#!/bin/bash
################################################################################
# Module: install-ethercat.sh
# Description: Install and configure EtherCAT master from repositories
# Based on: https://forum.linuxcnc.org/ethercat/45336
################################################################################

log "Installing EtherCAT master from repositories..."

# Check if already installed
if command -v ethercat &> /dev/null; then
    INSTALLED_VERSION=$(ethercat version 2>&1 | head -n1 || echo "unknown")
    warn "EtherCAT master already installed: $INSTALLED_VERSION"
    read -p "Reinstall/reconfigure? [y/N]: " REINSTALL
    if [[ ! "$REINSTALL" =~ ^[Yy]$ ]]; then
        log "Skipping EtherCAT installation"
        return 0
    fi
fi

# Update package lists
log "Updating package lists..."
apt-get update

# Install EtherCAT packages from repositories
log "Installing EtherCAT packages..."
apt-get install -y linuxcnc-ethercat || {
    warn "Trying alternative installation method..."
    apt-get install -y ethercat-master libethercat-dev linuxcnc-ethercat
}

# Verify installation
if ! command -v ethercat &> /dev/null; then
    error "EtherCAT installation failed!"
    return 1
fi

log "EtherCAT master installed successfully"
ethercat version

# Network interface selection
log "Detecting network interfaces..."

# Get all non-loopback interfaces
mapfile -t INTERFACES < <(ip -o link show | awk -F': ' '{print $2}' | grep -v '^lo$')

if [ ${#INTERFACES[@]} -eq 0 ]; then
    error "No network interfaces found!"
    return 1
fi

echo ""
echo "=== Available Network Interfaces ==="
for i in "${!INTERFACES[@]}"; do
    IFACE="${INTERFACES[$i]}"
    MAC=$(ip link show "$IFACE" | awk '/link\/ether/ {print $2}')
    STATE=$(ip link show "$IFACE" | grep -o 'state [A-Z]*' | awk '{print $2}')
    DRIVER=$(ethtool -i "$IFACE" 2>/dev/null | grep driver | awk '{print $2}' || echo "unknown")
    
    echo "$((i+1))) $IFACE"
    echo "   MAC:    $MAC"
    echo "   State:  $STATE"
    echo "   Driver: $DRIVER"
    
    # Warn about Realtek
    if [[ "$DRIVER" == *"r8169"* ]] || [[ "$DRIVER" == *"r8168"* ]]; then
        echo "   ⚠️  WARNING: Realtek driver - not recommended for EtherCAT!"
    fi
    
    # Recommend Intel
    if [[ "$DRIVER" == *"e1000"* ]] || [[ "$DRIVER" == *"igb"* ]] || [[ "$DRIVER" == *"igc"* ]]; then
        echo "   ✅  RECOMMENDED: Intel driver - good for EtherCAT"
    fi
    echo ""
done

# Default to first interface
DEFAULT_CHOICE=1

# Try to be smart - prefer Intel interfaces
for i in "${!INTERFACES[@]}"; do
    DRIVER=$(ethtool -i "${INTERFACES[$i]}" 2>/dev/null | grep driver | awk '{print $2}' || echo "unknown")
    if [[ "$DRIVER" == *"e1000"* ]] || [[ "$DRIVER" == *"igb"* ]] || [[ "$DRIVER" == *"igc"* ]]; then
        DEFAULT_CHOICE=$((i+1))
        break
    fi
done

read -p "Select interface for EtherCAT [$DEFAULT_CHOICE]: " IFACE_CHOICE
IFACE_CHOICE=${IFACE_CHOICE:-$DEFAULT_CHOICE}

ETHERCAT_INTERFACE="${INTERFACES[$((IFACE_CHOICE-1))]}"
ETHERCAT_MAC=$(ip link show "$ETHERCAT_INTERFACE" | awk '/link\/ether/ {print $2}')

log "Selected interface: $ETHERCAT_INTERFACE (MAC: $ETHERCAT_MAC)"

# Configure /etc/ethercat.conf
log "Configuring /etc/ethercat.conf..."

# Backup existing config
if [ -f /etc/ethercat.conf ]; then
    cp /etc/ethercat.conf /etc/ethercat.conf.backup.$(date +%Y%m%d-%H%M%S)
fi

# Update MAC address and driver
sed -i "s/^MASTER0_DEVICE=.*/MASTER0_DEVICE=\"$ETHERCAT_MAC\"/" /etc/ethercat.conf
sed -i "s/^DEVICE_MODULES=.*/DEVICE_MODULES=\"generic\"/" /etc/ethercat.conf

log "EtherCAT configuration updated:"
grep -E "^MASTER0_DEVICE=|^DEVICE_MODULES=" /etc/ethercat.conf

# Enable and start service
log "Enabling EtherCAT service..."
systemctl enable ethercat.service
systemctl start ethercat.service

# Check status
sleep 2
if systemctl is-active --quiet ethercat.service; then
    log "EtherCAT service started successfully"
else
    warn "EtherCAT service failed to start"
    systemctl status ethercat.service
    return 1
fi

# Set permissions on /dev/EtherCAT0
log "Setting permissions on /dev/EtherCAT0..."
chmod 666 /dev/EtherCAT0 2>/dev/null || warn "Could not set permissions (device may not exist yet)"

# Create udev rule for persistent permissions
log "Creating udev rule for EtherCAT device permissions..."
cat > /etc/udev/rules.d/99-ethercat.rules << 'EOF'
# EtherCAT device permissions
KERNEL=="EtherCAT[0-9]", MODE="0666"

# Disable power management and offloading for EtherCAT interface
# Note: Replace eth0 with your actual interface if different
SUBSYSTEM=="net", ACTION=="add", KERNEL=="eth0", RUN+="/usr/sbin/ethtool -s %k wol d"
SUBSYSTEM=="net", ACTION=="add", KERNEL=="eth0", RUN+="/usr/sbin/ethtool -K %k gro off"
SUBSYSTEM=="net", ACTION=="add", KERNEL=="eth0", RUN+="/usr/sbin/ethtool -K %k lro off"
SUBSYSTEM=="net", ACTION=="add", KERNEL=="eth0", RUN+="/usr/sbin/ethtool -K %k tso off"
SUBSYSTEM=="net", ACTION=="add", KERNEL=="eth0", RUN+="/usr/sbin/ethtool -K %k gso off"
EOF

# Update udev rules file with actual interface name
sed -i "s/eth0/$ETHERCAT_INTERFACE/g" /etc/udev/rules.d/99-ethercat.rules

# Reload udev rules
udevadm control --reload-rules

log "Udev rules created and reloaded"

# Test EtherCAT
log "Testing EtherCAT master..."
ethercat slaves || warn "No EtherCAT slaves detected (this is normal if nothing is connected)"

# Install cia402 HAL component
log "Installing cia402 HAL component..."

CIA402_DIR="/home/$DEFAULT_USERNAME/dev/hal-cia402"
mkdir -p "/home/$DEFAULT_USERNAME/dev"

if [ ! -d "$CIA402_DIR" ]; then
    log "Cloning cia402 repository..."
    cd "/home/$DEFAULT_USERNAME/dev"
    git clone https://github.com/dbraun1981/hal-cia402
    chown -R "$DEFAULT_USERNAME:$DEFAULT_USERNAME" "$CIA402_DIR"
else
    log "cia402 repository already exists"
fi

# Compile cia402.comp
if [ -f "$CIA402_DIR/cia402.comp" ]; then
    log "Compiling cia402.comp..."
    halcompile --install "$CIA402_DIR/cia402.comp" || warn "Failed to compile cia402.comp"
else
    warn "cia402.comp not found in $CIA402_DIR"
fi

echo ""
echo "==================================================================="
echo "EtherCAT Installation Complete!"
echo "==================================================================="
echo "Interface:       $ETHERCAT_INTERFACE"
echo "MAC Address:     $ETHERCAT_MAC"
echo "Config file:     /etc/ethercat.conf"
echo "Service status:  $(systemctl is-active ethercat.service)"
echo ""
echo "Test EtherCAT slaves with:"
echo "  ethercat slaves"
echo ""
echo "NOTE: Reboot recommended for udev rules to take full effect"
echo "==================================================================="
echo ""
