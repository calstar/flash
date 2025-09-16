#!/bin/bash

# SD card mount initialization script
# Handles automatic mounting of SD cards for flash operations

set -e

# Configuration
SD_MOUNT_POINT="/mnt/sd"
AUTO_MOUNT_ENABLED=true

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[SD-MOUNT]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[SD-MOUNT]${NC} $1"
}

log_error() {
    echo -e "${RED}[SD-MOUNT]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Create mount point
create_mount_point() {
    if [[ ! -d "$SD_MOUNT_POINT" ]]; then
        log "Creating SD card mount point: $SD_MOUNT_POINT"
        mkdir -p "$SD_MOUNT_POINT"
        chmod 755 "$SD_MOUNT_POINT"
    fi
}

# Detect SD card devices
detect_sd_cards() {
    local sd_devices=()
    
    # Look for SD card devices (typically /dev/mmcblk* or /dev/sd*)
    for device in /dev/mmcblk* /dev/sd*; do
        if [[ -b "$device" ]]; then
            # Check if it's an SD card by looking at the device name or size
            local size=$(lsblk -d -n -o SIZE "$device" 2>/dev/null || echo "0")
            if [[ "$device" =~ mmcblk ]] || [[ "$size" != "0" ]]; then
                sd_devices+=("$device")
            fi
        fi
    done
    
    echo "${sd_devices[@]}"
}

# Mount SD card
mount_sd_card() {
    local device=$1
    
    if [[ -z "$device" ]]; then
        log_error "No SD card device specified"
        return 1
    fi
    
    # Check if device is already mounted
    if mountpoint -q "$SD_MOUNT_POINT"; then
        log_warn "SD card is already mounted at $SD_MOUNT_POINT"
        return 0
    fi
    
    # Create mount point
    create_mount_point
    
    # Mount the SD card
    log "Mounting SD card $device to $SD_MOUNT_POINT"
    if mount "$device" "$SD_MOUNT_POINT"; then
        log "Successfully mounted SD card $device to $SD_MOUNT_POINT"
        
        # Set appropriate permissions
        chmod 755 "$SD_MOUNT_POINT"
        
        return 0
    else
        log_error "Failed to mount SD card $device"
        return 1
    fi
}

# Unmount SD card
unmount_sd_card() {
    if mountpoint -q "$SD_MOUNT_POINT"; then
        log "Unmounting SD card from $SD_MOUNT_POINT"
        if umount "$SD_MOUNT_POINT"; then
            log "Successfully unmounted SD card"
            return 0
        else
            log_error "Failed to unmount SD card"
            return 1
        fi
    else
        log_warn "No SD card mounted at $SD_MOUNT_POINT"
        return 0
    fi
}

# Auto-detect and mount SD card
auto_mount() {
    log "Auto-detecting SD cards..."
    local sd_devices=($(detect_sd_cards))
    
    if [[ ${#sd_devices[@]} -eq 0 ]]; then
        log_warn "No SD cards detected"
        return 1
    elif [[ ${#sd_devices[@]} -eq 1 ]]; then
        log "Found SD card: ${sd_devices[0]}"
        mount_sd_card "${sd_devices[0]}"
    else
        log "Multiple SD cards detected:"
        for i in "${!sd_devices[@]}"; do
            echo "  $((i+1)). ${sd_devices[$i]}"
        done
        log_warn "Please specify which SD card to mount"
        return 1
    fi
}

# Main function
main() {
    case "${1:-}" in
        "auto")
            check_root
            auto_mount
            ;;
        "mount")
            check_root
            mount_sd_card "$2"
            ;;
        "unmount")
            check_root
            unmount_sd_card
            ;;
        "detect")
            detect_sd_cards
            ;;
        *)
            echo "Usage: $0 {auto|mount <device>|unmount|detect}"
            echo ""
            echo "Commands:"
            echo "  auto     - Auto-detect and mount SD card"
            echo "  mount    - Mount specified SD card device"
            echo "  unmount  - Unmount SD card"
            echo "  detect   - List detected SD card devices"
            echo ""
            echo "Examples:"
            echo "  $0 auto"
            echo "  $0 mount /dev/mmcblk0p1"
            echo "  $0 unmount"
            echo "  $0 detect"
            exit 1
            ;;
    esac
}

main "$@"
