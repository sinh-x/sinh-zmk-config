# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a ZMK (Zephyr Mechanical Keyboard) firmware configuration repository for a Corne split keyboard with nice_nano_v2 controllers. The keyboard uses the Colemak-DH layout with homerow mods.

## Build Commands

### Using Docker (Recommended for local builds)
Docker builds use the official ZMK toolchain, ensuring full feature support including OLED display.

```bash
./scripts/build-docker.sh              # Build both halves
./scripts/build-docker.sh --left-only  # Build only left half
./scripts/build-docker.sh --right-only # Build only right half
./scripts/build-docker.sh --flash      # Build and flash both halves
./scripts/build-docker.sh -l -f        # Build and flash left half only
./scripts/build-docker.sh --force      # Force rebuild (skip cache)
./scripts/build-docker.sh --help       # Show all options
```

**Build Caching:** The script caches builds based on config file hash. If your config files haven't changed since the last build, it will reuse existing firmware. Use `--force` to rebuild anyway.

**Flashing:** The `--flash` option auto-detects when the keyboard enters bootloader mode (double-tap reset) and copies the firmware automatically. No manual mounting/copying required (3-minute timeout).

**Prerequisites:**
- Docker installed and running
- ZMK repository cloned at `~/git-repos/others/zmk` (or set `ZMK_DIR` env var)

**First run:** The script automatically initializes the ZMK workspace (`west init` + `west update`).

**Output:** Firmware files are placed in `output/YYYYMMDD-HHMM/` with timestamps for build history.

### Using Nix
Note: Nix builds via `zmk-nix` may have issues with OLED display support. Use Docker for full feature parity.

```bash
nix build              # Build firmware for both halves
nix flake check        # Validate flake configuration
nix run .#flash        # Flash firmware to keyboard
nix run .#update       # Update ZMK dependencies (updates zephyrDepsHash in flake.nix)
```

### Using GitHub Actions
Push to any branch or create a PR to trigger the build workflow. Firmware artifacts are uploaded automatically.

## Architecture

### Key Files
- `config/corne.keymap` - Main keymap definition with 5 layers (default, lower, raise, function, media)
- `config/corne.conf` - Keyboard configuration (display, ZMK Studio, pointing device enabled)
- `build.yaml` - GitHub Actions build matrix (nice_nano_v2 + corne_left/corne_right)
- `flake.nix` - Nix build configuration using zmk-nix
- `scripts/build-docker.sh` - Docker-based local build script

### Keymap Structure
The keymap uses ZMK devicetree syntax. Each layer is defined in `config/corne.keymap`:
- **Layer 0 (default)**: Colemak-DH with homerow mods (GACS on home row)
- **Layer 1 (lower)**: Numbers, symbols, brackets
- **Layer 2 (raise)**: Function keys, navigation
- **Layer 3 (function)**: Arrow keys, page up/down, Bluetooth controls
- **Layer 4 (media)**: Mouse emulation, volume, brightness, media controls

### Custom Macros
Macros are defined in the `macros` section of `corne.keymap`:
- `www`, `app_launch`, `app_launch_cmd` - Application launchers
- `prev_word`, `next_word` - Word navigation (Ctrl+Arrow)
- `line_start`, `line_end` - Home/End
- `browser_back`, `browser_forward` - Alt+Arrow for browser navigation

### Homerow Mods
Uses `hm` behavior (hold-tap) with 200ms tapping-term for GACS modifiers on both home rows.

## Updating Dependencies

When ZMK updates, run `nix run .#update` which updates the `zephyrDepsHash` in `flake.nix`. The weekly GitHub Action (`flake.yml`) also creates PRs for flake input updates.

## Development Workflow (Kiro)

This repository uses the Kiro spec-driven development workflow for complex features. See `.kiro/kiro-system-templates/how_kiro_works.md` for details.

### When to Use Full Specs
- Adding new layers or significantly modifying existing ones
- Creating new behaviors or complex macros
- Changes affecting multiple files

### When to Skip Specs
- Simple key remapping
- Config tweaks in `.conf`
- Typo fixes

### Workflow Structure
```
.kiro/
├── bugs/           # Bug reports (Report → Analyze → Fix → Verify)
├── specs/          # Feature specs (Requirements → Design → Tasks)
└── kiro-system-templates/  # Templates adapted for ZMK development
```
