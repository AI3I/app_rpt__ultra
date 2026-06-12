#!/usr/bin/env bash
# migrate-lang.sh — migrate an existing app_rpt__ultra install to the "rp" language
# layout where sounds/rp is a REAL directory and /opt/app_rpt/sounds is a symlink.
#
# Before (old layout):
#   /opt/app_rpt/sounds/         ← real dir (TMS5220 + Allison Smith contamination)
#   sounds/en  → /opt/app_rpt/sounds   ← caused package manager to contaminate our dir
#
# After (new layout):
#   /usr/share/asterisk/sounds/rp/     ← real dir, owned entirely by app_rpt__ultra
#   /usr/share/asterisk/sounds/en/     ← real dir, clean Allison Smith (package-managed)
#   /var/lib/asterisk/sounds/rp  → /usr/share/asterisk/sounds/rp
#   /opt/app_rpt/sounds          → /usr/share/asterisk/sounds/rp  (scripts unchanged)
#
# What this script does:
#   1. Removes old sounds/en symlinks
#   2. Backs up user data (ids/, tails/, custom/, voice_id.ulaw)
#   3. Creates the real sounds/rp/ directory
#   4. Restores user data into sounds/rp/
#   5. Removes the old (contaminated) /opt/app_rpt/sounds/ real directory
#   6. Creates /opt/app_rpt/sounds symlink → sounds/rp/
#   7. Creates /var/lib/asterisk/sounds/rp symlink (secondary Asterisk path)
#   8. Reinstalls asl3-asterisk so sounds/en/ is a clean real directory again
#   9. Sets language=rp in chan_dahdi.conf
#
# After this script: run upgrade.sh to populate sounds/rp/ with TMS5220 files.
# Run as root.

set -euo pipefail

INSTALL_BASE="${1:-/opt/app_rpt}"
AST_SOUNDS_RP="/usr/share/asterisk/sounds/rp"
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

# ── 1. Remove old sounds/en symlinks ────────────────────────────────────────
info "Step 1: Removing old sounds/en symlinks..."
for old_link in "/var/lib/asterisk/sounds/en" "/usr/share/asterisk/sounds/en"; do
    parent="$(dirname "$old_link")"
    [[ -d "$parent" ]] || continue
    if [[ -L "$old_link" ]] && [[ "$(readlink "$old_link")" == "$OLD_SOUNDS" ]]; then
        rm -f "$old_link"
        success "  Removed: $old_link"
    elif [[ -L "$old_link" ]]; then
        info "  Skipping $old_link — points elsewhere (not ours)"
    else
        info "  No old en symlink at $old_link"
    fi
done

# ── 2. Back up user data from the old sounds directory ───────────────────────
# Save ids/, tails/, custom/, and voice_id.ulaw — these contain user-generated
# content that upgrade.sh won't restore.
BACKUP_DIR="$(mktemp -d /tmp/app_rpt_sounds_backup.XXXXXX)"
info "Step 2: Backing up user data to $BACKUP_DIR ..."

if [[ -d "$OLD_SOUNDS" ]] && [[ ! -L "$OLD_SOUNDS" ]]; then
    for d in ids tails custom; do
        if [[ -d "$OLD_SOUNDS/$d" ]]; then
            cp -a "$OLD_SOUNDS/$d" "$BACKUP_DIR/"
            success "  Backed up: $d/"
        fi
    done
    if [[ -f "$OLD_SOUNDS/voice_id.ulaw" ]]; then
        cp -a "$OLD_SOUNDS/voice_id.ulaw" "$BACKUP_DIR/"
        success "  Backed up: voice_id.ulaw"
    fi
else
    info "  Old sounds dir is already a symlink or absent — nothing to back up"
fi

# ── 3. Create the real sounds/rp/ directory ──────────────────────────────────
info "Step 3: Creating real directory $AST_SOUNDS_RP ..."
mkdir -p "$AST_SOUNDS_RP"/{ids,rpt,tails,wx,weather,letters,digits,custom,_male,_female,_sndfx}
success "  Created: $AST_SOUNDS_RP"

# ── 4. Restore user data into sounds/rp/ ─────────────────────────────────────
info "Step 4: Restoring user data into $AST_SOUNDS_RP ..."
for d in ids tails custom; do
    if [[ -d "$BACKUP_DIR/$d" ]]; then
        cp -a "$BACKUP_DIR/$d/." "$AST_SOUNDS_RP/$d/"
        success "  Restored: $d/"
    fi
done
if [[ -f "$BACKUP_DIR/voice_id.ulaw" ]]; then
    cp -a "$BACKUP_DIR/voice_id.ulaw" "$AST_SOUNDS_RP/"
    success "  Restored: voice_id.ulaw"
fi
rm -rf "$BACKUP_DIR"

# ── 5. Remove the old (contaminated) real sounds directory ───────────────────
info "Step 5: Removing old sounds directory $OLD_SOUNDS ..."
if [[ -d "$OLD_SOUNDS" ]] && [[ ! -L "$OLD_SOUNDS" ]]; then
    rm -rf "$OLD_SOUNDS"
    success "  Removed: $OLD_SOUNDS"
elif [[ -L "$OLD_SOUNDS" ]]; then
    info "  Already a symlink — skipping removal"
fi

# ── 6. Create /opt/app_rpt/sounds symlink → sounds/rp/ ───────────────────────
info "Step 6: Creating $INSTALL_BASE/sounds -> $AST_SOUNDS_RP ..."
ln -s "$AST_SOUNDS_RP" "$INSTALL_BASE/sounds"
success "  Created symlink"

# ── 7. Create /var/lib/asterisk/sounds/rp symlink ────────────────────────────
info "Step 7: Creating secondary Asterisk sounds symlink ..."
lib_rp="/var/lib/asterisk/sounds/rp"
if [[ -d "/var/lib/asterisk/sounds" ]]; then
    rm -f "$lib_rp"
    ln -s "$AST_SOUNDS_RP" "$lib_rp"
    success "  Created: $lib_rp -> $AST_SOUNDS_RP"
else
    info "  /var/lib/asterisk/sounds absent — skipping"
fi

# ── 8. Reinstall asl3-asterisk for a clean sounds/en/ ────────────────────────
# With the old symlink removed, dpkg will now place files in a real sounds/en/ dir.
info "Step 8: Reinstalling asl3-asterisk to restore clean sounds/en/ ..."
DEBIAN_FRONTEND=noninteractive apt-get install --reinstall -y asl3-asterisk
if [[ -d "/usr/share/asterisk/sounds/en" ]] && [[ ! -L "/usr/share/asterisk/sounds/en" ]]; then
    count=$(find /usr/share/asterisk/sounds/en -maxdepth 1 -name "*.ulaw" | wc -l)
    success "  sounds/en/ restored ($count .ulaw files)"
else
    fail "  sounds/en/ is still a symlink or missing after reinstall"
fi

# ── 9. Set language=rp in chan_dahdi.conf ─────────────────────────────────────
info "Step 9: Setting language=rp in chan_dahdi.conf ..."
if [[ ! -f "$DAHDI_CONF" ]]; then
    info "  chan_dahdi.conf not found — add 'language=rp' to [general] manually"
elif grep -q "^language=rp" "$DAHDI_CONF"; then
    success "  Already set: language=rp"
elif grep -q "^language=" "$DAHDI_CONF"; then
    sed -i 's/^language=.*/language=rp/' "$DAHDI_CONF"
    success "  Updated: language=rp"
elif grep -q "^;language=en" "$DAHDI_CONF"; then
    sed -i 's/^;language=en/language=rp/' "$DAHDI_CONF"
    success "  Uncommented and set: language=rp"
else
    sed -i '/^\[general\]/a language=rp' "$DAHDI_CONF"
    success "  Added language=rp to [general]"
fi

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════"
success "Migration complete."
echo ""
echo "  sounds/en/  ← clean Allison Smith  (package-managed, real dir)"
echo "  sounds/rp/  ← $AST_SOUNDS_RP  (real dir, app_rpt__ultra)"
echo "  $INSTALL_BASE/sounds -> $AST_SOUNDS_RP"
echo ""
echo "  NEXT: run upgrade.sh to install TMS5220 sounds, then reload Asterisk:"
echo "    sudo $INSTALL_BASE/util/upgrade.sh"
echo "    asterisk -rx 'reload'"
echo "════════════════════════════════════════════════════════"
