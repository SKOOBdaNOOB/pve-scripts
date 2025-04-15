#!/usr/bin/env bash

# Copyright (c) 2025
# License: MIT

function header_info {
  clear
  cat <<"EOF"
    __  ____                 __           __    _
   / / / / /_  __  ______  _/ /___  __   / /   (_)___  __  ___  __
  / / / / __ \/ / / / __ \/ __/ / / /  / /   / / __ \/ / / / |/_/
 / /_/ / /_/ / /_/ / / / / /_/ /_/ /  / /___/ / / / / /_/ />  <
 \____/_.___/\__,_/_/ /_/\__/\__,_/  /_____/_/_/ /_/\__,_/_/|_|

EOF
}

header_info
echo -e "\n Loading..."

# Configuration
GEN_MAC=02:$(openssl rand -hex 5 | awk '{print toupper($0)}' | sed 's/\(..\)/\1:/g; s/.$//')
NEXTID=$(pvesh get /cluster/nextid)
TEMP_DIR=$(mktemp -d)
CLEANUP_ON_EXIT=true
UBUNTU_VERSION="noble"
UBUNTU_URL="https://cloud-images.ubuntu.com/${UBUNTU_VERSION}/current/${UBUNTU_VERSION}-server-cloudimg-amd64.img"
DISK_SIZE="16G"

# Text formatting
BOLD="\033[1m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
RESET="\033[m"
BFR="\\r\\033[K"
HOLD=" "
CM="${GREEN}✓${RESET}"
CROSS="${RED}✗${RESET}"
THIN="discard=on,ssd=1,"
SPINNER_PID=""

# Error handling
set -Eeuo pipefail
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR
trap cleanup EXIT
trap 'echo -e "\n${RED}Script interrupted.${RESET}"; exit 1' SIGINT SIGTERM

function error_handler() {
  if [ -n "$SPINNER_PID" ] && ps -p $SPINNER_PID > /dev/null; then kill $SPINNER_PID > /dev/null; fi
  printf "\e[?25h"
  local exit_code="$?"
  local line_number="$1"
  local command="$2"
  local error_message="${RED}[ERROR]${RESET} in line ${RED}$line_number${RESET}: exit code ${RED}$exit_code${RESET}: while executing command ${YELLOW}$command${RESET}"
  echo -e "\n$error_message\n"
  cleanup_vmid
}

function cleanup_vmid() {
  if qm status $VMID &>/dev/null; then
    qm stop $VMID &>/dev/null
    qm destroy $VMID &>/dev/null
  fi
}

function cleanup() {
  if [ "$CLEANUP_ON_EXIT" = true ]; then
    rm -rf $TEMP_DIR
  fi
}

function spinner() {
  local chars="/-\|"
  local spin_i=0
  printf "\e[?25l"
  while true; do
    printf "\r \e[36m%s\e[0m" "${chars:spin_i++%${#chars}:1}"
    sleep 0.1
  done
}

function msg_info() {
  local msg="$1"
  echo -ne " ${HOLD} ${YELLOW}${msg}   "
  spinner &
  SPINNER_PID=$!
}

function msg_ok() {
  if [ -n "$SPINNER_PID" ] && ps -p $SPINNER_PID > /dev/null; then kill $SPINNER_PID > /dev/null; fi
  printf "\e[?25h"
  local msg="$1"
  echo -e "${BFR} ${CM} ${GREEN}${msg}${RESET}"
}

function msg_error() {
  if [ -n "$SPINNER_PID" ] && ps -p $SPINNER_PID > /dev/null; then kill $SPINNER_PID > /dev/null; fi
  printf "\e[?25h"
  local msg="$1"
  echo -e "${BFR} ${CROSS} ${RED}${msg}${RESET}"
}

function check_root() {
  if [[ "$(id -u)" -ne 0 || $(ps -o comm= -p $PPID) == "sudo" ]]; then
    clear
    msg_error "Please run this script as root."
    echo -e "\nExiting..."
    sleep 2
    exit
  fi
}

function pve_check() {
  if ! pveversion &>/dev/null; then
    msg_error "This script must be run on a Proxmox VE node."
    echo -e "Exiting..."
    sleep 2
    exit
  fi
}

function arch_check() {
  if [ "$(dpkg --print-architecture)" != "amd64" ]; then
    msg_error "This script will only work on 64-bit (amd64) systems."
    echo -e "Exiting..."
    sleep 2
    exit
  fi
}

function ssh_check() {
  if command -v pveversion >/dev/null 2>&1; then
    if [ -n "${SSH_CLIENT:+x}" ]; then
      if whiptail --backtitle "Proxmox VE Helper Scripts" --defaultno --title "SSH DETECTED" --yesno "It's suggested to use the Proxmox shell instead of SSH, since SSH can create issues while gathering variables. Would you like to proceed with using SSH?" 10 62; then
        echo "you've been warned"
      else
        clear
        exit
      fi
    fi
  fi
}

function exit_script() {
  clear
  echo -e "⚠  User exited script \n"
  exit
}

function default_settings() {
  VMID="$NEXTID"
  FORMAT=",efitype=4m"
  MACHINE=""
  DISK_CACHE="cache=writethrough,"
  HN="ubuntu-vm"
  CPU_TYPE=" -cpu host"
  CORE_COUNT="2"
  RAM_SIZE="2048"
  BRG="vmbr0"
  MAC="$GEN_MAC"
  VLAN=""
  MTU=""
  START_VM="yes"
  CI_USER="ubuntu"
  CI_PASSWORD="ubuntu"
  CI_SSH_KEY=""
  CI_IP_CONFIG="dhcp"
  CI_IP_ADDR=""
  CI_GATEWAY=""
  CI_DNS=""
  METHOD="default"

  echo -e "${YELLOW}Using Ubuntu Version: ${BLUE}${UBUNTU_VERSION}${RESET}"
  echo -e "${YELLOW}Using Virtual Machine ID: ${BLUE}${VMID}${RESET}"
  echo -e "${YELLOW}Using Machine Type: ${BLUE}i440fx${RESET}"
  echo -e "${YELLOW}Using Disk Cache: ${BLUE}Write Through${RESET}"
  echo -e "${YELLOW}Using Hostname: ${BLUE}${HN}${RESET}"
  echo -e "${YELLOW}Using CPU Model: ${BLUE}Host${RESET}"
  echo -e "${YELLOW}Allocated Cores: ${BLUE}${CORE_COUNT}${RESET}"
  echo -e "${YELLOW}Allocated RAM: ${BLUE}${RAM_SIZE}${RESET}"
  echo -e "${YELLOW}Using Bridge: ${BLUE}${BRG}${RESET}"
  echo -e "${YELLOW}Using MAC Address: ${BLUE}${MAC}${RESET}"
  echo -e "${YELLOW}Using VLAN: ${BLUE}Default${RESET}"
  echo -e "${YELLOW}Using Interface MTU Size: ${BLUE}Default${RESET}"
  echo -e "${YELLOW}Using Cloud-Init User: ${BLUE}${CI_USER}${RESET}"
  echo -e "${YELLOW}Using Cloud-Init IP Config: ${BLUE}${CI_IP_CONFIG}${RESET}"
  echo -e "${YELLOW}Start VM when completed: ${BLUE}yes${RESET}"
  echo -e "${BLUE}Creating an Ubuntu VM using the above default settings${RESET}"
}

function advanced_settings() {
  METHOD="advanced"

  while true; do
    if VMID=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set Virtual Machine ID" 8 58 $NEXTID --title "VIRTUAL MACHINE ID" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
      if [ -z "$VMID" ]; then
        VMID="$NEXTID"
      fi
      if pct status "$VMID" &>/dev/null || qm status "$VMID" &>/dev/null; then
        echo -e "${CROSS}${RED} ID $VMID is already in use${RESET}"
        sleep 2
        continue
      fi
      echo -e "${YELLOW}Virtual Machine ID: ${BLUE}$VMID${RESET}"
      break
    else
      exit_script
    fi
  done

  if MACH=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "MACHINE TYPE" --radiolist --cancel-button Exit-Script "Choose Type" 10 58 2 \
    "i440fx" "Machine i440fx" ON \
    "q35" "Machine q35" OFF \
    3>&1 1>&2 2>&3); then
    if [ $MACH = q35 ]; then
      echo -e "${YELLOW}Using Machine Type: ${BLUE}$MACH${RESET}"
      FORMAT=""
      MACHINE=" -machine q35"
    else
      echo -e "${YELLOW}Using Machine Type: ${BLUE}$MACH${RESET}"
      FORMAT=",efitype=4m"
      MACHINE=""
    fi
  else
    exit_script
  fi

  if DISK_CACHE1=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "DISK CACHE" --radiolist "Choose" --cancel-button Exit-Script 10 58 2 \
    "0" "None" OFF \
    "1" "Write Through (Default)" ON \
    3>&1 1>&2 2>&3); then
    if [ $DISK_CACHE1 = "1" ]; then
      echo -e "${YELLOW}Using Disk Cache: ${BLUE}Write Through${RESET}"
      DISK_CACHE="cache=writethrough,"
    else
      echo -e "${YELLOW}Using Disk Cache: ${BLUE}None${RESET}"
      DISK_CACHE=""
    fi
  else
    exit_script
  fi

  if VM_NAME=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set Hostname" 8 58 ubuntu-vm --title "HOSTNAME" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $VM_NAME ]; then
      HN="ubuntu-vm"
      echo -e "${YELLOW}Using Hostname: ${BLUE}$HN${RESET}"
    else
      HN=$(echo ${VM_NAME,,} | tr -d ' ')
      echo -e "${YELLOW}Using Hostname: ${BLUE}$HN${RESET}"
    fi
  else
    exit_script
  fi

  if CPU_TYPE1=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "CPU MODEL" --radiolist "Choose" --cancel-button Exit-Script 10 58 2 \
    "0" "KVM64" OFF \
    "1" "Host (Default)" ON \
    3>&1 1>&2 2>&3); then
    if [ $CPU_TYPE1 = "1" ]; then
      echo -e "${YELLOW}Using CPU Model: ${BLUE}Host${RESET}"
      CPU_TYPE=" -cpu host"
    else
      echo -e "${YELLOW}Using CPU Model: ${BLUE}KVM64${RESET}"
      CPU_TYPE=""
    fi
  else
    exit_script
  fi

  if CORE_COUNT=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Allocate CPU Cores" 8 58 2 --title "CORE COUNT" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $CORE_COUNT ]; then
      CORE_COUNT="2"
      echo -e "${YELLOW}Allocated Cores: ${BLUE}$CORE_COUNT${RESET}"
    else
      echo -e "${YELLOW}Allocated Cores: ${BLUE}$CORE_COUNT${RESET}"
    fi
  else
    exit_script
  fi

  if RAM_SIZE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Allocate RAM in MiB" 8 58 2048 --title "RAM" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $RAM_SIZE ]; then
      RAM_SIZE="2048"
      echo -e "${YELLOW}Allocated RAM: ${BLUE}$RAM_SIZE${RESET}"
    else
      echo -e "${YELLOW}Allocated RAM: ${BLUE}$RAM_SIZE${RESET}"
    fi
  else
    exit_script
  fi

  if BRG=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set a Bridge" 8 58 vmbr0 --title "BRIDGE" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $BRG ]; then
      BRG="vmbr0"
      echo -e "${YELLOW}Using Bridge: ${BLUE}$BRG${RESET}"
    else
      echo -e "${YELLOW}Using Bridge: ${BLUE}$BRG${RESET}"
    fi
  else
    exit_script
  fi

  if MAC1=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set a MAC Address" 8 58 $GEN_MAC --title "MAC ADDRESS" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $MAC1 ]; then
      MAC="$GEN_MAC"
      echo -e "${YELLOW}Using MAC Address: ${BLUE}$MAC${RESET}"
    else
      MAC="$MAC1"
      echo -e "${YELLOW}Using MAC Address: ${BLUE}$MAC1${RESET}"
    fi
  else
    exit_script
  fi

  if VLAN1=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set a Vlan(leave blank for default)" 8 58 --title "VLAN" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $VLAN1 ]; then
      VLAN1="Default"
      VLAN=""
      echo -e "${YELLOW}Using Vlan: ${BLUE}$VLAN1${RESET}"
    else
      VLAN=",tag=$VLAN1"
      echo -e "${YELLOW}Using Vlan: ${BLUE}$VLAN1${RESET}"
    fi
  else
    exit_script
  fi

  if MTU1=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set Interface MTU Size (leave blank for default)" 8 58 --title "MTU SIZE" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $MTU1 ]; then
      MTU1="Default"
      MTU=""
      echo -e "${YELLOW}Using Interface MTU Size: ${BLUE}$MTU1${RESET}"
    else
      MTU=",mtu=$MTU1"
      echo -e "${YELLOW}Using Interface MTU Size: ${BLUE}$MTU1${RESET}"
    fi
  else
    exit_script
  fi

  # Cloud-Init User Configuration
  if CI_USERNAME=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set Cloud-Init Username" 8 58 ubuntu --title "CLOUD-INIT USERNAME" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $CI_USERNAME ]; then
      CI_USER="ubuntu"
      echo -e "${YELLOW}Using Cloud-Init Username: ${BLUE}$CI_USER${RESET}"
    else
      CI_USER="$CI_USERNAME"
      echo -e "${YELLOW}Using Cloud-Init Username: ${BLUE}$CI_USER${RESET}"
    fi
  else
    exit_script
  fi

  if CI_PASS=$(whiptail --backtitle "Proxmox VE Helper Scripts" --passwordbox "Set Cloud-Init Password" 8 58 --title "CLOUD-INIT PASSWORD" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z "$CI_PASS" ]; then
      CI_PASSWORD="ubuntu"
      echo -e "${YELLOW}Using Cloud-Init Password: ${BLUE}Default Password${RESET}"
    else
      CI_PASSWORD="$CI_PASS"
      echo -e "${YELLOW}Using Cloud-Init Password: ${BLUE}Custom Password${RESET}"
    fi
  else
    exit_script
  fi

  if CI_SSHKEY=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set Cloud-Init SSH Key (leave blank for none)" 8 58 --title "CLOUD-INIT SSH KEY" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z "$CI_SSHKEY" ]; then
      CI_SSH_KEY=""
      echo -e "${YELLOW}Using Cloud-Init SSH Key: ${BLUE}None${RESET}"
    else
      CI_SSH_KEY="$CI_SSHKEY"
      echo -e "${YELLOW}Using Cloud-Init SSH Key: ${BLUE}Custom SSH Key${RESET}"
    fi
  else
    exit_script
  fi

  # Network Configuration
  if IP_CONFIG=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "IP CONFIGURATION" --radiolist --cancel-button Exit-Script "Choose IP Configuration" 10 58 2 \
    "dhcp" "DHCP (Automatic IP)" ON \
    "static" "Static IP" OFF \
    3>&1 1>&2 2>&3); then
    CI_IP_CONFIG="$IP_CONFIG"
    echo -e "${YELLOW}Using IP Configuration: ${BLUE}$CI_IP_CONFIG${RESET}"

    if [ "$CI_IP_CONFIG" = "static" ]; then
      if CI_IPADDR=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set Static IP Address (CIDR format, e.g., 192.168.1.100/24)" 8 58 --title "STATIC IP ADDRESS" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
        if [ -z "$CI_IPADDR" ]; then
          msg_error "Static IP address is required for static configuration."
          exit_script
        else
          CI_IP_ADDR="$CI_IPADDR"
          echo -e "${YELLOW}Using Static IP Address: ${BLUE}$CI_IP_ADDR${RESET}"
        fi
      else
        exit_script
      fi

      if CI_GW=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set Gateway IP Address" 8 58 --title "GATEWAY" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
        if [ -z "$CI_GW" ]; then
          msg_error "Gateway is required for static configuration."
          exit_script
        else
          CI_GATEWAY="$CI_GW"
          echo -e "${YELLOW}Using Gateway: ${BLUE}$CI_GATEWAY${RESET}"
        fi
      else
        exit_script
      fi

      if CI_NAMESERVER=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set DNS Server(s) (comma-separated)" 8 58 "8.8.8.8,1.1.1.1" --title "DNS SERVERS" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
        if [ -z "$CI_NAMESERVER" ]; then
          CI_DNS="8.8.8.8,1.1.1.1"
          echo -e "${YELLOW}Using DNS Servers: ${BLUE}$CI_DNS${RESET}"
        else
          CI_DNS="$CI_NAMESERVER"
          echo -e "${YELLOW}Using DNS Servers: ${BLUE}$CI_DNS${RESET}"
        fi
      else
        exit_script
      fi
    fi
  else
    exit_script
  fi

  if (whiptail --backtitle "Proxmox VE Helper Scripts" --title "START VIRTUAL MACHINE" --yesno "Start VM when completed?" 10 58); then
    echo -e "${YELLOW}Start VM when completed: ${BLUE}yes${RESET}"
    START_VM="yes"
  else
    echo -e "${YELLOW}Start VM when completed: ${BLUE}no${RESET}"
    START_VM="no"
  fi

  if (whiptail --backtitle "Proxmox VE Helper Scripts" --title "ADVANCED SETTINGS COMPLETE" --yesno "Ready to create Ubuntu VM?" --no-button Do-Over 10 58); then
    echo -e "${RED}Creating an Ubuntu VM using the above advanced settings${RESET}"
  else
    header_info
    echo -e "${RED}Using Advanced Settings${RESET}"
    advanced_settings
  fi
}

function start_script() {
  if (whiptail --backtitle "Proxmox VE Helper Scripts" --title "SETTINGS" --yesno "Use Default Settings?" --no-button Advanced 10 58); then
    header_info
    echo -e "${BLUE}Using Default Settings${RESET}"
    default_settings
  else
    header_info
    echo -e "${RED}Using Advanced Settings${RESET}"
    advanced_settings
  fi
}

check_root
arch_check
pve_check
ssh_check
start_script

msg_info "Validating Storage"
while read -r line; do
  TAG=$(echo $line | awk '{print $1}')
  TYPE=$(echo $line | awk '{printf "%-10s", $2}')
  FREE=$(echo $line | numfmt --field 4-6 --from-unit=K --to=iec --format %.2f | awk '{printf( "%9sB", $6)}')
  ITEM="  Type: $TYPE Free: $FREE "
  OFFSET=2
  if [[ $((${#ITEM} + $OFFSET)) -gt ${MSG_MAX_LENGTH:-} ]]; then
    MSG_MAX_LENGTH=$((${#ITEM} + $OFFSET))
  fi
  STORAGE_MENU+=("$TAG" "$ITEM" "OFF")
done < <(pvesm status -content images | awk 'NR>1')
VALID=$(pvesm status -content images | awk 'NR>1')
if [ -z "$VALID" ]; then
  msg_error "Unable to detect a valid storage location."
  exit
elif [ $((${#STORAGE_MENU[@]} / 3)) -eq 1 ]; then
  STORAGE=${STORAGE_MENU[0]}
else
  while [ -z "${STORAGE:+x}" ]; do
    if [ -n "$SPINNER_PID" ] && ps -p $SPINNER_PID > /dev/null; then kill $SPINNER_PID > /dev/null; fi
    printf "\e[?25h"
    STORAGE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "Storage Pools" --radiolist \
      "Which storage pool you would like to use for ${HN}?\nTo make a selection, use the Spacebar.\n" \
      16 $(($MSG_MAX_LENGTH + 23)) 6 \
      "${STORAGE_MENU[@]}" 3>&1 1>&2 2>&3) || exit
  done
fi
msg_ok "Using ${RESET}${BLUE}$STORAGE${RESET} ${GREEN}for Storage Location."
msg_ok "Virtual Machine ID is ${RESET}${BLUE}$VMID${RESET}."

msg_info "Retrieving Ubuntu ${UBUNTU_VERSION} Cloud Image"
URL=$UBUNTU_URL
wget -q --show-progress $URL -O $TEMP_DIR/ubuntu-cloud.img
echo -en "\e[1A\e[0K"
msg_ok "Downloaded ${RESET}${BLUE}ubuntu-${UBUNTU_VERSION}-server-cloudimg-amd64.img${RESET}"

STORAGE_TYPE=$(pvesm status -storage $STORAGE | awk 'NR>1 {print $2}')
case $STORAGE_TYPE in
nfs | dir)
  DISK_EXT=".raw"
  DISK_REF="$VMID/"
  DISK_IMPORT="-format raw"
  THIN=""
  ;;
btrfs | local-zfs)
  DISK_EXT=".raw"
  DISK_REF="$VMID/"
  DISK_IMPORT="-format raw"
  FORMAT=",efitype=4m"
  THIN=""
  ;;
esac

msg_info "Creating Ubuntu VM"
qm create $VMID -agent 1${MACHINE} -tablet 0 -localtime 1 -bios ovmf${CPU_TYPE} -cores $CORE_COUNT -memory $RAM_SIZE \
  -name $HN -tags ubuntu-linux -net0 virtio,bridge=$BRG,macaddr=$MAC$VLAN$MTU -onboot 1 -ostype l26 -scsihw virtio-scsi-pci

# Create EFI disk
msg_info "Creating EFI disk"
pvesm alloc $STORAGE $VMID vm-${VMID}-disk-1 4M 1>&/dev/null

# Import the disk
msg_info "Importing disk image"
qm importdisk $VMID $TEMP_DIR/ubuntu-cloud.img $STORAGE ${DISK_IMPORT:-} 1>&/dev/null

# Configure the VM
msg_info "Configuring VM settings"
qm set $VMID \
  -efidisk0 ${STORAGE}:vm-${VMID}-disk-1${FORMAT} \
  -scsi0 ${STORAGE}:vm-${VMID}-disk-0,${DISK_CACHE}${THIN}size=${DISK_SIZE} \
  -boot order=scsi0 \
  -serial0 socket \
  -vga serial0 \
  -ide2 ${STORAGE}:cloudinit \
  -description "Ubuntu ${UBUNTU_VERSION} VM created by script" >/dev/null

# Configure cloud-init
msg_info "Configuring cloud-init"
qm set $VMID --ciuser "$CI_USER" >/dev/null
qm set $VMID --cipassword "$CI_PASSWORD" >/dev/null

# Ensure cloud-init is properly configured
if [ -n "$CI_SSH_KEY" ]; then
  echo "$CI_SSH_KEY" > $TEMP_DIR/ssh_key.pub
  qm set $VMID --sshkeys $TEMP_DIR/ssh_key.pub >/dev/null
fi

if [ "$CI_IP_CONFIG" = "static" ]; then
  qm set $VMID --ipconfig0 "ip=$CI_IP_ADDR,gw=$CI_GATEWAY" >/dev/null

  # Set DNS servers
  if [ -n "$CI_DNS" ]; then
    qm set $VMID --nameserver "$CI_DNS" >/dev/null
  fi
else
  qm set $VMID --ipconfig0 "ip=dhcp" >/dev/null
fi

# Regenerate cloud-init config
msg_info "Regenerating cloud-init configuration"
qm cloudinit update $VMID >/dev/null

msg_ok "Created Ubuntu VM ${RESET}${BLUE}(${HN})${RESET}"

if [ "$START_VM" == "yes" ]; then
  msg_info "Starting Ubuntu VM"
  qm start $VMID
  msg_ok "Started Ubuntu VM"
fi

msg_ok "Completed Successfully!\n"
echo -e "You can access the VM console from the Proxmox web UI or via SSH once it's booted."
if [ "$CI_IP_CONFIG" = "dhcp" ]; then
  echo -e "The VM is configured to use DHCP. Check your router/DHCP server to find its IP address."
else
  echo -e "The VM is configured with static IP: $CI_IP_ADDR"
fi
echo -e "Login with username: ${BLUE}$CI_USER${RESET} and your configured password."
