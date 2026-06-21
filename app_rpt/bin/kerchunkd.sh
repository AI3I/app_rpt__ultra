#!/usr/bin/env bash
###VERSION=2.0.8
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
# kerchunkd.sh - Kerchunk detection daemon
# This daemon runs continuously and monitors for kerchunks in near real-time.
# When consecutive kerchunks are detected, it plays a warning message
# immediately after the transmission ends (no cron delay).
#
# USAGE: Start via systemd service or run in background

set -euo pipefail

# Source common functions and configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

# ==============================================================================
#    Configuration
# ==============================================================================

# Poll interval in seconds (how often to check for new transmissions)
POLL_INTERVAL="${POLL_INTERVAL:-1}"

# Kerchunk detection mode (passive=log only, active=log+play warning)
KERCHUNK_MODE="${KERCHUNK_MODE:-passive}"

# Kerchunk detection threshold
KERCHUNK_THRESHOLD="${KERCHUNK_THRESHOLD:-3}"

# Rate limiting (seconds between warning messages)
KERCHUNK_WAITLIMIT="${KERCHUNK_WAITLIMIT:-30}"

# Delay (seconds) after COS drops before playing the warning
KERCHUNK_WARNDELAY="${KERCHUNK_WARNDELAY:-2}"

# Kerchunk duration range (seconds)
KERCHUNK_MIN_DURATION="${KERCHUNK_MIN_DURATION:-0.2}"  # Minimum duration to count (ignore noise/blips)
KERCHUNK_MAX_DURATION="${KERCHUNK_MAX_DURATION:-1.5}"  # Maximum duration - anything over this resets counter

# PID file and lock file (per-node, outside sticky /tmp to avoid fs.protected_regular)
PID_FILE="${BASEDIR}/lib/kerchunkd_${MYNODE}.pid"
LOCK_FILE="${BASEDIR}/lib/kerchunkd_${MYNODE}.lock"

# State file locations
STATE_DIR="${BASEDIR}/lib/kerchunk_${MYNODE}"
CONSECUTIVE_FILE="${STATE_DIR}/consecutive"
LAST_WARNING_FILE="${STATE_DIR}/last_warning"
LAST_KEYUPS_FILE="${STATE_DIR}/last_keyups"
LAST_TXTIME_FILE="${STATE_DIR}/last_txtime"
LAST_KERCHUNKS_FILE="${STATE_DIR}/last_kerchunks"

# ==============================================================================
#    Functions
# ==============================================================================

# Convert TX time string (HH:MM:SS:mmm) to total milliseconds
txtime_to_ms() {
    local txtime="$1"

    # Parse HH:MM:SS:mmm format
    if [[ $txtime =~ ^([0-9]+):([0-9]+):([0-9]+):([0-9]+)$ ]]; then
        local hours="${BASH_REMATCH[1]}"
        local minutes="${BASH_REMATCH[2]}"
        local seconds="${BASH_REMATCH[3]}"
        local ms="${BASH_REMATCH[4]}"

        # Convert to total milliseconds (force base-10 to handle leading zeros)
        local total_ms=$(( (10#$hours * 3600 + 10#$minutes * 60 + 10#$seconds) * 1000 + 10#$ms ))
        echo "$total_ms"
    else
        echo "0"
    fi
}

get_stats() {
    # Get current keyups, TX time, and kerchunks from rpt stats
    local stats
    stats=$(asterisk -rx "rpt stats ${MYNODE}" 2>/dev/null)

    # Extract keyups
    local keyups
    keyups=$(echo "$stats" | grep "Keyups since system initialization" | awk -F: '{print $2}' | tr -d ' ')
    [[ "$keyups" =~ ^[0-9]+$ ]] || keyups="0"

    # Extract kerchunks (RF-only, excludes node connect events)
    local kerchunks
    kerchunks=$(echo "$stats" | grep "Kerchunks since system initialization" | awk -F: '{print $2}' | tr -d ' ')
    [[ "$kerchunks" =~ ^[0-9]+$ ]] || kerchunks="0"

    # Extract TX time
    local txtime
    txtime=$(echo "$stats" | grep "TX time since system initialization" | awk -F: '{print $2":"$3":"$4":"$5}' | tr -d ' ')
    [[ -n "$txtime" ]] || txtime="00:00:00:000"

    # Convert TX time to milliseconds
    local txtime_ms
    txtime_ms=$(txtime_to_ms "$txtime")

    echo "${keyups}:${txtime_ms}:${kerchunks}"
}

initialize_state() {
    mkdir -p "${STATE_DIR}"
    [[ -f "${CONSECUTIVE_FILE}" ]] || echo "0" > "${CONSECUTIVE_FILE}"
    [[ -f "${LAST_WARNING_FILE}" ]] || echo "0" > "${LAST_WARNING_FILE}"
    [[ -f "${LAST_KEYUPS_FILE}" ]] || echo "0" > "${LAST_KEYUPS_FILE}"
    [[ -f "${LAST_TXTIME_FILE}" ]] || echo "0" > "${LAST_TXTIME_FILE}"
    [[ -f "${LAST_KERCHUNKS_FILE}" ]] || echo "0" > "${LAST_KERCHUNKS_FILE}"
}

read_state() {
    CONSECUTIVE=$(cat "${CONSECUTIVE_FILE}" 2>/dev/null || echo "0")
    LAST_WARNING=$(cat "${LAST_WARNING_FILE}" 2>/dev/null || echo "0")
    LAST_KEYUPS=$(cat "${LAST_KEYUPS_FILE}" 2>/dev/null || echo "0")
    LAST_TXTIME=$(cat "${LAST_TXTIME_FILE}" 2>/dev/null || echo "0")
    LAST_KERCHUNKS=$(cat "${LAST_KERCHUNKS_FILE}" 2>/dev/null || echo "0")
}

write_state() {
    echo "${CONSECUTIVE}" > "${CONSECUTIVE_FILE}"
    echo "${LAST_WARNING}" > "${LAST_WARNING_FILE}"
    echo "${LAST_KEYUPS}" > "${LAST_KEYUPS_FILE}"
    echo "${LAST_TXTIME}" > "${LAST_TXTIME_FILE}"
    echo "${LAST_KERCHUNKS}" > "${LAST_KERCHUNKS_FILE}"
}

log_kerchunk_stats() {
    local duration="$1"
    local consecutive="$2"
    local warning_played="$3"
    local transmission_type="$4"  # "kerchunk" or "normal"

    # Log file location
    local stats_log="/opt/app_rpt/log/kerchunk_stats.log"

    # Get current system state
    local current_state
    current_state=$(grep "^Selected system state" < <(asterisk -rx "rpt stats ${MYNODE}" 2>/dev/null) | awk -F: '{print $2}' | tr -d ' ' || echo "unknown")

    # Format: Timestamp, Node, Duration, Consecutive, Warning_Played, Type, State
    echo "$(date '+%Y-%m-%d %H:%M:%S'), ${MYNODE}, ${duration}s, ${consecutive}, ${warning_played}, ${transmission_type}, state_${current_state}" >> "$stats_log"
}

play_kerchunk_warning() {
    sleep "${KERCHUNK_WARNDELAY}"
    log "Playing kerchunk reminder message (consecutive: ${CONSECUTIVE})"

    # Check if we have a custom message
    if [[ -f "${SOUNDS}/custom/kerchunk_reminder.ulaw" ]]; then
        asterisk -rx "rpt localplay ${MYNODE} ${SOUNDS}/custom/kerchunk_reminder" &>/dev/null
    else
        # Use default TMS5220 message: "Please identify"
        asterisk -rx "rpt localplay ${MYNODE} ${SOUNDS}/_male/please" &>/dev/null
        sleep 0.2
        asterisk -rx "rpt localplay ${MYNODE} ${SOUNDS}/_male/identify" &>/dev/null
    fi
}

check_rate_limit() {
    local now
    now=$(date +%s)
    local elapsed=$((now - LAST_WARNING))

    if [[ $elapsed -lt $KERCHUNK_WAITLIMIT ]]; then
        return 1
    fi

    return 0
}

# ==============================================================================
#    Main Daemon Loop
# ==============================================================================

_loop_iteration() {
    # Read current state
    read_state

    # Get current stats (keyups:txtime_ms:kerchunks)
    local stats
    stats=$(get_stats)
    local current_keyups
    current_keyups=$(echo "$stats" | cut -d: -f1)
    local current_txtime
    current_txtime=$(echo "$stats" | cut -d: -f2)
    local current_kerchunks
    current_kerchunks=$(echo "$stats" | cut -d: -f3)

    local new_kerchunks=$((current_kerchunks - LAST_KERCHUNKS))
    local new_keyups=$((current_keyups - LAST_KEYUPS))

    if [[ $new_kerchunks -gt 0 ]]; then
        # app_rpt classified this as a kerchunk (RF-only, node connects excluded)
        local avg_duration_s="n/a"
        if [[ $new_keyups -gt 0 ]]; then
            local txtime_delta_ms=$((current_txtime - LAST_TXTIME))
            local avg_duration_ms=$((txtime_delta_ms / new_keyups))
            avg_duration_s=$(awk "BEGIN {printf \"%.1f\", $avg_duration_ms/1000.0}")
        fi

        CONSECUTIVE=$((CONSECUTIVE + new_kerchunks))
        log "Kerchunk detected (duration: ${avg_duration_s}s, consecutive: ${CONSECUTIVE})"

        if [[ $CONSECUTIVE -ge $KERCHUNK_THRESHOLD ]]; then
            log "Kerchunk threshold reached (${CONSECUTIVE} >= ${KERCHUNK_THRESHOLD})"

            if [[ "$KERCHUNK_MODE" == "active" ]]; then
                if check_rate_limit; then
                    play_kerchunk_warning
                    log_kerchunk_stats "$avg_duration_s" "$CONSECUTIVE" "yes" "kerchunk"
                    LAST_WARNING=$(date +%s)
                    CONSECUTIVE=0
                else
                    log_kerchunk_stats "$avg_duration_s" "$CONSECUTIVE" "no" "kerchunk"
                fi
            else
                log "Passive mode: kerchunks logged, no warning played"
                log_kerchunk_stats "$avg_duration_s" "$CONSECUTIVE" "no-passive" "kerchunk"
                CONSECUTIVE=0
            fi
        else
            log_kerchunk_stats "$avg_duration_s" "$CONSECUTIVE" "no" "kerchunk"
        fi

    elif [[ $new_keyups -gt 0 ]]; then
        # Keyups increased but kerchunks counter didn't — use duration to decide
        # whether this is a normal transmission (reset counter) or a non-RF event
        # like a node connect (ignore entirely)
        local txtime_delta_ms=$((current_txtime - LAST_TXTIME))
        local avg_duration_ms=$((txtime_delta_ms / new_keyups))
        local avg_duration_s=$(awk "BEGIN {printf \"%.1f\", $avg_duration_ms/1000.0}")

        local kerchunk_min_ms=$(awk "BEGIN {printf \"%.0f\", $KERCHUNK_MIN_DURATION*1000}")
        local kerchunk_max_ms=$(awk "BEGIN {printf \"%.0f\", $KERCHUNK_MAX_DURATION*1000}")

        if [[ $avg_duration_ms -lt $kerchunk_min_ms ]]; then
            # Too short — noise/blip, ignore
            log "Transmission too short (duration: ${avg_duration_s}s < ${KERCHUNK_MIN_DURATION}s, ignored)"
        elif [[ $avg_duration_ms -gt $kerchunk_max_ms ]]; then
            # Long enough to be a normal transmission — reset consecutive counter
            log "Normal transmission detected (duration: ${avg_duration_s}s > ${KERCHUNK_MAX_DURATION}s, consecutive reset)"
            log_kerchunk_stats "$avg_duration_s" "0" "no" "normal"
            CONSECUTIVE=0
        else
            # In kerchunk duration range but not counted by app_rpt — non-RF event (e.g. node connect), ignore
            log "Non-RF event ignored (duration: ${avg_duration_s}s, not counted as kerchunk by app_rpt)"
        fi
    fi

    # Update state
    LAST_KEYUPS=$current_keyups
    LAST_TXTIME=$current_txtime
    LAST_KERCHUNKS=$current_kerchunks
    write_state
}

main_loop() {
    log "Kerchunk daemon started (poll: ${POLL_INTERVAL}s, mode: ${KERCHUNK_MODE}, threshold: ${KERCHUNK_THRESHOLD}, duration: ${KERCHUNK_MIN_DURATION}-${KERCHUNK_MAX_DURATION}s, warndelay: ${KERCHUNK_WARNDELAY}s)"

    # Initialize state
    initialize_state

    while true; do
        _loop_iteration || log_error "Loop iteration failed (exit $?), recovering..."
        sleep "$POLL_INTERVAL"
    done
}

# ==============================================================================
#    Daemon Startup
# ==============================================================================

# Use flock for atomic single-instance enforcement (eliminates TOCTOU race)
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    OLD_PID=$(cat "$PID_FILE" 2>/dev/null || echo "unknown")
    log "Kerchunk daemon already running (PID: $OLD_PID)"
    exit 1
fi

# Write PID file now that we hold the lock
echo $$ > "$PID_FILE"

# Cleanup on exit
trap 'rm -f "$PID_FILE" "$LOCK_FILE"; log "Kerchunk daemon stopped"' EXIT

# Check if kerchunk monitoring is enabled
if [[ "${KERCHUNK_ENABLE:-0}" != "1" ]]; then
    log "Kerchunk monitoring disabled (KERCHUNK_ENABLE=0)"
    exit 0
fi

# Start main loop
main_loop
