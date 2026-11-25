#!/usr/bin/env bash

#
#    app_rpt__ultra :: the ultimate controller experience for app_rpt
#    Copyright (C) 2025   John D. Lewis (AI3I)
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

# Builds ${RECORDDIR}/recordings.json, the list the recordings page
# (${RECORDDIR}/index.html, served at /recordings/) plays from: each node's
# WAV recordings with their length in seconds, read from the WAV header, and
# start time (file mtime minus length; uploads and conversions keep mtime).
# Filenames aren't used for time: app_rpt names them in whatever zone Asterisk
# started under, so one archive can hold both UTC- and local-named files.
# Nodes this hub keeps a config for (${BACKUPDIR}/<node>/rpt.conf) that have
# archiving on are listed even before any of their recordings arrive.
# Runs every minute from cron.  Only hubs hold an archive worth browsing
# (children upload theirs nightly via datadumper.sh), so children exit here.
# The daily .txt activity logs are never listed.

source "%%BASEDIR%%/bin/common.sh"
set -euo pipefail

[[ "${FETCHLOCAL:-0}" == "1" ]] && exit 0

if [[ -z "${RECORDDIR:-}" ]] || [[ ! -d "$RECORDDIR" ]]; then
    log_error "RECORDDIR (${RECORDDIR:-unset}) is not a directory; the recordings page has no list to play from"
    exit 1
fi

if ! err=$(python3 -I - "$RECORDDIR" "${BACKUPDIR:-}" "${MYNODE:-}" <<'PY' 2>&1
import json, os, re, struct, sys, time

root, backups, home = sys.argv[1], sys.argv[2], sys.argv[3]
out = os.path.join(root, "recordings.json")

def seconds(path, size):
    """Length of a RIFF/WAVE file from its fmt byte rate and data size."""
    with open(path, "rb") as f:
        head = f.read(512)
    if len(head) < 12 or head[:4] != b"RIFF" or head[8:12] != b"WAVE":
        return None
    pos, rate = 12, 0
    while pos + 8 <= len(head):
        cid = head[pos:pos + 4]
        clen = struct.unpack("<I", head[pos + 4:pos + 8])[0]
        if cid == b"fmt " and pos + 20 <= len(head):
            rate = struct.unpack("<I", head[pos + 16:pos + 20])[0]
        elif cid == b"data":
            avail = size - (pos + 8)
            # A recording still in progress has no data size in its header yet
            if clen == 0 or clen > avail:
                clen = avail
            return round(clen / rate, 1) if rate else None
        pos += 8 + clen + (clen & 1)
    return None

nodes = {}
# Nodes with archiving on in the hub's copy of their rpt.conf
if backups and os.path.isdir(backups):
    for node in os.listdir(backups):
        conf = os.path.join(backups, node, "rpt.conf")
        if node.isdigit() and os.path.isfile(conf):
            try:
                with open(conf, errors="replace") as f:
                    if any(re.match(r"archivedir\s*=", line) for line in f):
                        nodes[node] = []
            except OSError:
                pass

for node in sorted(os.listdir(root)):
    ndir = os.path.join(root, node)
    if not node.isdigit() or not os.path.isdir(ndir):
        continue
    entries = []
    for name in os.listdir(ndir):
        if not re.fullmatch(r"\d{14}\w*\.wav", name, re.IGNORECASE):
            continue
        path = os.path.join(ndir, name)
        try:
            st = os.stat(path)
            secs = seconds(path, st.st_size) if st.st_size > 0 else None
        except OSError:
            continue  # purged or renamed while we looked
        if secs is not None:
            entries.append([name, secs, int(st.st_mtime - secs)])
    if entries:
        entries.sort(key=lambda e: (e[2], e[0]))
        nodes[node] = entries

nodes = dict(sorted(nodes.items(), key=lambda kv: int(kv[0])))
body = {"nodes": nodes, "home": home}
try:
    with open(out) as f:
        old = json.load(f)
    if old.get("nodes") == nodes and old.get("home") == home:
        sys.exit(0)  # unchanged: keep the file (and its "updated" time)
except (OSError, ValueError):
    pass

body["updated"] = int(time.time())
tmp = out + ".tmp"
with open(tmp, "w") as f:
    json.dump(body, f, separators=(",", ":"))
os.chmod(tmp, 0o644)
os.replace(tmp, out)
PY
); then
    log_error "recordings.json not rebuilt; the recordings page shows the list as of its last update: ${err//$'\n'/ }"
    exit 1
fi
