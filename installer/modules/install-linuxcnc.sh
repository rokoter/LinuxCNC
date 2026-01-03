#!/bin/bash
################################################################################
# Module: install-linuxcnc.sh
# Description: Install or verify LinuxCNC installation
################################################################################

log "Checking LinuxCNC installation..."

# Check if LinuxCNC is already installed
if command -v linuxcnc &> /dev/null; then
    INSTALLED_VERSION=$(linuxcnc -v 2>&1 | head -n1 || echo "unknown")
    log "LinuxCNC is already installed: $INSTALLED_VERSION"
    
    read -p "Reinstall/update LinuxCNC? [y/N]: " REINSTALL
    if [[ ! "$REINSTALL" =~ ^[Yy]$ ]]; then
        log "Keeping existing LinuxCNC installation"
        return 0
    fi
fi

# Update package lists
log "Updating package lists..."
apt-get update

# Install LinuxCNC
log "Installing LinuxCNC..."

# Try to install from repositories
if apt-cache show linuxcnc-uspace &> /dev/null; then
    log "Installing LinuxCNC from repositories..."
    apt-get install -y linuxcnc-uspace linuxcnc-uspace-dev || {
        error "Failed to install LinuxCNC from repositories"
        return 1
    }
else
    warn "LinuxCNC not available in repositories"
    warn "Please ensure you have added the LinuxCNC repository:"
    warn "  echo 'deb https://www.linuxcnc.org bookworm base' | sudo tee /etc/apt/sources.list.d/linuxcnc.list"
    warn "  wget -O - https://www.linuxcnc.org/dists/bookworm/Release.key | sudo apt-key add -"
    return 1
fi

# Install additional useful packages
log "Installing additional tools..."
apt-get install -y \
    linuxcnc-doc-en \
    mesaflash \
    hostmot2-firmware-all \
    axis \
    python3-pyqt5 || warn "Some optional packages failed to install"

# Verify installation
if command -v linuxcnc &> /dev/null; then
    log "LinuxCNC installed successfully"
    linuxcnc -v
else
    error "LinuxCNC installation verification failed"
    return 1
fi

log "LinuxCNC installation complete"
