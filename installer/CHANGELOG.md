# Changelog

All notable changes to the LinuxCNC Auto-Installer project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.8] - 2025-01-03

### Fixed
- **Prevent apt upgrade errors from raspi-firmware on x86 systems**
  - Debian LinuxCNC ISO sometimes includes raspi-firmware on x86 systems
  - Causes `initramfs-tools` configuration errors during upgrade
  - Now safely removes raspi-firmware ONLY on x86/x86_64 systems
  - Preserves raspi-firmware on ARM systems (Raspberry Pi)

### Added
- Architecture detection before package cleanup
- Safe removal of incompatible ARM packages on x86
- Logging of detected architecture type

### Technical Details
- Uses `uname -m` to detect architecture (x86_64, i686, armv7l, aarch64)
- Only removes raspi-firmware if: (1) x86 architecture AND (2) package installed
- Prevents dpkg errors: "raspi-firmware: missing /boot/firmware"
- Ensures clean apt upgrade on mixed-architecture ISO images

---

## [1.0.7] - 2025-01-03

### Improved
- **EtherCAT permissions now verified automatically**
  - Removed manual "Fix EtherCAT permissions" from Next Steps
  - Added automatic verification at end of installation
  - Shows ✓ if permissions are correct (666 or 777)
  - Shows ⚠ warning only if permissions actually need fixing
  - Better user experience - no unnecessary manual steps

### Fixed
- Next Steps list reduced from 5 to 4 items
- Only shows EtherCAT permission warning if actually needed
- Clearer messaging about when reboot will fix permissions

### Technical Details
- Added `stat -c "%a"` check for /dev/EtherCAT0 permissions
- Verifies permissions are 666 or 777
- Warns user only if permissions are incorrect after installation
- Handles case where /dev/EtherCAT0 doesn't exist yet

---

## [1.0.6] - 2025-01-03

### Added
- **System package upgrade now included** (as recommended in forum guide)
  - Interactive prompt asks user if they want to upgrade (~500MB download)
  - Non-interactive mode upgrades by default
  - New flags: `--upgrade` (force) and `--no-upgrade` (skip)
  - Follows forum best practice: "apt update" then install

### Improved
- Better handling of package upgrades in different modes
- Clear warning if user skips upgrade
- Help text updated with upgrade options

### Technical Details
- Added `SKIP_UPGRADE` variable (default: false)
- Interactive mode prompts user (default: Yes)
- Non-interactive mode upgrades automatically
- `--no-upgrade` flag for fast testing/development

---

## [1.0.5] - 2025-01-03

### Improved
- **BIOS recommendations now prominently displayed at end of installation**
  - No longer scrolls off screen during installation
  - Shown in final summary after all modules complete
  - Also saved to `~/BIOS_RECOMMENDATIONS.txt` for reference
  - Includes all critical settings needed for realtime performance

### Added
- EtherCAT permissions fix reminder in final summary
- Target latency values in next steps (< 50µs)
- Numbered checklist for post-installation steps
- Better visual formatting with emojis for important sections

### Technical Details
- `optimize-realtime.sh` saves BIOS recommendations to file
- Both interactive and non-interactive flows show BIOS settings
- Final summary now includes 5-step checklist
- File saved with proper ownership for user access

---

## [1.0.4] - 2025-01-03

### Fixed
- **CRITICAL**: Fixed EtherCAT device permissions being overwritten
  - `optimize-realtime.sh` was overwriting udev rules created by `install-ethercat.sh`
  - EtherCAT device permissions (`KERNEL=="EtherCAT[0-9]*"`) were lost
  - Caused "Permission denied" on `/dev/EtherCAT0`

### Improved
- `optimize-realtime.sh` now checks for existing udev rules instead of overwriting
- Added `udevadm trigger` to apply rules immediately
- Better comments explaining MODE="0666" vs "0777" (0666 is safer)
- Wildcard pattern `EtherCAT[0-9]*` instead of `EtherCAT[0-9]` for better matching

### Technical Details
- Module execution order issue resolved:
  1. `install-ethercat.sh` creates complete udev rules
  2. `optimize-realtime.sh` now verifies instead of overwriting
- MODE="0666" (rw-rw-rw-) is sufficient and safer than MODE="0777"
- Added `udevadm trigger` for immediate rule application

---

## [1.0.3] - 2025-01-03

### Fixed
- **CRITICAL**: Fixed "MACHINE_NAME: unbound variable" error in non-interactive mode
  - Added default values for all required variables
  - Enhanced parse_args() to set MACHINE_NAME and CONFIG_PATH
  - Fixed non-interactive flow to work with --local flag

### Improved
- Non-interactive mode now works correctly when called via bootstrap
- Better default handling for command-line arguments
- Cleaner separation between interactive and non-interactive flows

### Technical Details
- Set default values at script start: MACHINE_TYPE, MACHINE_NAME, CONFIG_PATH, etc.
- parse_args() now sets MACHINE_NAME based on MACHINE_TYPE
- Non-interactive path no longer calls main(), executes steps directly
- All variables initialized before use (fixes "unbound variable" errors)

---

## [1.0.2] - 2025-01-01

### Fixed
- **CRITICAL**: Fixed git conflict error when running bootstrap script on fresh install
  - Bootstrap script now passes `--local` flag to installer
  - Prevents "local changes would be overwritten" error
  - Installer no longer tries to update repository that bootstrap already updated

### Improved
- Enhanced `clone_or_update_repo()` function with interactive git conflict resolution
  - Detects local changes before attempting checkout
  - Offers 4 options: stash, commit, discard, or skip
  - Better error messages with clear guidance
  - Prevents git operation failures

### Technical Details
- Bootstrap scripts now pass `--local` to prevent duplicate git operations
- Added `git diff-index` check before attempting repository updates
- Interactive prompts for resolving git conflicts
- Auto-stash/commit functionality with timestamps

---

## [1.0.1] - 2025-01-01

### Fixed
- **CRITICAL**: Fixed `/home/root` directory issue when running installer with sudo
  - Installer now correctly detects actual user via `$SUDO_USER` environment variable
  - All paths now use `$ACTUAL_HOME` instead of hardcoded `/home/$USER`
  - Fixed repository clone failures that occurred when script was run as root
  - Added proper error handling in `clone_or_update_repo()` function
  
### Added
- **Pre-flight checks module** (`preflight-checks.sh`)
  - Validates system requirements before installation starts
  - Checks available disk space (requires minimum 5GB free)
  - Verifies internet connectivity to GitHub and package repositories
  - Detects if running on RT (real-time) kernel vs standard kernel
  - Warns when running in virtualization environments (VirtualBox, KVM, etc.)
  - Identifies potentially conflicting packages (e.g., network-manager)
  - Validates CPU core count for realtime performance
  - Provides summary with pass/fail status for critical checks

### Improved
- Enhanced `install-linuxcnc.sh` module
  - Added actual package installation logic
  - Proper repository detection and error messages
  - Installation of optional but useful packages (mesaflash, docs, etc.)
  - Better version detection
  
- Better error handling throughout
  - All `cd` commands now check for success before proceeding
  - Error messages include actionable suggestions
  - Graceful fallbacks when modules fail

- All modules updated to use `$ACTUAL_HOME`
  - `install-ethercat.sh` - cia402 installation path
  - `setup-machine-config.sh` - configuration paths
  - `install.sh` - repository and final summary

### Technical Details
- New global variables:
  - `ACTUAL_USER`: Real user (from `$SUDO_USER` or `$USER`)
  - `ACTUAL_HOME`: Real user's home directory (using `getent passwd`)
- All hardcoded `/home/$USER` paths replaced with `$ACTUAL_HOME`
- Permission management improved (proper chown for all created directories)
- Git operations now preserve user ownership

### Testing
- Tested with bootstrap script: `curl -sSL ... | sudo bash`
- Verified on Debian 12 with LinuxCNC ISO
- Confirmed fix for root user issue

---

## [1.0.0] - 2025-01-01

### Initial Release

#### Features
- Interactive menu-driven installation wizard
- Command-line automation support for unattended installs
- Git branch selection (main, develop, custom, or local files)
- Multiple machine type support:
  - IHSV-57 Single Axis (Test Setup)
  - XYZ Gantry (3-axis)
  - XYYZ Gantry (4-axis with dual Y)
  - Custom Configuration
- One-command installation via bootstrap script
- Modular architecture for easy extension

#### Modules Included
1. **install-ethercat.sh**
   - Installs EtherCAT master from repositories
   - Automatic network interface detection
   - Intel NIC detection and recommendation
   - Realtek driver warnings
   - Configures `/etc/ethercat.conf`
   - Creates udev rules for permissions
   - Disables network offloading
   - Installs and compiles cia402 HAL component

2. **install-linuxcnc.sh**
   - Verifies LinuxCNC installation
   - Checks version information
   - Placeholder for source builds (if needed)

3. **optimize-realtime.sh**
   - CPU core isolation (isolcpus)
   - GRUB configuration for realtime parameters
   - Network interface optimization
   - Disables unnecessary services (bluetooth, cups, avahi)
   - Provides BIOS configuration recommendations

4. **setup-machine-config.sh**
   - Links machine-specific configurations
   - Creates symbolic link to active machine
   - Compiles HAL components
   - Sets proper file permissions

#### System Features
- Hostname configuration
- Essential package installation
- Repository clone/update functionality
- Interactive confirmation prompts
- Colored console output
- Comprehensive error handling
- Help system with examples

#### Bootstrap Script
- One-command curl installation
- Automatic branch detection
- Support for feature-installer and main branches
- Git repository management
- Interactive prompts work even when piped from curl

### Known Limitations
- BIOS settings must be configured manually
- Requires LinuxCNC repositories to be pre-configured
- EtherCAT requires reboot for full functionality
- Network Manager may conflict (manual disable needed)

---

## Upgrade Instructions

### From 1.0.0 to 1.0.1

No breaking changes. To upgrade an existing installation:

```bash
cd ~/LinuxCNC
git pull origin feature-installer
```

To re-run the installer with fixes:

```bash
sudo ~/LinuxCNC/installer/install.sh
```

The installer will detect existing installations and prompt for updates.

---

## Future Plans

### v1.1.0 (Planned)
- Automatic LinuxCNC repository configuration
- Network Manager auto-detection and disable
- Integrated latency testing
- Configuration backup and restore
- Update script for existing installations

### v1.2.0 (Future)
- Machine type auto-detection from EtherCAT slaves
- Web-based configuration interface
- Ansible playbook generation
- Multi-machine deployment support

### v2.0.0 (Long-term Vision)
- Full migration to Ansible
- Remote management capabilities
- Centralized configuration management
- Fleet deployment for multiple machines

---

## Contributors

- RoKoTer - Initial development and implementation
- LinuxCNC Community - EtherCAT guides and best practices
- AI Assistant - Code review and optimization suggestions

---

## License

[To be determined]

---

## Support & Resources

- **GitHub Issues**: https://github.com/rokoter/LinuxCNC/issues
- **LinuxCNC Forum**: https://forum.linuxcnc.org/
- **Documentation**: See installer/README.md
- **Bootstrap Guide**: See installer/BOOTSTRAP.md
