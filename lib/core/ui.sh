#!/bin/bash
#
# UI Utilities for Proxmox VM Template Wizard
# Handles all user interface elements including text formatting, messages, prompts, and menus
#

# Text formatting
BOLD="\033[1m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
RESET="\033[0m"

# Function to display a header
show_header() {
    clear
    echo -e "${BOLD}${BLUE}============================================${RESET}"
    echo -e "${BOLD}${BLUE}  Proxmox VM Template Creation Wizard      ${RESET}"
    echo -e "${BOLD}${BLUE}============================================${RESET}"
    echo ""
}

# Function to display a section header
section_header() {
    echo ""
    echo -e "${BOLD}${CYAN}== $1 ==${RESET}"
    echo ""
}

# Function to show a success message
show_success() {
    echo -e "${GREEN}✓ $1${RESET}"
}

# Function to show an error message
show_error() {
    echo -e "${RED}✗ $1${RESET}"
}

# Function to show a warning message
show_warning() {
    echo -e "${YELLOW}⚠ $1${RESET}"
}

# Function to show an info message
show_info() {
    echo -e "${BLUE}ℹ $1${RESET}"
}

# Function to prompt for yes/no
prompt_yes_no() {
    local prompt="$1"
    local default="$2"
    local response

    if [[ "$default" == "Y" ]]; then
        prompt="$prompt [Y/n]"
    else
        prompt="$prompt [y/N]"
    fi

    while true; do
        read -p "$prompt " response
        response=${response:-$default}
        local response_lower=$(echo "$response" | tr '[:upper:]' '[:lower:]')
        case "$response_lower" in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

# Function to prompt for a value with validation
prompt_value() {
    local prompt="$1"
    local default="$2"
    local validation="$3"
    local value

    while true; do
        read -p "$prompt [${default}]: " value
        value=${value:-$default}

        if [[ -z "$validation" ]] || [[ "$value" =~ $validation ]]; then
            echo "$value"
            return
        else
            show_error "Invalid input. Please try again."
        fi
    done
}

# Global variable for menu selection
MENU_SELECTION=0

# Function to display a menu and get selection
show_menu() {
    local title="$1"
    shift
    local options=("$@")
    local selection
    local attempts=0
    local max_attempts=5

    section_header "$title"

    for i in "${!options[@]}"; do
        echo "  $((i+1)). ${options[$i]}"
    done

    echo ""
    echo -e "${BLUE}(Enter a number from 1-${#options[@]}, or 'q' to go back)${RESET}"

    while true; do
        if [[ $attempts -ge $max_attempts ]]; then
            show_warning "Too many invalid attempts. Returning to previous menu..."
            sleep 1
            return 255  # Special return code to indicate max attempts reached
        fi

        read -p "Enter selection [1-${#options[@]}]: " selection

        # Check for exit command
        local selection_lower=$(echo "$selection" | tr '[:upper:]' '[:lower:]')
        if [[ "$selection_lower" == "q" || "$selection_lower" == "quit" || "$selection_lower" == "exit" ]]; then
            show_info "Returning to previous menu..."
            sleep 0.5
            return 254  # Special return code to indicate user requested exit
        fi

        # Validate input
        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#options[@]}" ]; then
            MENU_SELECTION=$((selection-1))
            return 0
        else
            ((attempts++))
            show_error "Invalid selection. Please enter a number between 1 and ${#options[@]}."
            sleep 0.5  # Short delay to prevent spam
        fi
    done
}

# Function to show progress with spinner
show_progress() {
    local message="$1"
    local pid=$!
    local spin='-\|/'
    local i=0

    echo -ne "${message} "

    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) % 4 ))
        echo -ne "\b${spin:$i:1}"
        sleep .1
    done

    echo -ne "\b "
    echo
}
