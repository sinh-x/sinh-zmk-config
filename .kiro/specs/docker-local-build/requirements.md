# Docker Local Build Requirements

## 1. Introduction

This document specifies the requirements for adding Docker-based local firmware builds as an alternative to the existing Nix build system. The Docker approach uses the official ZMK build container, ensuring compatibility with all ZMK features including OLED display support.

**Architecture Overview**: A shell script wrapping Docker commands to build firmware for both keyboard halves, producing .uf2 files identical to GitHub Actions output.

## 2. User Stories

### Keyboard User
- **As a keyboard user**, I want to build firmware locally with full OLED display support, so that I can iterate quickly without relying on GitHub Actions
- **As a keyboard user**, I want a simple one-command build process, so that I don't need to remember complex Docker commands
- **As a keyboard user**, I want to flash firmware automatically without manual mounting/copying, so that the workflow is streamlined
- **As a keyboard user**, I want builds to be cached when config hasn't changed, so that I don't wait for unnecessary rebuilds

### Developer/Maintainer
- **As a maintainer**, I want builds that match GitHub Actions output, so that local testing accurately reflects production firmware
- **As a maintainer**, I want to keep the Nix build as an option, so that users can choose their preferred build method
- **As a maintainer**, I want to force rebuilds when needed, so that I can verify changes even when cache exists

## 3. Acceptance Criteria

### Functional Requirements
- **WHEN** user runs the build script, **THEN** it **SHALL** produce .uf2 files for both left and right halves
- **WHEN** user runs the build script without ZMK cloned, **THEN** it **SHALL** display instructions to clone ZMK
- **WHEN** build completes successfully, **THEN** the output **SHALL** be placed in `output/<YYYYMMDD-HHMM>/` subdirectory
- **WHEN** OLED display is enabled in config, **THEN** the built firmware **SHALL** include working display support

### Flashing Requirements
- **WHEN** user runs with `--flash` option, **THEN** the script **SHALL** wait for bootloader detection (up to 3 minutes)
- **WHEN** bootloader is detected, **THEN** the script **SHALL** automatically copy firmware to the device
- **WHEN** bootloader is not detected within timeout, **THEN** the script **SHALL** display troubleshooting instructions

### Build Caching Requirements
- **WHEN** config files haven't changed since last build, **THEN** the script **SHALL** reuse cached firmware
- **WHEN** user runs with `--force` option, **THEN** the script **SHALL** rebuild regardless of cache
- **WHEN** build completes, **THEN** the script **SHALL** store config hash in output directory for future cache checks

### Configuration Requirements
- **WHEN** user wants to customize ZMK location, **THEN** they **SHALL** be able to set it via environment variable
- **WHEN** user wants to build only one half, **THEN** they **SHALL** be able to specify left or right

### Error Handling Requirements
- **IF** Docker is not installed, **THEN** the script **SHALL** display an appropriate error message
- **IF** ZMK directory doesn't exist, **THEN** the script **SHALL** display clone instructions
- **IF** build fails, **THEN** the script **SHALL** exit with non-zero status and show error output

## 4. Technical Architecture

### Build Components
- **Docker Image**: `zmkfirmware/zmk-build-arm:stable`
- **Build Tool**: West (Zephyr meta-tool)
- **Output Format**: UF2 bootloader files

### Configuration
- **Board**: nice_nano (uses revision system, defaults to v2.0.0)
- **Shield**: corne_left / corne_right
- **Features**: All features from corne.conf (display, ZMK Studio, pointing device)

### Key Files
- `scripts/build-docker.sh` - Main build script
- `config/corne.keymap` - Keymap definition
- `config/corne.conf` - Feature configuration
- `output/<YYYYMMDD-HHMM>/` - Build output directory (generated per build)
- `output/<YYYYMMDD-HHMM>/.config_hash` - SHA256 hash of config files for caching

## 5. Feature Specifications

### Core Features
1. **One-Command Build**: Single script to build both halves
2. **OLED Support**: Full display functionality in built firmware
3. **Output Organization**: Timestamped subdirectories (e.g., `output/20260115-1430/`) for build history
4. **Build Caching**: SHA256 hash-based caching to skip rebuilds when config unchanged
5. **Auto-Flash**: Automatic bootloader detection and firmware copying

### Advanced Features
1. **Selective Build**: Option to build only left or right half (`--left-only`, `--right-only`)
2. **Custom ZMK Path**: Environment variable to specify ZMK location (`ZMK_DIR`)
3. **Clean Build**: Option to remove previous build artifacts (`--clean`)
4. **Force Rebuild**: Option to bypass cache and rebuild (`--force`)
5. **Selective Flash**: Options to flash specific halves (`--flash-left`, `--flash-right`)

## 6. Success Criteria

### User Experience
- **WHEN** user runs `./scripts/build-docker.sh`, **THEN** they **SHALL** have working firmware within 5 minutes (first build) or instantly (cached)
- **WHEN** firmware is flashed, **THEN** OLED display **SHALL** show status information
- **WHEN** user runs with `--flash`, **THEN** flashing **SHALL** complete without manual file copying

### Build/Firmware
- **WHEN** firmware is built, **THEN** it **SHALL** compile without errors
- **WHEN** firmware is flashed, **THEN** the keyboard **SHALL** function identically to GitHub Actions builds
- **WHEN** firmware is flashed, **THEN** OLED **SHALL** display layer, battery, and connection status

### Caching
- **WHEN** config files are unchanged, **THEN** cached build **SHALL** be used (no Docker execution)
- **WHEN** `--force` is used, **THEN** fresh build **SHALL** occur regardless of cache

## 7. Assumptions and Dependencies

### Technical Assumptions
- Docker is installed and running on user's system
- User has internet access to pull Docker image (first run)
- User can clone ZMK repository

### External Dependencies
- ZMK repository: https://github.com/zmkfirmware/zmk.git
- Docker image: zmkfirmware/zmk-build-arm:stable
- West build system within Docker container

## 8. Constraints and Limitations

### System Requirements
- Docker Desktop (macOS/Windows) or Docker Engine (Linux)
- ~2GB disk space for Docker image
- ~500MB disk space for ZMK repository

### Platform Constraints
- Script designed for Unix-like systems (Linux, macOS)
- Windows users need WSL2 or Git Bash

---

**Document Status**: Implemented

**Last Updated**: 2026-01-15

**Version**: 2.0

**Changelog**:
- v2.0: Added build caching, auto-flash, and --force options
- v1.0: Initial requirements for Docker-based builds
