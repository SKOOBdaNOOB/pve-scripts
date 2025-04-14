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
        case "${response,,}" in
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

    section_header "$title"

    for i in "${!options[@]}"; do
        echo "  $((i+1)). ${options[$i]}"
    done

    echo ""
    while true; do
        read -p "Enter selection [1-${#options[@]}]: " selection

        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#options[@]}" ]; then
            MENU_SELECTION=$((selection-1))
            return
        else
            show_error "Invalid selection. Please try again."
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
