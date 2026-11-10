#!/usr/bin/env bash
# migrate-lang.sh — migrate an existing app_rpt__ultra install to the "rp" language
# layout where sounds/rp is a REAL directory and /opt/app_rpt/sounds is a symlink.
#
# Before (old layouts seen in the field):
#   /opt/app_rpt/sounds/                ← real dir (TMS5220 + Allison Smith contamination)
#   sounds/en  → /opt/app_rpt/sounds    ← caused package manager to contaminate our dir
#   or: /usr/share/asterisk/sounds → /opt/app_rpt/sounds (whole parent symlinked), and
#       /var/lib/asterisk/sounds   → /opt/app_rpt/sounds
#
# After (new layout):
#   /usr/share/asterisk/sounds/rp/     ← real dir, owned entirely by app_rpt__ultra
#   /usr/share/asterisk/sounds/en/     ← real dir, clean Allison Smith (package-managed)
#   /var/lib/asterisk/sounds/rp  → /usr/share/asterisk/sounds/rp
#   /opt/app_rpt/sounds          → /usr/share/asterisk/sounds/rp  (scripts unchanged)
#
# Nothing is deleted: the old sounds directory is moved to
# $INSTALL_BASE/backups/sounds_premigration_<timestamp>/ and can be removed by hand
# once the node is verified.
#
# What this script does:
#   1. Replaces parent symlinks (/usr/share/asterisk/sounds, /var/lib/asterisk/sounds)
#      that point at the old sounds dir with real directories
#   2. Removes sounds/en symlinks that point into the old sounds dir
#   3. Creates the real sounds/rp/ directory (refuses if it would live inside the old dir)
#   4. Copies user data (ids/, tails/, custom/, rpt/, recordings/, voice_id, tail_message)
#   5. Moves the old real sounds directory into backups/
#   6. Creates /opt/app_rpt/sounds symlink → sounds/rp/
#   7. Creates /var/lib/asterisk/sounds/rp symlink (secondary Asterisk path)
#   8. Reinstalls asl3-asterisk so sounds/en/ is a clean real directory again
#   9. Sets language=rp in asterisk.conf and chan_dahdi.conf
#
# Safe to re-run: steps that are already done are skipped.
# After this script: run upgrade.sh to populate sounds/rp/ with TMS5220 files.
# Run as root.

set -euo pipefail

INSTALL_BASE="${1:-/opt/app_rpt}"
AST_SOUNDS="/usr/share/asterisk/sounds"
AST_SOUNDS_RP="$AST_SOUNDS/rp"
LIB_SOUNDS="/var/lib/asterisk/sounds"
DAHDI_CONF="/etc/asterisk/chan_dahdi.conf"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { echo -e "${YELLOW}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[ OK ]${NC} $*"; }
fail()    { echo -e "${RED}[FAIL]${NC} $*"; exit 1; }

[[ $EUID -ne 0 ]] && fail "Must be run as root."
[[ -d "$INSTALL_BASE" ]] || fail "app_rpt__ultra not found at $INSTALL_BASE"

OLD_SOUNDS="$INSTALL_BASE/sounds"
OLD_REAL="$(readlink -f "$OLD_SOUNDS")"

# True if path $1 resolves to the old sounds dir or anything inside it.
inside_old() {
    local real
    real="$(readlink -m "$1")"
    [[ "$real" == "$OLD_REAL" || "$real" == "$OLD_REAL/"* ]]
}

# ── 0. Work out what needs doing ─────────────────────────────────────────────
NEED_MOVE=false
if [[ -L "$OLD_SOUNDS" ]]; then
    if [[ "$(readlink -f "$OLD_SOUNDS")" == "$(readlink -m "$AST_SOUNDS_RP")" ]] \
        && [[ -d "$AST_SOUNDS_RP" ]] && [[ ! -L "$AST_SOUNDS_RP" ]]; then
        info "$OLD_SOUNDS already points to $AST_SOUNDS_RP — layout already migrated"
    else
        fail "$OLD_SOUNDS is a symlink to $(readlink "$OLD_SOUNDS"), not $AST_SOUNDS_RP — fix by hand"
    fi
elif [[ -d "$OLD_SOUNDS" ]]; then
    NEED_MOVE=true
else
    info "$OLD_SOUNDS does not exist — will create it as a symlink"
fi

if [[ "$NEED_MOVE" == true ]]; then
    # ── 1. Replace parent symlinks that point at the old sounds dir ──────────
    info "Step 1: Checking Asterisk sounds parent directories..."
    for parent in "$AST_SOUNDS" "$LIB_SOUNDS"; do
        if [[ -L "$parent" ]]; then
            if inside_old "$parent"; then
                rm -f "$parent"          # removes the link only (no trailing slash)
                mkdir -p "$parent"
                success "  Replaced symlink with real directory: $parent"
            else
                fail "  $parent is a symlink to $(readlink "$parent") — fix by hand before migrating"
            fi
        else
            info "  $parent is not a symlink"
        fi
    done

    # ── 2. Remove sounds/en symlinks pointing into the old sounds dir ────────
    info "Step 2: Removing old sounds/en symlinks..."
    for old_link in "$LIB_SOUNDS/en" "$AST_SOUNDS/en"; do
        if [[ -L "$old_link" ]] && inside_old "$old_link"; then
            rm -f "$old_link"            # removes the link only (no trailing slash)
            success "  Removed: $old_link"
        elif [[ -L "$old_link" ]]; then
            info "  Skipping $old_link — points elsewhere (not ours)"
        else
            info "  No en symlink at $old_link"
        fi
    done
fi

# ── 3. Create the real sounds/rp/ directory ──────────────────────────────────
info "Step 3: Creating real directory $AST_SOUNDS_RP ..."
if [[ -L "$AST_SOUNDS_RP" ]]; then
    fail "  $AST_SOUNDS_RP is a symlink — expected a real directory; fix by hand"
fi
if [[ "$NEED_MOVE" == true ]] && inside_old "$AST_SOUNDS_RP"; then
    fail "  $AST_SOUNDS_RP resolves inside $OLD_SOUNDS — refusing to continue"
fi
mkdir -p "$AST_SOUNDS_RP"/{ids,rpt,tails,wx,weather,letters,digits,custom,recordings,_male,_female,_sndfx}
success "  Ready: $AST_SOUNDS_RP"

if [[ "$NEED_MOVE" == true ]]; then
    # ── 4. Copy user data into sounds/rp/ ─────────────────────────────────────
    info "Step 4: Copying user data into $AST_SOUNDS_RP ..."
    for d in ids tails custom rpt recordings; do
        if [[ -d "$OLD_SOUNDS/$d" ]]; then
            cp -a "$OLD_SOUNDS/$d/." "$AST_SOUNDS_RP/$d/"
            success "  Copied: $d/"
        fi
    done
    for f in voice_id.ulaw tail_message.ulaw; do
        if [[ -e "$OLD_SOUNDS/$f" || -L "$OLD_SOUNDS/$f" ]]; then
            cp -a "$OLD_SOUNDS/$f" "$AST_SOUNDS_RP/"
            success "  Copied: $f"
        fi
    done

    # ── 5. Move the old real sounds directory aside (never deleted) ──────────
    PRESERVE="$INSTALL_BASE/backups/sounds_premigration_$(date +%Y%m%d_%H%M%S)"
    info "Step 5: Moving old sounds directory to $PRESERVE ..."
    mkdir -p "$INSTALL_BASE/backups"
    mv "$OLD_SOUNDS" "$PRESERVE"
    success "  Moved: $OLD_SOUNDS -> $PRESERVE (remove by hand once verified)"
fi

# ── 6. Create /opt/app_rpt/sounds symlink → sounds/rp/ ───────────────────────
info "Step 6: Ensuring $OLD_SOUNDS -> $AST_SOUNDS_RP ..."
if [[ ! -e "$OLD_SOUNDS" && ! -L "$OLD_SOUNDS" ]]; then
    ln -s "$AST_SOUNDS_RP" "$OLD_SOUNDS"
    success "  Created symlink"
else
    info "  Already present"
fi

# ── 7. Create /var/lib/asterisk/sounds/rp symlink ────────────────────────────
info "Step 7: Creating secondary Asterisk sounds symlink ..."
lib_rp="$LIB_SOUNDS/rp"
if [[ ! -d "$LIB_SOUNDS" ]]; then
    info "  $LIB_SOUNDS absent — skipping"
elif [[ -e "$lib_rp" && ! -L "$lib_rp" ]]; then
    info "  $lib_rp is a real file or directory — leaving it alone"
else
    ln -sfn "$AST_SOUNDS_RP" "$lib_rp"
    success "  Created: $lib_rp -> $AST_SOUNDS_RP"
fi

# ── 8. Reinstall asl3-asterisk for a clean sounds/en/ ────────────────────────
# With the old symlinks removed, dpkg will now place files in a real sounds/en/ dir.
info "Step 8: Reinstalling asl3-asterisk to restore clean sounds/en/ ..."
if ! DEBIAN_FRONTEND=noninteractive apt-get install --reinstall -y asl3-asterisk; then
    info "  apt-get failed — sounds/en/ not restored; rerun: apt-get install --reinstall asl3-asterisk"
elif [[ -d "$AST_SOUNDS/en" ]] && [[ ! -L "$AST_SOUNDS/en" ]]; then
    count=$(find "$AST_SOUNDS/en" -maxdepth 1 -name "*.ulaw" | wc -l)
    success "  sounds/en/ restored ($count .ulaw files)"
else
    info "  sounds/en/ is still a symlink or missing after reinstall"
fi

# ── 9. Set language=rp in asterisk.conf and chan_dahdi.conf ──────────────────
# asterisk.conf defaultlanguage covers ALL channel types including app_rpt's
# internal pseudo channels.  chan_dahdi.conf only covers DAHDI trunk channels.
AST_CONF="/etc/asterisk/asterisk.conf"
info "Step 9: Setting defaultlanguage=rp in asterisk.conf ..."
if [[ ! -f "$AST_CONF" ]]; then
    info "  asterisk.conf not found — set defaultlanguage = rp manually"
elif grep -q "^defaultlanguage = rp" "$AST_CONF"; then
    success "  Already set: defaultlanguage = rp"
elif grep -q "^;*defaultlanguage" "$AST_CONF"; then
    sed -i 's/^;*defaultlanguage\s*=.*/defaultlanguage = rp/' "$AST_CONF"
    success "  Set: defaultlanguage = rp in asterisk.conf"
else
    sed -i '/^\[options\]/a defaultlanguage = rp' "$AST_CONF"
    success "  Added defaultlanguage = rp to asterisk.conf [options]"
fi

info "      Setting language=rp in chan_dahdi.conf ..."
if [[ ! -f "$DAHDI_CONF" ]]; then
    info "  chan_dahdi.conf not found — skipping"
elif grep -q "^language=rp" "$DAHDI_CONF"; then
    success "  Already set: language=rp"
elif grep -q "^language=" "$DAHDI_CONF"; then
    sed -i 's/^language=.*/language=rp/' "$DAHDI_CONF"
    success "  Updated: language=rp in chan_dahdi.conf"
elif grep -q "^;language=en" "$DAHDI_CONF"; then
    sed -i 's/^;language=en/language=rp/' "$DAHDI_CONF"
    success "  Set: language=rp in chan_dahdi.conf"
else
    sed -i '/^\[general\]/a language=rp' "$DAHDI_CONF"
    success "  Added language=rp to chan_dahdi.conf [general]"
fi

chown -R asterisk:asterisk "$AST_SOUNDS_RP"
chown -h asterisk:asterisk "$OLD_SOUNDS"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════"
success "Migration complete."
echo ""
echo "  sounds/en/  ← clean Allison Smith  (package-managed, real dir)"
echo "  sounds/rp/  ← $AST_SOUNDS_RP  (real dir, app_rpt__ultra)"
echo "  $INSTALL_BASE/sounds -> $AST_SOUNDS_RP"
if [[ -n "${PRESERVE:-}" ]]; then
    echo "  old sounds  ← $PRESERVE"
fi
echo ""
echo "  NEXT: run upgrade.sh to install TMS5220 sounds, then reload Asterisk:"
echo "    sudo $INSTALL_BASE/util/upgrade.sh"
echo "    asterisk -rx 'reload'"
echo "════════════════════════════════════════════════════════"
