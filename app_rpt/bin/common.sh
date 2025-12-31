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

# ==============================================================================
#    common.sh - Shared initialization for app_rpt__ultra scripts
# ==============================================================================
#
#    This file is sourced by all app_rpt scripts to provide:
#    - Bash safety settings
#    - Configuration loading and validation
#    - Common utility functions
#
#    The %%BASEDIR%% placeholder is replaced by install.sh during installation.
#

set -euo pipefail

# Installation directory (replaced by install.sh)
readonly SCRIPT_DIR="%%BASEDIR%%/bin"
readonly CONFIG_FILE="%%BASEDIR%%/config.ini"

# Validate config exists before sourcing
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: Config file not found: $CONFIG_FILE" >&2
    echo "       Please run install.sh or verify your installation." >&2
    exit 1
fi

# Source the configuration
source "$CONFIG_FILE"

# ==============================================================================
#    Configuration Validation
# ==============================================================================

# Validate that essential config variables are set
validate_config() {
    local missing=()

    # Core required variables
    [[ -z "${MYNODE:-}" ]] && missing+=("MYNODE")
    [[ -z "${BASEDIR:-}" ]] && missing+=("BASEDIR")
    [[ -z "${SOUNDS:-}" ]] && missing+=("SOUNDS")
    [[ -z "${BINDIR:-}" ]] && missing+=("BINDIR")
    [[ -z "${RPTCONF:-}" ]] && missing+=("RPTCONF")

    # Sound directories
    [[ -z "${SNDMALE:-}" ]] && missing+=("SNDMALE")
    [[ -z "${SNDFEMALE:-}" ]] && missing+=("SNDFEMALE")
    [[ -z "${SNDRPT:-}" ]] && missing+=("SNDRPT")

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "ERROR: Missing required config variables: ${missing[*]}" >&2
        echo "       Please check $CONFIG_FILE" >&2
        exit 1
    fi
}

# Run validation on load
validate_config

# ==============================================================================
#    Logging Functions
# ==============================================================================

# Log file location
readonly LOG_FILE="/var/log/app_rpt.log"

# Log a message with timestamp
# Usage: log "message"
log() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$$] $*" >> "$LOG_FILE" 2>/dev/null || true
}

# Log and echo to stderr
# Usage: log_error "error message"
log_error() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "ERROR: $*" >&2
    echo "[$timestamp] [$$] ERROR: $*" >> "$LOG_FILE" 2>/dev/null || true
}

# ==============================================================================
#    Error Handling Functions
# ==============================================================================

# Play error sound and exit
# Usage: die_with_error "error message"
die_with_error() {
    log_error "$*"
    asterisk -rx "rpt localplay $MYNODE rpt/program_error" 2>/dev/null || true
    exit 1
}

# Exit with error message (no sound)
# Usage: die "error message"
die() {
    log_error "$*"
    exit 1
}

# ==============================================================================
#    Validation Functions
# ==============================================================================

# Check if a required variable is set
# Usage: require_var "VARNAME"
require_var() {
    local varname="$1"
    if [[ -z "${!varname:-}" ]]; then
        die "Required variable $varname is not set in config"
    fi
}

# Check if a required command exists
# Usage: require_cmd "command"
require_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then
        die "Required command not found: $cmd"
    fi
}

# Check if a file exists
# Usage: require_file "/path/to/file"
require_file() {
    local filepath="$1"
    if [[ ! -f "$filepath" ]]; then
        die "Required file not found: $filepath"
    fi
}

# ==============================================================================
#    Asterisk Helper Functions
# ==============================================================================

# Execute asterisk command safely
# Usage: ast_cmd "rpt localplay $MYNODE rpt/message"
ast_cmd() {
    asterisk -rx "$*" 2>/dev/null || log_error "Asterisk command failed: $*"
}

# Play a local audio file
# Usage: ast_play "rpt/message"
ast_play() {
    ast_cmd "rpt localplay $MYNODE $1"
}

###EDIT: Tue Dec 31 2025
