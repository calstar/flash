#!/bin/bash

# Mount device script for flash operations
# This script handles mounting of external storage devices

set -e

# Configuration
MOUNT_POINT="/mnt/flash"
DEVICE_PATTERN="/dev/sd*"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# List available devices
list_devices() {
    log "Available storage devices:"
    lsblk -d -o NAME,SIZE,TYPE,MOUNTPOINT | grep -E "(disk|part)"
}

# Mount device
mount_device() {
    local device=$1
    
    if [[ -z "$device" ]]; then
        log_error "No device specified"
        return 1
    fi
    
    if [[ ! -b "$device" ]]; then
        log_error "Device $device does not exist or is not a block device"
        return 1
    fi
    
    # Create mount point if it doesn't exist
    if [[ ! -d "$MOUNT_POINT" ]]; then
        log "Creating mount point: $MOUNT_POINT"
        mkdir -p "$MOUNT_POINT"
    fi
    
    # Check if device is already mounted
    if mountpoint -q "$MOUNT_POINT"; then
        log_warn "Device is already mounted at $MOUNT_POINT"
        return 0
    fi
    
    # Mount the device
    log "Mounting $device to $MOUNT_POINT"
    if mount "$device" "$MOUNT_POINT"; then
        log "Successfully mounted $device to $MOUNT_POINT"
        return 0
    else
        log_error "Failed to mount $device"
        return 1
    fi
}

# Unmount device
unmount_device() {
    if mountpoint -q "$MOUNT_POINT"; then
        log "Unmounting device from $MOUNT_POINT"
        if umount "$MOUNT_POINT"; then
            log "Successfully unmounted device"
            return 0
        else
            log_error "Failed to unmount device"
            return 1
        fi
    else
        log_warn "No device mounted at $MOUNT_POINT"
        return 0
    fi
}

# Main function
main() {
    case "${1:-}" in
        "list")
            list_devices
            ;;
        "mount")
            check_root
            mount_device "$2"
            ;;
        "unmount")
            check_root
            unmount_device
            ;;
        *)
            echo "Usage: $0 {list|mount <device>|unmount}"
            echo ""
            echo "Commands:"
            echo "  list     - List available storage devices"
            echo "  mount    - Mount a device to $MOUNT_POINT"
            echo "  unmount  - Unmount the device from $MOUNT_POINT"
            echo ""
            echo "Examples:"
            echo "  $0 list"
            echo "  $0 mount /dev/sdb1"
            echo "  $0 unmount"
            exit 1
            ;;
    esac
}

main "$@"
