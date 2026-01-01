# LinuxCNC Machine Auto-Installer

Automated installation and configuration system for LinuxCNC EtherCAT machines.

## Features

- ✅ Interactive menu-driven installation
- ✅ Command-line automation support
- ✅ Git branch selection (main, develop, custom)
- ✅ Multiple machine type support
- ✅ **Pre-flight system validation** (NEW in v1.0.1)
- ✅ Realtime optimization (CPU isolation, GRUB config)
- ✅ EtherCAT master installation
- ✅ Modular design (easy to extend)
- ✅ Ansible-ready structure (for future migration)
- ✅ **Proper sudo/root handling** (FIXED in v1.0.1)

## Quick Start

### Interactive Installation

```bash
# Download installer
cd ~
git clone https://github.com/rokoter/LinuxCNC.git
cd LinuxCNC/installer

# Run installer (interactive mode)
sudo ./install.sh
```

### Automated Installation

```bash
# Install specific machine type
sudo ./install.sh --machine xyz-gantry --branch main --hostname mill-01

# Use local files (no git pull)
sudo ./install.sh --machine ihsv-single --local
```

## Supported Machine Types

1. **ihsv-single** - IHSV-57 Single Axis Test Setup
2. **xyz-gantry** - 3-axis XYZ Gantry
3. **xyyz-gantry** - 4-axis Gantry with Dual Y
4. **custom** - Custom configuration

## Git Branch Options

- `main` - Stable, production-ready configurations
- `develop` - Testing/development branch
- Custom branch - Specify any branch name
- Local - Use existing local files without git pull

## Directory Structure

```
installer/
├── install.sh              # Main installer script
├── modules/                # Installation modules
│   ├── install-ethercat.sh       # EtherCAT master installation
│   ├── install-linuxcnc.sh       # LinuxCNC installation
│   ├── optimize-realtime.sh      # Realtime optimization
│   └── setup-machine-config.sh   # Machine config setup
├── configs/                # Machine configuration templates
│   ├── ihsv-single.conf
│   ├── xyz-gantry.conf
│   └── xyyz-gantry.conf
└── README.md               # This file
```

## What the Installer Does

### 0. Pre-flight Checks (NEW)
- Validates system requirements
- Checks disk space (minimum 5GB)
- Verifies internet connectivity
- Detects RT kernel
- Warns about virtualization
- Checks for conflicting packages

### 1. System Setup
- Sets hostname
- Updates package lists
- Installs essential packages (git, vim, htop, build-essential)

### 2. EtherCAT Installation
- Clones and builds EtherCAT master
- Configures EtherCAT network interface
- Sets up systemd service

### 3. LinuxCNC Installation
- Verifies or installs LinuxCNC packages
- Installs optional tools (mesaflash, docs)

### 4. Realtime Optimization
- Configures CPU isolation (isolcpus)
- Updates GRUB with realtime parameters
- Disables unnecessary services
- Configures network interface for low latency

### 5. Machine Configuration
- Clones/updates your LinuxCNC configuration repository
- Creates symbolic links to active machine config
- Compiles HAL components (cia402.comp)

## BIOS Configuration

After installation, configure your BIOS for optimal realtime performance:

### Disable:
- Intel SpeedStep / EIST
- Turbo Boost / Turbo Mode
- C-States (C3, C6, C7, etc.)
- Package C-State
- Enhanced Halt State (C1E)
- Hyper-Threading (test both on/off)

### Enable:
- Performance Mode

## Post-Installation

### 1. Reboot
```bash
sudo reboot
```

### 2. Run Latency Test
```bash
latency-histogram
```

**Target:** Servo thread max < 50µs

### 3. Start LinuxCNC
```bash
linuxcnc ~/linuxcnc/configs/active-machine/<config-file>.ini
```

## Command Line Options

```
Usage: ./install.sh [OPTIONS]

OPTIONS:
    --machine TYPE      Machine type (ihsv-single, xyz-gantry, xyyz-gantry)
    --branch BRANCH     Git branch to use (main, develop, custom)
    --hostname NAME     Set hostname
    --local             Use local files, skip git pull
    --help              Show help message

EXAMPLES:
    # Interactive mode
    sudo ./install.sh

    # Automated with specific machine
    sudo ./install.sh --machine xyz-gantry --branch main --hostname mill-01

    # Use local files
    sudo ./install.sh --machine ihsv-single --local
```

## Customization

### Adding a New Machine Type

1. Create configuration in your repo: `ethercat/my-machine/`
2. Run installer and select "Custom Configuration"
3. Or modify `install.sh` to add new machine type to menu

### Adding Custom Modules

Create new module in `modules/` directory:

```bash
# modules/my-custom-module.sh
#!/bin/bash
log "Running my custom module..."
# Your code here
```

Add to `install.sh`:
```bash
run_module "my-custom-module"
```

## TODO / Future Enhancements

- [ ] Add your specific EtherCAT installation commands
- [ ] Create machine-specific configuration files
- [ ] Add network interface auto-detection
- [ ] Add backup/restore functionality
- [ ] Migration to Ansible (when managing multiple machines)
- [ ] Add diagnostics/troubleshooting module
- [ ] Add update script (for existing installations)

## Troubleshooting

### Latency Issues
- Check BIOS settings (see above)
- Run `latency-histogram` with stress test
- Check if CPU isolation is active: `cat /proc/cmdline | grep isolcpus`

### EtherCAT Not Working
- Check interface: `ethercat slaves`
- Verify network interface name in `/etc/sysconfig/ethercat`
- Check dmesg: `dmesg | grep -i ethercat`

### Configuration Not Found
- Verify git clone was successful: `ls -la ~/LinuxCNC`
- Check branch: `cd ~/LinuxCNC && git branch`
- Verify config path matches repository structure

## Support

For issues or questions:
- GitHub Issues: https://github.com/rokoter/LinuxCNC/issues
- LinuxCNC Forum: https://forum.linuxcnc.org/

## License

[Your License Here]

## Version History

- 1.0.0 (2025-01-01) - Initial release
  - Interactive installation
  - Multi-machine support
  - Git branch selection
  - Realtime optimization
  - Modular design

## Migration to Ansible

This installer is designed to be easily migrated to Ansible when needed.
Each module corresponds to future Ansible roles. See `ANSIBLE_MIGRATION.md`
for conversion guide.
