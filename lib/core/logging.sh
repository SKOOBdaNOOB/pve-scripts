#!/bin/bash
#
# Logging System for Proxmox VM Template Wizard
# Handles log output, rotation, and different verbosity levels
#

# Import UI module for colors
source "$(dirname "${BASH_SOURCE[0]}")/ui.sh"

# Default log settings
LOG_LEVEL="info"
LOG_FILE=""
LOG_MAX_SIZE_KB=1024
LOG_BACKUP_COUNT=5
LOG_TO_SYSLOG=false
LOG_SYSLOG_FACILITY="local0"
LOG_TIMESTAMP_FORMAT="%Y-%m-%d %H:%M:%S"

# Define log levels
declare -A LOG_LEVELS
LOG_LEVELS=(
    ["debug"]=0
    ["info"]=1
    ["warning"]=2
    ["error"]=3
    ["critical"]=4
    ["none"]=100
)

# Initialize logging system
init_logging() {
    local level="${1:-$LOG_LEVEL}"
    local file="${2:-$LOG_FILE}"
    local to_syslog="${3:-$LOG_TO_SYSLOG}"

    LOG_LEVEL="$level"
    LOG_FILE="$file"
    LOG_TO_SYSLOG="$to_syslog"

    # Create log directory if a log file is specified
    if [ -n "$LOG_FILE" ]; then
        local log_dir=$(dirname "$LOG_FILE")
        if [ ! -d "$log_dir" ]; then
            mkdir -p "$log_dir" || {
                echo -e "${RED}Failed to create log directory: $log_dir${RESET}"
                LOG_FILE=""
                return 1
            }
        fi

        # Check if log file exists and is writable, or can be created
        if [ -f "$LOG_FILE" ]; then
            if [ ! -w "$LOG_FILE" ]; then
                echo -e "${RED}Log file is not writable: $LOG_FILE${RESET}"
                LOG_FILE=""
                return 1
            fi
        else
            touch "$LOG_FILE" 2>/dev/null || {
                echo -e "${RED}Cannot create log file: $LOG_FILE${RESET}"
                LOG_FILE=""
                return 1
            }
        fi

        # Check log rotation
        check_log_rotation
    fi

    # Log initialization
    log_info "Logging initialized: level=$LOG_LEVEL, file=$LOG_FILE, syslog=$LOG_TO_SYSLOG"
    return 0
}

# Check if log file needs rotation
check_log_rotation() {
    if [ -z "$LOG_FILE" ] || [ ! -f "$LOG_FILE" ]; then
        return
    fi

    # Get log file size in KB
    local size_kb=$(du -k "$LOG_FILE" | cut -f1)

    if [ "$size_kb" -gt "$LOG_MAX_SIZE_KB" ]; then
        log_debug "Rotating log file: $LOG_FILE (size: ${size_kb}KB, max: ${LOG_MAX_SIZE_KB}KB)"

        # Shift backup files
        for (( i=LOG_BACKUP_COUNT-1; i>0; i-- )); do
            if [ -f "${LOG_FILE}.$i" ]; then
                mv "${LOG_FILE}.$i" "${LOG_FILE}.$((i+1))"
            fi
        done

        # Move current log to .1
        mv "$LOG_FILE" "${LOG_FILE}.1"

        # Create new log file
        touch "$LOG_FILE"

        log_info "Log rotated: $LOG_FILE"
    fi
}

# Internal function to write to log
_log() {
    local level="$1"
    local message="$2"
    local log_level_num=${LOG_LEVELS[$level]}
    local current_level_num=${LOG_LEVELS[$LOG_LEVEL]}

    # Skip if message level is below current log level
    if [ "$log_level_num" -lt "$current_level_num" ]; then
        return
    fi

    # Format timestamp
    local timestamp=$(date +"$LOG_TIMESTAMP_FORMAT")

    # Format log entry
    local entry="[$timestamp] [$level] $message"

    # Add to log file if specified
    if [ -n "$LOG_FILE" ]; then
        echo "$entry" >> "$LOG_FILE"
        check_log_rotation
    fi

    # Send to syslog if enabled
    if [ "$LOG_TO_SYSLOG" = true ]; then
        local syslog_priority
        case "$level" in
            debug) syslog_priority="debug" ;;
            info) syslog_priority="info" ;;
            warning) syslog_priority="warning" ;;
            error) syslog_priority="err" ;;
            critical) syslog_priority="crit" ;;
            *) syslog_priority="notice" ;;
        esac

        logger -p "${LOG_SYSLOG_FACILITY}.${syslog_priority}" -t "pve-template-wizard" "$message"
    fi

    # Always output to console with color
    case "$level" in
        debug) echo -e "${MAGENTA}[DEBUG] $message${RESET}" ;;
        info) echo -e "${BLUE}[INFO] $message${RESET}" ;;
        warning) echo -e "${YELLOW}[WARNING] $message${RESET}" ;;
        error) echo -e "${RED}[ERROR] $message${RESET}" ;;
        critical) echo -e "${BOLD}${RED}[CRITICAL] $message${RESET}" ;;
    esac
}

# Function to log debug message
log_debug() {
    _log "debug" "$1"
}

# Function to log info message
log_info() {
    _log "info" "$1"
}

# Function to log warning message
log_warning() {
    _log "warning" "$1"
}

# Function to log error message
log_error() {
    _log "error" "$1"
}

# Function to log critical message
log_critical() {
    _log "critical" "$1"
}

# Function to log and exit on fatal error
log_fatal() {
    _log "critical" "FATAL: $1"
    exit 1
}

# Function to log command execution
log_command() {
    local cmd="$1"
    local description="${2:-Executing command}"

    log_debug "$description: $cmd"

    # Execute command and capture output
    local output
    local status

    output=$($cmd 2>&1)
    status=$?

    if [ $status -eq 0 ]; then
        log_debug "Command succeeded"
        [ -n "$output" ] && log_debug "Output: $output"
    else
        log_error "Command failed with exit code $status"
        [ -n "$output" ] && log_error "Output: $output"
    fi

    return $status
}

# Function to configure logging
configure_logging() {
    section_header "Configure Logging"

    # Log level
    local log_options=("None" "Error only" "Warning & Error" "Info, Warning & Error" "Debug & All")
    show_menu "Select log verbosity level" "${log_options[@]}"

    case $MENU_SELECTION in
        0) LOG_LEVEL="none" ;;
        1) LOG_LEVEL="error" ;;
        2) LOG_LEVEL="warning" ;;
        3) LOG_LEVEL="info" ;;
        4) LOG_LEVEL="debug" ;;
    esac

    # Log file
    if prompt_yes_no "Would you like to write logs to a file?" "N"; then
        LOG_FILE=$(prompt_value "Enter log file path" "${HOME}/.pve-template-wizard/logs/wizard.log")

        # Max size
        LOG_MAX_SIZE_KB=$(prompt_value "Enter maximum log file size in KB" "$LOG_MAX_SIZE_KB" "^[0-9]+$")

        # Backup count
        LOG_BACKUP_COUNT=$(prompt_value "Enter number of log backups to keep" "$LOG_BACKUP_COUNT" "^[0-9]+$")
    else
        LOG_FILE=""
    fi

    # Syslog
    if prompt_yes_no "Would you like to send logs to syslog?" "N"; then
        LOG_TO_SYSLOG=true

        # Facility
        local syslog_facilities=("user" "local0" "local1" "local2" "local3" "local4" "local5" "local6" "local7")
        show_menu "Select syslog facility" "${syslog_facilities[@]}"
        LOG_SYSLOG_FACILITY="${syslog_facilities[$MENU_SELECTION]}"
    else
        LOG_TO_SYSLOG=false
    fi

    # Initialize with new settings
    init_logging "$LOG_LEVEL" "$LOG_FILE" "$LOG_TO_SYSLOG"

    show_success "Logging configured: level=$LOG_LEVEL, file=$LOG_FILE, syslog=$LOG_TO_SYSLOG"
}
