#!/usr/bin/env bash
# Docker-based ZMK firmware build script
# Builds firmware for Corne keyboard with full OLED display support

set -euo pipefail

# Configuration
ZMK_DIR="${ZMK_DIR:-$HOME/git-repos/others/zmk}"
CONFIG_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TIMESTAMP="$(date +%Y%m%d-%H%M)"
OUTPUT_DIR="$CONFIG_DIR/output/$TIMESTAMP"
DOCKER_IMAGE="zmkfirmware/zmk-build-arm:stable"

# Board and shield configuration
# Note: nice_nano_v2 is now "nice_nano" with revision system in newer ZMK
BOARD="nice_nano"
SHIELD_LEFT="corne_left"
SHIELD_RIGHT="corne_right"

# Build flags
BUILD_LEFT=true
BUILD_RIGHT=true
CLEAN=false
FLASH_LEFT=false
FLASH_RIGHT=false
FORCE_BUILD=false

# Flash detection
FLASH_TIMEOUT=180
BOOTLOADER_NAME="NICENANO"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

#######################################
# Display usage information
#######################################
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Build ZMK firmware for Corne keyboard using Docker.

Options:
  -l, --left-only     Build only left half
  -r, --right-only    Build only right half
  -f, --flash         Flash firmware after build (detects bootloader automatically)
  --flash-left        Flash only left half after build
  --flash-right       Flash only right half after build
  --force             Force rebuild even if config hasn't changed
  -c, --clean         Clean output directory before build
  -h, --help          Show this help message

Build Caching:
  The script caches builds based on config file hash. If your config files
  haven't changed since the last build, it will reuse existing firmware.
  Use --force to rebuild anyway.

Environment Variables:
  ZMK_DIR             Path to ZMK repository (default: ~/git-repos/others/zmk)

Examples:
  $(basename "$0")              # Build both halves
  $(basename "$0") --left-only  # Build only left half
  $(basename "$0") -l -f        # Build and flash left half
  $(basename "$0") --flash      # Build both, then flash each when bootloader detected
  ZMK_DIR=/path/to/zmk $(basename "$0")  # Use custom ZMK path

Output:
  Firmware files will be placed in: output/<YYYYMMDD-HHMM>/
EOF
}

#######################################
# Print colored message
#######################################
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

#######################################
# Compute hash of config files
#######################################
compute_config_hash() {
    # Hash all config files that affect the build
    local hash_input=""

    # Include all files in config directory
    if [[ -d "$CONFIG_DIR/config" ]]; then
        hash_input=$(find "$CONFIG_DIR/config" -type f -exec cat {} \; 2>/dev/null | sha256sum | cut -d' ' -f1)
    fi

    echo "$hash_input"
}

#######################################
# Find the latest build with matching hash
#######################################
find_cached_build() {
    local current_hash="$1"
    local shield="$2"

    # Look for existing builds in output directory
    if [[ ! -d "$CONFIG_DIR/output" ]]; then
        return 1
    fi

    # Check each build directory (newest first)
    for build_dir in $(ls -1td "$CONFIG_DIR/output"/*/ 2>/dev/null); do
        local hash_file="$build_dir/.config_hash"
        local uf2_file="$build_dir/${shield}.uf2"

        if [[ -f "$hash_file" ]] && [[ -f "$uf2_file" ]]; then
            local stored_hash
            stored_hash=$(cat "$hash_file")
            if [[ "$stored_hash" == "$current_hash" ]]; then
                echo "$build_dir"
                return 0
            fi
        fi
    done

    return 1
}

#######################################
# Check if Docker is available
#######################################
check_docker() {
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install Docker first."
        echo "  Visit: https://docs.docker.com/get-docker/"
        exit 1
    fi

    if ! docker info &> /dev/null; then
        error "Docker daemon is not running. Please start Docker."
        exit 1
    fi

    info "Docker is available"
}

#######################################
# Check if ZMK directory exists
#######################################
check_zmk() {
    if [[ ! -d "$ZMK_DIR" ]]; then
        error "ZMK not found at $ZMK_DIR"
        echo ""
        echo "Please clone ZMK first:"
        echo "  git clone https://github.com/zmkfirmware/zmk.git $ZMK_DIR"
        exit 2
    fi

    if [[ ! -f "$ZMK_DIR/app/CMakeLists.txt" ]]; then
        error "ZMK directory exists but appears invalid (missing app/CMakeLists.txt)"
        echo "Please verify ZMK is properly cloned at: $ZMK_DIR"
        exit 2
    fi

    info "ZMK found at $ZMK_DIR"
}

#######################################
# Initialize ZMK workspace if needed
#######################################
init_zmk_workspace() {
    if [[ -d "$ZMK_DIR/.west" ]] && [[ -d "$ZMK_DIR/modules" ]]; then
        info "ZMK workspace already initialized"
        return 0
    fi

    info "Initializing ZMK workspace (first-time setup)..."
    warn "This may take several minutes..."

    docker run --rm \
        -v "$ZMK_DIR":/zmk \
        -w /zmk \
        "$DOCKER_IMAGE" \
        sh -c "
            west init -l app && \
            west update
        "

    if [[ -d "$ZMK_DIR/.west" ]]; then
        info "ZMK workspace initialized successfully"
    else
        error "Failed to initialize ZMK workspace"
        exit 3
    fi
}

#######################################
# Build firmware for one half
#######################################
build_half() {
    local shield="$1"
    local build_dir="/build/${shield}"

    info "Building $shield..."

    docker run --rm \
        -v "$ZMK_DIR":/zmk \
        -v "$CONFIG_DIR/config":/config:ro \
        -v "$OUTPUT_DIR":/output \
        -w /zmk \
        "$DOCKER_IMAGE" \
        sh -c "
            west build -s /zmk/app -b $BOARD -d $build_dir -- -DSHIELD=$shield -DZMK_CONFIG=/config && \
            cp $build_dir/zephyr/zmk.uf2 /output/${shield}.uf2
        "

    if [[ -f "$OUTPUT_DIR/${shield}.uf2" ]]; then
        info "Successfully built ${shield}.uf2"
    else
        error "Build failed for $shield"
        exit 3
    fi
}

#######################################
# Find bootloader mount point
#######################################
find_bootloader() {
    # Common mount points for nice_nano bootloader
    local mount_points=(
        "/run/media/$USER/$BOOTLOADER_NAME"
        "/media/$USER/$BOOTLOADER_NAME"
        "/mnt/$BOOTLOADER_NAME"
        "/Volumes/$BOOTLOADER_NAME"  # macOS
    )

    # Check predefined paths - but verify device is actually mounted there
    for mp in "${mount_points[@]}"; do
        if [[ -d "$mp" ]] && mountpoint -q "$mp" 2>/dev/null; then
            echo "$mp"
            return 0
        fi
    done

    # Fallback: search for any mounted volume containing bootloader name
    local found
    found=$(mount | grep -i "$BOOTLOADER_NAME" | awk '{print $3}' | head -1)
    if [[ -n "$found" ]] && mountpoint -q "$found" 2>/dev/null; then
        echo "$found"
        return 0
    fi

    # Also check /run/media/$USER for any nice nano variant
    if [[ -d "/run/media/$USER" ]]; then
        for dir in /run/media/$USER/*/; do
            if [[ -d "$dir" ]] && mountpoint -q "$dir" 2>/dev/null; then
                local basename_dir
                basename_dir=$(basename "$dir")
                if [[ "$basename_dir" == *"NANO"* || "$basename_dir" == *"NRF"* ]]; then
                    echo "${dir%/}"
                    return 0
                fi
            fi
        done
    fi

    return 1
}

#######################################
# Prompt user to select and mount device
# Sets SELECTED_MOUNT_POINT global variable
#######################################
SELECTED_MOUNT_POINT=""

prompt_mount_device() {
    SELECTED_MOUNT_POINT=""
    echo ""
    warn "No mounted bootloader found. Showing available devices:"
    echo ""
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINTS
    echo ""

    # Prompt user for device (read from terminal directly)
    read -p "Enter device to mount (e.g., sda) or press Enter to skip: " user_device </dev/tty

    if [[ -z "$user_device" ]]; then
        return 1
    fi

    # Add /dev/ prefix if not provided
    if [[ "$user_device" != /dev/* ]]; then
        user_device="/dev/$user_device"
    fi

    # Verify device exists
    if [[ ! -b "$user_device" ]]; then
        error "Device $user_device not found"
        return 1
    fi

    # Clean up leftover mount point if exists but not mounted
    if [[ -d "/mnt/$BOOTLOADER_NAME" ]] && ! mountpoint -q "/mnt/$BOOTLOADER_NAME" 2>/dev/null; then
        sudo rmdir "/mnt/$BOOTLOADER_NAME" 2>/dev/null || true
    fi

    # Create mount point and mount
    if [[ ! -d "/mnt/$BOOTLOADER_NAME" ]]; then
        sudo mkdir -p "/mnt/$BOOTLOADER_NAME"
    fi

    if sudo mount "$user_device" "/mnt/$BOOTLOADER_NAME"; then
        info "Mounted $user_device to /mnt/$BOOTLOADER_NAME"
        SELECTED_MOUNT_POINT="/mnt/$BOOTLOADER_NAME"
        return 0
    else
        error "Failed to mount $user_device"
        return 1
    fi
}

#######################################
# Wait for bootloader and flash
#######################################
flash_firmware() {
    local uf2_file="$1"
    local side="$2"

    if [[ ! -f "$uf2_file" ]]; then
        error "Firmware file not found: $uf2_file"
        return 1
    fi

    echo ""
    info "Ready to flash $side"
    warn "Put keyboard ($side) in bootloader mode (double-tap reset button)"
    echo ""
    echo "Waiting for bootloader to appear..."
    echo "(Looking for drive named: $BOOTLOADER_NAME or similar)"
    echo "(Timeout: ${FLASH_TIMEOUT}s / $(( FLASH_TIMEOUT / 60 )) min)"
    echo ""

    local elapsed=0
    local mount_point=""
    local prompted=false

    while [[ $elapsed -lt $FLASH_TIMEOUT ]]; do
        # Use || true to prevent set -e from exiting on non-zero return
        mount_point=$(find_bootloader) || true
        if [[ -n "$mount_point" ]]; then
            break
        fi

        # After 5 seconds, offer manual device selection
        if [[ $elapsed -ge 5 ]] && [[ "$prompted" == false ]]; then
            prompted=true
            # Call prompt directly - it sets SELECTED_MOUNT_POINT global variable
            if prompt_mount_device; then
                mount_point="$SELECTED_MOUNT_POINT"
                if [[ -n "$mount_point" ]]; then
                    break
                fi
            fi
        fi

        sleep 1
        ((elapsed++))
        # Show progress every 10 seconds
        if ((elapsed % 10 == 0)); then
            echo "  Waiting... ${elapsed}s / ${FLASH_TIMEOUT}s"
        fi
    done

    if [[ -z "$mount_point" ]]; then
        error "Timeout: Bootloader not detected within ${FLASH_TIMEOUT}s"
        echo ""
        echo "Troubleshooting:"
        echo "  1. Double-tap the reset button on the keyboard"
        echo "  2. Check if a USB drive appears (may be named NICENANO, NRF52BOOT, etc.)"
        echo "  3. Run 'lsblk' or check /run/media/$USER/ to see mounted drives"
        return 1
    fi

    info "Bootloader detected at: $mount_point"
    info "Copying firmware to $side..."

    # Copy as CURRENT.UF2 to overwrite existing firmware
    local target_file="$mount_point/CURRENT.UF2"
    local copy_success=false

    # Try normal copy first, fallback to sudo if permission denied
    if cp "$uf2_file" "$target_file" 2>/dev/null; then
        copy_success=true
    elif sudo cp "$uf2_file" "$target_file"; then
        copy_success=true
    fi

    if [[ "$copy_success" == true ]]; then
        info "Successfully copied firmware!"
        # Sync to ensure write completes
        sync
        sleep 1
        # Unmount the device
        info "Unmounting device..."
        if sudo umount "$mount_point" 2>/dev/null; then
            info "Device unmounted. $side will reboot with new firmware."
        else
            warn "Could not unmount $mount_point - device may have auto-ejected"
        fi
        # Clean up mount point directory
        if [[ -d "$mount_point" ]] && ! mountpoint -q "$mount_point" 2>/dev/null; then
            sudo rmdir "$mount_point" 2>/dev/null || true
        fi
        return 0
    else
        error "Failed to copy firmware to $mount_point"
        return 1
    fi
}

#######################################
# Parse command line arguments
#######################################
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -l|--left-only)
                BUILD_LEFT=true
                BUILD_RIGHT=false
                shift
                ;;
            -r|--right-only)
                BUILD_LEFT=false
                BUILD_RIGHT=true
                shift
                ;;
            -f|--flash)
                FLASH_LEFT=true
                FLASH_RIGHT=true
                shift
                ;;
            --flash-left)
                FLASH_LEFT=true
                shift
                ;;
            --flash-right)
                FLASH_RIGHT=true
                shift
                ;;
            --force)
                FORCE_BUILD=true
                shift
                ;;
            -c|--clean)
                CLEAN=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    # If flashing specific side, also build that side
    if [[ "$FLASH_LEFT" == true ]] && [[ "$FLASH_RIGHT" == false ]]; then
        BUILD_LEFT=true
    fi
    if [[ "$FLASH_RIGHT" == true ]] && [[ "$FLASH_LEFT" == false ]]; then
        BUILD_RIGHT=true
    fi
}

#######################################
# Main
#######################################
main() {
    parse_args "$@"

    echo "========================================"
    echo "  ZMK Firmware Builder (Docker)"
    echo "========================================"
    echo ""

    # Pre-flight checks
    check_docker
    check_zmk
    init_zmk_workspace

    # Compute config hash for caching
    local config_hash
    config_hash=$(compute_config_hash)
    info "Config hash: ${config_hash:0:12}..."

    # Check for cached builds
    local cached_dir=""
    local needs_build_left=false
    local needs_build_right=false
    local used_cache=false

    if [[ "$FORCE_BUILD" == true ]]; then
        info "Force build requested, skipping cache check"
        needs_build_left="$BUILD_LEFT"
        needs_build_right="$BUILD_RIGHT"
    else
        # Check cache for each half
        if [[ "$BUILD_LEFT" == true ]]; then
            cached_dir=$(find_cached_build "$config_hash" "$SHIELD_LEFT") || true
            if [[ -n "$cached_dir" ]]; then
                info "Found cached build for $SHIELD_LEFT in $cached_dir"
                used_cache=true
            else
                needs_build_left=true
            fi
        fi

        if [[ "$BUILD_RIGHT" == true ]]; then
            cached_dir=$(find_cached_build "$config_hash" "$SHIELD_RIGHT") || true
            if [[ -n "$cached_dir" ]]; then
                info "Found cached build for $SHIELD_RIGHT in $cached_dir"
                used_cache=true
            else
                needs_build_right=true
            fi
        fi
    fi

    # If using cached build, update OUTPUT_DIR to point to it
    if [[ "$used_cache" == true ]] && [[ "$needs_build_left" == false ]] && [[ "$needs_build_right" == false ]]; then
        OUTPUT_DIR="$cached_dir"
        info "Using cached firmware from: $OUTPUT_DIR"
    else
        # Create output directory for new build
        mkdir -p "$OUTPUT_DIR"
        info "Output directory: $OUTPUT_DIR"
        echo ""

        # Build firmware
        if [[ "$needs_build_left" == true ]]; then
            build_half "$SHIELD_LEFT"
        fi

        if [[ "$needs_build_right" == true ]]; then
            build_half "$SHIELD_RIGHT"
        fi

        # Save config hash for future cache checks
        echo "$config_hash" > "$OUTPUT_DIR/.config_hash"
    fi

    echo ""
    echo "========================================"
    info "Build complete!"
    echo "========================================"
    echo ""
    echo "Firmware files:"
    ls -la "$OUTPUT_DIR"/*.uf2 2>/dev/null || true

    # Flash if requested
    if [[ "$FLASH_LEFT" == true ]] || [[ "$FLASH_RIGHT" == true ]]; then
        echo ""
        echo "========================================"
        echo "  Flashing Firmware"
        echo "========================================"

        if [[ "$FLASH_LEFT" == true ]] && [[ "$BUILD_LEFT" == true ]]; then
            flash_firmware "$OUTPUT_DIR/${SHIELD_LEFT}.uf2" "LEFT" || true
        fi

        if [[ "$FLASH_RIGHT" == true ]] && [[ "$BUILD_RIGHT" == true ]]; then
            flash_firmware "$OUTPUT_DIR/${SHIELD_RIGHT}.uf2" "RIGHT" || true
        fi

        echo ""
        info "Flashing complete!"
    else
        echo ""
        echo "To flash: copy .uf2 file to keyboard in bootloader mode"
        echo "Or run with --flash to auto-detect bootloader"
    fi
}

main "$@"
