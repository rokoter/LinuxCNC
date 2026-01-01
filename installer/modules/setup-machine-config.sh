#!/bin/bash
################################################################################
# Module: setup-machine-config.sh
# Description: Link machine-specific LinuxCNC configuration
################################################################################

log "Setting up machine configuration..."

# Determine actual user's home directory
if [ -n "$ACTUAL_HOME" ]; then
    USER_HOME="$ACTUAL_HOME"
else
    USER_HOME="/home/$DEFAULT_USERNAME"
fi

# Repository location
REPO_DIR="$USER_HOME/LinuxCNC"
LINUXCNC_CONFIG_DIR="$USER_HOME/linuxcnc/configs"

# Create LinuxCNC config directory if it doesn't exist
mkdir -p "$LINUXCNC_CONFIG_DIR"

# Full path to machine config
MACHINE_CONFIG_SOURCE="$REPO_DIR/$CONFIG_PATH"

if [ ! -d "$MACHINE_CONFIG_SOURCE" ]; then
    error "Machine configuration not found: $MACHINE_CONFIG_SOURCE"
    warn "Available configurations:"
    find "$REPO_DIR/ethercat" -type d -maxdepth 1 2>/dev/null || echo "Repository not found"
    return 1
fi

log "Machine config source: $MACHINE_CONFIG_SOURCE"

# Create symbolic link to active configuration
ACTIVE_CONFIG_LINK="$LINUXCNC_CONFIG_DIR/active-machine"

if [ -L "$ACTIVE_CONFIG_LINK" ] || [ -e "$ACTIVE_CONFIG_LINK" ]; then
    warn "Active machine config already exists"
    ls -la "$ACTIVE_CONFIG_LINK"
    read -p "Replace with new configuration? [y/N]: " REPLACE
    if [[ "$REPLACE" =~ ^[Yy]$ ]]; then
        rm -f "$ACTIVE_CONFIG_LINK"
    else
        log "Keeping existing configuration"
        return 0
    fi
fi

log "Creating symbolic link to machine configuration..."
ln -s "$MACHINE_CONFIG_SOURCE" "$ACTIVE_CONFIG_LINK"
chown -h "$DEFAULT_USERNAME:$DEFAULT_USERNAME" "$ACTIVE_CONFIG_LINK"

log "Active machine config: $ACTIVE_CONFIG_LINK -> $MACHINE_CONFIG_SOURCE"

# Compile HAL components if cia402.comp exists
CIA402_COMP="$MACHINE_CONFIG_SOURCE/cia402.comp"
if [ -f "$CIA402_COMP" ]; then
    log "Found cia402.comp, compiling HAL component..."
    halcompile --install "$CIA402_COMP" || warn "Failed to compile cia402.comp"
else
    # Check in common location
    CIA402_COMP="$REPO_DIR/ethercat/components/cia402.comp"
    if [ -f "$CIA402_COMP" ]; then
        log "Compiling cia402.comp from common components..."
        halcompile --install "$CIA402_COMP" || warn "Failed to compile cia402.comp"
    else
        warn "cia402.comp not found, skipping compilation"
    fi
fi

# Set permissions
chown -R "$DEFAULT_USERNAME:$DEFAULT_USERNAME" "$LINUXCNC_CONFIG_DIR"

log "Machine configuration setup complete"

# Display config info
echo ""
echo "==================================================================="
echo "Machine Configuration Summary"
echo "==================================================================="
echo "Type:        $MACHINE_NAME"
echo "Source:      $MACHINE_CONFIG_SOURCE"
echo "Link:        $ACTIVE_CONFIG_LINK"
echo ""
echo "To start LinuxCNC with this configuration:"
echo "  linuxcnc ~/linuxcnc/configs/active-machine/<config-file>.ini"
echo "==================================================================="
echo ""
