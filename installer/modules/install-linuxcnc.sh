#!/bin/bash
################################################################################
# Module: install-linuxcnc.sh
# Description: Install LinuxCNC (if needed)
################################################################################

log "Checking LinuxCNC installation..."

# Check if LinuxCNC is already installed
if command -v linuxcnc &> /dev/null; then
    LINUXCNC_VERSION=$(linuxcnc -version 2>&1 | head -n1 || echo "unknown")
    log "LinuxCNC already installed: $LINUXCNC_VERSION"
    
    read -p "Reinstall/update LinuxCNC? [y/N]: " REINSTALL
    if [[ ! "$REINSTALL" =~ ^[Yy]$ ]]; then
        log "Skipping LinuxCNC installation"
        return 0
    fi
fi

# If LinuxCNC is not installed, user probably booted from LinuxCNC ISO
# In that case, this module doesn't need to do anything

log "LinuxCNC installation check complete"

# Note: If you need to build LinuxCNC from source, add those steps here
# For now, we assume LinuxCNC is already installed from ISO
