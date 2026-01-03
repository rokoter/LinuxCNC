#!/bin/bash
################################################################################
# Module: preflight-checks.sh
# Description: Validate system requirements before installation
################################################################################

log "Running pre-flight checks..."

PREFLIGHT_PASSED=true

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "Pre-flight: Must run as root (use sudo)"
    PREFLIGHT_PASSED=false
fi

# Check internet connectivity
log "Checking internet connectivity..."
if ping -c 1 -W 2 github.com &> /dev/null || ping -c 1 -W 2 8.8.8.8 &> /dev/null; then
    log "✓ Internet connectivity OK"
else
    warn "✗ No internet connectivity detected"
    warn "  Some features may not work without internet"
fi

# Check disk space (need at least 5GB free)
log "Checking disk space..."
AVAILABLE_GB=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$AVAILABLE_GB" -lt 5 ]; then
    error "✗ Insufficient disk space: ${AVAILABLE_GB}GB available, need at least 5GB"
    PREFLIGHT_PASSED=false
else
    log "✓ Disk space OK: ${AVAILABLE_GB}GB available"
fi

# Check CPU count
log "Checking CPU configuration..."
TOTAL_CORES=$(nproc)
if [ "$TOTAL_CORES" -lt 2 ]; then
    warn "✗ Only $TOTAL_CORES CPU core detected"
    warn "  Realtime performance may be limited"
else
    log "✓ CPU cores OK: $TOTAL_CORES cores"
fi

# Check if running on RT kernel
log "Checking kernel type..."
if uname -r | grep -q "rt"; then
    log "✓ Real-time kernel detected: $(uname -r)"
else
    warn "✗ Non-RT kernel detected: $(uname -r)"
    warn "  For best performance, use a real-time kernel"
fi

# Check for virtualization
log "Checking virtualization..."
if systemd-detect-virt &> /dev/null; then
    VIRT_TYPE=$(systemd-detect-virt)
    if [ "$VIRT_TYPE" != "none" ]; then
        warn "✗ Running in virtual machine: $VIRT_TYPE"
        warn "  Realtime performance will be significantly degraded"
        warn "  This is OK for testing but NOT for production use"
    fi
else
    log "✓ Not running in virtual machine"
fi

# Check for conflicting packages
log "Checking for conflicting packages..."
CONFLICTS=()
if dpkg -l | grep -q "network-manager"; then
    CONFLICTS+=("network-manager (can interfere with EtherCAT)")
fi

if [ ${#CONFLICTS[@]} -gt 0 ]; then
    warn "Potentially conflicting packages detected:"
    for pkg in "${CONFLICTS[@]}"; do
        warn "  - $pkg"
    done
fi

# Summary
echo ""
echo "==================================================================="
echo "Pre-flight Check Summary"
echo "==================================================================="
if [ "$PREFLIGHT_PASSED" = true ]; then
    log "✓ All critical checks passed"
    echo ""
    return 0
else
    error "✗ Some critical checks failed"
    echo ""
    echo "Please resolve the issues above before continuing."
    echo ""
    read -p "Continue anyway? [y/N]: " CONTINUE
    if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
        fatal "Installation aborted by user"
    fi
fi
echo "==================================================================="
echo ""
