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

# Note: 99-ethercat.rules is created by install-ethercat.sh
# We only need to ensure network optimizations are present
# Check if the file exists and has EtherCAT permissions rule
if [ -f /etc/udev/rules.d/99-ethercat.rules ]; then
    if ! grep -q "KERNEL.*EtherCAT" /etc/udev/rules.d/99-ethercat.rules; then
        warn "EtherCAT permissions rule missing from udev rules"
        log "Adding EtherCAT device permissions to existing rules..."
        # Prepend the EtherCAT rule
        echo '# EtherCAT device permissions' | cat - /etc/udev/rules.d/99-ethercat.rules > /tmp/99-ethercat.rules.tmp
        echo 'KERNEL=="EtherCAT[0-9]*", MODE="0666"' >> /tmp/99-ethercat.rules.tmp
        echo '' >> /tmp/99-ethercat.rules.tmp
        cat /etc/udev/rules.d/99-ethercat.rules >> /tmp/99-ethercat.rules.tmp
        mv /tmp/99-ethercat.rules.tmp /etc/udev/rules.d/99-ethercat.rules
    fi
    log "EtherCAT udev rules verified"
else
    log "Note: EtherCAT udev rules will be created by install-ethercat module"
fi

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
BIOS_RECOMMENDATIONS_FILE="$ACTUAL_HOME/BIOS_RECOMMENDATIONS.txt"

cat > "$BIOS_RECOMMENDATIONS_FILE" << 'EOF'
=================================================================
IMPORTANT: BIOS Settings Recommendations
=================================================================

For optimal realtime performance, configure your BIOS:

DISABLE:
  - Intel SpeedStep / EIST
  - Turbo Boost / Turbo Mode
  - C-States (C3, C6, C7, etc.)
  - Package C-State
  - CPU C-States
  - Enhanced Halt State (C1E)
  - Hyper-Threading (test both enabled/disabled)

ENABLE:
  - Performance Mode (if available)

After changing BIOS settings, run latency test:
  latency-histogram

Target: servo thread max < 50µs

=================================================================
This file saved to: ~/BIOS_RECOMMENDATIONS.txt
=================================================================
EOF

chown "$DEFAULT_USERNAME:$DEFAULT_USERNAME" "$BIOS_RECOMMENDATIONS_FILE"

log "BIOS recommendations saved to $BIOS_RECOMMENDATIONS_FILE"

log "Realtime optimization complete"
log "NOTE: Reboot required for changes to take effect"
