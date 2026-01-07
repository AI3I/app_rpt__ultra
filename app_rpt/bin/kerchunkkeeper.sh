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
# kerchunkkeeper.sh - Monitor and discourage kerchunking behavior
# This script monitors consecutive short transmissions (kerchunks) and plays
# a polite reminder message after 2-3 consecutive kerchunks are detected.
# Messages are rate-limited to avoid harassment.
#
# USAGE: Called via cron every minute
#

set -euo pipefail

# Source common functions and configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

# ==============================================================================
#    Configuration
# ==============================================================================

# Kerchunk detection threshold (number of consecutive kerchunks before warning)
KERCHUNK_THRESHOLD="${KERCHUNK_THRESHOLD:-3}"

# Rate limiting (seconds between warning messages)
KERCHUNK_WAITLIMIT="${KERCHUNK_WAITLIMIT:-30}"  # 30 seconds

# State file locations
STATE_DIR="/tmp/app_rpt_kerchunk"
LAST_COUNT_FILE="${STATE_DIR}/last_count"
CONSECUTIVE_FILE="${STATE_DIR}/consecutive"
LAST_WARNING_FILE="${STATE_DIR}/last_warning"

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

    # Return 0 if we couldn't get the count
    if [[ -z "$kerchunks" ]] || [[ ! "$kerchunks" =~ ^[0-9]+$ ]]; then
        echo "0"
        return
    fi

    echo "$kerchunks"
}

initialize_state() {
    # Create state directory if it doesn't exist
    mkdir -p "${STATE_DIR}"

    # Initialize files if they don't exist
    [[ ! -f "${LAST_COUNT_FILE}" ]] && echo "0" > "${LAST_COUNT_FILE}"
    [[ ! -f "${CONSECUTIVE_FILE}" ]] && echo "0" > "${CONSECUTIVE_FILE}"
    [[ ! -f "${LAST_WARNING_FILE}" ]] && echo "0" > "${LAST_WARNING_FILE}"
}

read_state() {
    # Read state from files
    LAST_COUNT=$(cat "${LAST_COUNT_FILE}" 2>/dev/null || echo "0")
    CONSECUTIVE=$(cat "${CONSECUTIVE_FILE}" 2>/dev/null || echo "0")
    LAST_WARNING=$(cat "${LAST_WARNING_FILE}" 2>/dev/null || echo "0")
}

write_state() {
    # Write state to files
    echo "${LAST_COUNT}" > "${LAST_COUNT_FILE}"
    echo "${CONSECUTIVE}" > "${CONSECUTIVE_FILE}"
    echo "${LAST_WARNING}" > "${LAST_WARNING_FILE}"
}

play_kerchunk_warning() {
    # Play a polite reminder message about kerchunking
    log "Playing kerchunk reminder message"

    # Check if we have a custom message
    if [[ -f "${SOUNDS}/custom/kerchunk_reminder.ulaw" ]]; then
        asterisk -rx "rpt localplay ${MYNODE} ${SOUNDS}/custom/kerchunk_reminder" &>/dev/null
    else
        # Use default TMS5220 message: "Please identify your station"
        # This is polite and follows FCC rules without being accusatory
        asterisk -rx "rpt localplay ${MYNODE} ${SOUNDS}/_male/please" &>/dev/null
        sleep 0.3
        asterisk -rx "rpt localplay ${MYNODE} ${SOUNDS}/_male/identify" &>/dev/null
        sleep 0.3
        asterisk -rx "rpt localplay ${MYNODE} ${SOUNDS}/_male/your" &>/dev/null
        sleep 0.3
        asterisk -rx "rpt localplay ${MYNODE} ${SOUNDS}/_male/station" &>/dev/null
    fi
}

check_rate_limit() {
    # Check if we're within the rate limit window
    local now
    now=$(date +%s)
    local elapsed=$((now - LAST_WARNING))

    if [[ $elapsed -lt $KERCHUNK_WAITLIMIT ]]; then
        log "Rate limit active, ${elapsed}s since last warning (${KERCHUNK_WAITLIMIT}s limit)"
        return 1
    fi

    return 0
}

# ==============================================================================
#    Main Logic
# ==============================================================================

main() {
    # Check if kerchunk monitoring is enabled
    if [[ "${KERCHUNK_ENABLE:-0}" != "1" ]]; then
        # Silently exit if disabled
        exit 0
    fi

    # Initialize state directory and files
    initialize_state

    # Read current state
    read_state

    # Get current kerchunk count
    CURRENT_COUNT=$(get_kerchunk_count)

    # Check if count has increased
    if [[ $CURRENT_COUNT -gt $LAST_COUNT ]]; then
        # Kerchunk detected
        local new_kerchunks=$((CURRENT_COUNT - LAST_COUNT))
        CONSECUTIVE=$((CONSECUTIVE + new_kerchunks))

        log "Kerchunk detected (count: ${CURRENT_COUNT}, consecutive: ${CONSECUTIVE})"

        # Check if we've reached the threshold
        if [[ $CONSECUTIVE -ge $KERCHUNK_THRESHOLD ]]; then
            log "Kerchunk threshold reached (${CONSECUTIVE} consecutive)"

            # Check rate limiting
            if check_rate_limit; then
                play_kerchunk_warning
                LAST_WARNING=$(date +%s)
                CONSECUTIVE=0  # Reset consecutive count after warning
            else
                log "Skipping warning due to rate limit"
            fi
        fi
    else
        # No new kerchunks, check if there was a normal keyup
        local current_keyups
        current_keyups=$(asterisk -rx "rpt stats ${MYNODE}" 2>/dev/null | \
                        grep "Keyups since system initialization" | \
                        awk -F: '{print $2}' | \
                        tr -d ' ')

        # If keyups increased but kerchunks didn't, reset consecutive counter
        # This indicates a proper transmission occurred
        if [[ -n "$current_keyups" ]] && [[ "$current_keyups" =~ ^[0-9]+$ ]]; then
            if [[ -f "${STATE_DIR}/last_keyups" ]]; then
                local last_keyups
                last_keyups=$(cat "${STATE_DIR}/last_keyups")
                if [[ $current_keyups -gt $last_keyups ]]; then
                    CONSECUTIVE=0
                    log "Normal keyup detected, resetting consecutive count"
                fi
            fi
            echo "$current_keyups" > "${STATE_DIR}/last_keyups"
        fi
    fi

    # Update last count
    LAST_COUNT=$CURRENT_COUNT

    # Write state back to files
    write_state
}

# Execute main function
main "$@"
