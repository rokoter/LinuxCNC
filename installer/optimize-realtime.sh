#!/bin/bash
################################################################################
# Module: optimize-realtime.sh
# Description: Optimize system for realtime performance
################################################################################

log "Optimizing system for realtime performance..."

# Detect number of CPU cores
TOTAL_CORES=$(nproc)
log "Detected $TOTAL_CORES CPU cores"

# Isolate last 2 cores for realtime
if [ "$TOTAL_CORES" -ge 4 ]; then
    ISOLATE_START=$((TOTAL_CORES - 2))
    ISOLATE_END=$((TOTAL_CORES - 1))
    ISOLATE_CORES="${ISOLATE_START},${ISOLATE_END}"
    
    log "Will isolate cores: $ISOLATE_CORES"
else
    warn "Only $TOTAL_CORES cores detected, skipping CPU isolation"
    ISOLATE_CORES=""
fi

# Backup GRUB config
if [ -f /etc/default/grub ]; then
    log "Backing up GRUB configuration..."
    cp /etc/default/grub /etc/default/grub.backup.$(date +%Y%m%d-%H%M%S)
fi

# Configure GRUB
log "Configuring GRUB for realtime..."

if [ -n "$ISOLATE_CORES" ]; then
    # Add isolcpus parameters
    GRUB_PARAMS="isolcpus=$ISOLATE_CORES nohz_full=$ISOLATE_CORES rcu_nocbs=$ISOLATE_CORES"
    
    # Check if parameters already exist
    if grep -q "isolcpus=" /etc/default/grub; then
        warn "CPU isolation already configured in GRUB"
        cat /etc/default/grub | grep GRUB_CMDLINE_LINUX_DEFAULT
    else
        # Add parameters to GRUB_CMDLINE_LINUX_DEFAULT
        sed -i.bak "s/GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1 $GRUB_PARAMS\"/" /etc/default/grub
        log "Added CPU isolation parameters to GRUB"
    fi
    
    # Update GRUB
    log "Updating GRUB..."
    update-grub
else
    log "Skipping GRUB CPU isolation (not enough cores)"
fi

# Disable power management on EtherCAT interface
log "Configuring EtherCAT network interface..."

# Create udev rule for EtherCAT interface
cat > /etc/udev/rules.d/99-ethercat.rules << 'EOF'
# Disable power management and offloading for EtherCAT interface
SUBSYSTEM=="net", ACTION=="add", KERNEL=="eth0", RUN+="/usr/sbin/ethtool -s %k wol d"
SUBSYSTEM=="net", ACTION=="add", KERNEL=="eth0", RUN+="/usr/sbin/ethtool -K %k gro off"
SUBSYSTEM=="net", ACTION=="add", KERNEL=="eth0", RUN+="/usr/sbin/ethtool -K %k lro off"
SUBSYSTEM=="net", ACTION=="add", KERNEL=="eth0", RUN+="/usr/sbin/ethtool -K %k tso off"
SUBSYSTEM=="net", ACTION=="add", KERNEL=="eth0", RUN+="/usr/sbin/ethtool -K %k gso off"
EOF

log "Created udev rules for EtherCAT interface"

# Disable unnecessary services
log "Disabling unnecessary services..."

SERVICES_TO_DISABLE=(
    "bluetooth"
    "cups"
    "avahi-daemon"
)

for service in "${SERVICES_TO_DISABLE[@]}"; do
    if systemctl is-enabled "$service" &>/dev/null; then
        systemctl disable "$service" || warn "Could not disable $service"
        log "Disabled $service"
    fi
done

# Display BIOS recommendations
echo ""
echo "==================================================================="
echo "IMPORTANT: BIOS Settings Recommendations"
echo "==================================================================="
echo ""
echo "For optimal realtime performance, configure your BIOS:"
echo ""
echo "DISABLE:"
echo "  - Intel SpeedStep / EIST"
echo "  - Turbo Boost / Turbo Mode"
echo "  - C-States (C3, C6, C7, etc.)"
echo "  - Package C-State"
echo "  - CPU C-States"
echo "  - Enhanced Halt State (C1E)"
echo "  - Hyper-Threading (test both enabled/disabled)"
echo ""
echo "ENABLE:"
echo "  - Performance Mode (if available)"
echo ""
echo "After changing BIOS settings, run latency test:"
echo "  latency-histogram"
echo ""
echo "Target: servo thread max < 50µs"
echo "==================================================================="
echo ""

log "Realtime optimization complete"
log "NOTE: Reboot required for changes to take effect"
