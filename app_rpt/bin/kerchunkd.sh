#!/bin/bash
###VERSION=2.0.2
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
#

set -euo pipefail

# Source common functions and configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

# ==============================================================================
#    Configuration
# ==============================================================================

# Poll interval in seconds (how often to check for new kerchunks)
POLL_INTERVAL="${POLL_INTERVAL:-5}"

# Kerchunk detection threshold
KERCHUNK_THRESHOLD="${KERCHUNK_THRESHOLD:-3}"

# Rate limiting (seconds between warning messages)
KERCHUNK_WAITLIMIT="${KERCHUNK_WAITLIMIT:-30}"

# PID file
PID_FILE="/tmp/kerchunkd.pid"

# State file locations
STATE_DIR="/tmp/app_rpt_kerchunk"
LAST_COUNT_FILE="${STATE_DIR}/last_count"
CONSECUTIVE_FILE="${STATE_DIR}/consecutive"
LAST_WARNING_FILE="${STATE_DIR}/last_warning"
LAST_KEYUPS_FILE="${STATE_DIR}/last_keyups"

# ==============================================================================
#    Daemon Management
# ==============================================================================

cleanup() {
    log "Kerchunk daemon shutting down"
    rm -f "${PID_FILE}"
    exit 0
}

trap cleanup SIGTERM SIGINT

check_if_running() {
    if [[ -f "${PID_FILE}" ]]; then
        local pid
        pid=$(cat "${PID_FILE}")
        if kill -0 "$pid" 2>/dev/null; then
            echo "Kerchunk daemon already running (PID: $pid)"
            exit 1
        else
            # Stale PID file
            rm -f "${PID_FILE}"
        fi
    fi
}

write_pid() {
    echo $$ > "${PID_FILE}"
}

# ==============================================================================
#    Functions
# ==============================================================================

get_kerchunk_count() {
    # Get current kerchunk count from app_rpt stats
    local kerchunks
    kerchunks=$(asterisk -rx "rpt stats ${MYNODE}" 2>/dev/null | \
                grep "Kerchunks since system initialization" | \
                awk -F: '{print $2}' | \
                tr -d ' ')

    if [[ -z "$kerchunks" ]] || [[ ! "$kerchunks" =~ ^[0-9]+$ ]]; then
        echo "0"
        return
    fi

    echo "$kerchunks"
}

get_keyup_count() {
    # Get current normal keyup count
    local keyups
    keyups=$(asterisk -rx "rpt stats ${MYNODE}" 2>/dev/null | \
            grep "Keyups since system initialization" | \
            awk -F: '{print $2}' | \
            tr -d ' ')

    if [[ -z "$keyups" ]] || [[ ! "$keyups" =~ ^[0-9]+$ ]]; then
        echo "0"
        return
    fi

    echo "$keyups"
}

initialize_state() {
    mkdir -p "${STATE_DIR}"
    [[ ! -f "${LAST_COUNT_FILE}" ]] && echo "0" > "${LAST_COUNT_FILE}"
    [[ ! -f "${CONSECUTIVE_FILE}" ]] && echo "0" > "${CONSECUTIVE_FILE}"
    [[ ! -f "${LAST_WARNING_FILE}" ]] && echo "0" > "${LAST_WARNING_FILE}"
    [[ ! -f "${LAST_KEYUPS_FILE}" ]] && echo "0" > "${LAST_KEYUPS_FILE}"
}

read_state() {
    LAST_COUNT=$(cat "${LAST_COUNT_FILE}" 2>/dev/null || echo "0")
    CONSECUTIVE=$(cat "${CONSECUTIVE_FILE}" 2>/dev/null || echo "0")
    LAST_WARNING=$(cat "${LAST_WARNING_FILE}" 2>/dev/null || echo "0")
    LAST_KEYUPS=$(cat "${LAST_KEYUPS_FILE}" 2>/dev/null || echo "0")
}

write_state() {
    echo "${LAST_COUNT}" > "${LAST_COUNT_FILE}"
    echo "${CONSECUTIVE}" > "${CONSECUTIVE_FILE}"
    echo "${LAST_WARNING}" > "${LAST_WARNING_FILE}"
    echo "${LAST_KEYUPS}" > "${LAST_KEYUPS_FILE}"
}

play_kerchunk_warning() {
    log "Playing kerchunk reminder message (consecutive: ${CONSECUTIVE})"

    # Check if we have a custom message
    if [[ -f "${SOUNDS}/custom/kerchunk_reminder.ulaw" ]]; then
        asterisk -rx "rpt localplay ${MYNODE} ${SOUNDS}/custom/kerchunk_reminder" &>/dev/null
    else
        # Use default TMS5220 message: "Please identify"
        # Play both words back-to-back without delay
        asterisk -rx "rpt localplay ${MYNODE} ${SOUNDS}/_male/please,${SOUNDS}/_male/identify" &>/dev/null
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

main_loop() {
    log "Kerchunk daemon started (poll interval: ${POLL_INTERVAL}s, threshold: ${KERCHUNK_THRESHOLD})"

    # Initialize state
    initialize_state

    while true; do
        # Read current state
        read_state

        # Get current counts
        CURRENT_COUNT=$(get_kerchunk_count)
        CURRENT_KEYUPS=$(get_keyup_count)

        # Check if kerchunk count increased
        if [[ $CURRENT_COUNT -gt $LAST_COUNT ]]; then
            # Kerchunk detected
            local new_kerchunks=$((CURRENT_COUNT - LAST_COUNT))
            CONSECUTIVE=$((CONSECUTIVE + new_kerchunks))

            log "Kerchunk detected (count: ${CURRENT_COUNT}, consecutive: ${CONSECUTIVE})"

            # Check if we've reached the threshold
            if [[ $CONSECUTIVE -ge $KERCHUNK_THRESHOLD ]]; then
                log "Kerchunk threshold reached (${CONSECUTIVE} >= ${KERCHUNK_THRESHOLD})"

                # Check rate limiting
                if check_rate_limit; then
                    # Wait a moment for the transmission to fully end
                    sleep 2

                    play_kerchunk_warning
                    LAST_WARNING=$(date +%s)
                    CONSECUTIVE=0  # Reset after warning
                else
                    log "Skipping warning due to rate limit"
                fi
            fi
        fi

        # Check if normal keyup occurred (reset consecutive on normal transmission)
        if [[ $CURRENT_KEYUPS -gt $LAST_KEYUPS ]]; then
            local keyup_delta=$((CURRENT_KEYUPS - LAST_KEYUPS))
            local kerchunk_delta=$((CURRENT_COUNT - LAST_COUNT))

            # If more keyups than kerchunks, at least one was a normal transmission
            if [[ $keyup_delta -gt $kerchunk_delta ]]; then
                if [[ $CONSECUTIVE -gt 0 ]]; then
                    log "Normal transmission detected, resetting consecutive count"
                fi
                CONSECUTIVE=0
            fi
        fi

        # Update last counts
        LAST_COUNT=$CURRENT_COUNT
        LAST_KEYUPS=$CURRENT_KEYUPS

        # Write state
        write_state

        # Sleep before next poll
        sleep "$POLL_INTERVAL"
    done
}

# ==============================================================================
#    Entry Point
# ==============================================================================

# Check if feature is enabled
if [[ "${KERCHUNK_ENABLE:-0}" != "1" ]]; then
    echo "Kerchunk monitoring is disabled (KERCHUNK_ENABLE=0 in config.ini)"
    exit 0
fi

# Check if already running
check_if_running

# Write PID file
write_pid

# Start main loop
main_loop
