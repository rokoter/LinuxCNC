#!/bin/bash
################################################################################
# LinuxCNC EtherCAT Bootstrap Script
# 
# One-command installation from fresh LinuxCNC install
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/rokoter/LinuxCNC/main/installer/bootstrap.sh | sudo bash
#
# Or download and run:
#   wget https://raw.githubusercontent.com/rokoter/LinuxCNC/main/installer/bootstrap.sh
#   sudo bash bootstrap.sh
#
################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[BOOTSTRAP]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Check root
if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root"
    echo "Usage: sudo $0"
    echo "Or: curl -sSL https://...../bootstrap.sh | sudo bash"
    exit 1
fi

# Detect actual user (not root when using sudo)
ACTUAL_USER="${SUDO_USER:-$USER}"
ACTUAL_HOME=$(eval echo ~$ACTUAL_USER)

log "Bootstrap starting for user: $ACTUAL_USER"
log "Home directory: $ACTUAL_HOME"

# Update system first
log "Updating package lists (sudo apt update)..."
apt-get update -qq

# Install git if not present
if ! command -v git &> /dev/null; then
    log "Installing git..."
    apt-get install -y git
fi

# Install curl if not present (shouldn't happen if using curl to run this!)
if ! command -v curl &> /dev/null; then
    log "Installing curl..."
    apt-get install -y curl
fi

# Clone repository
REPO_DIR="$ACTUAL_HOME/LinuxCNC"
REPO_URL="https://github.com/rokoter/LinuxCNC.git"

if [ -d "$REPO_DIR" ]; then
    log "Repository already exists at $REPO_DIR"
    read -p "Pull latest changes? [Y/n]: " UPDATE_REPO
    if [[ ! "$UPDATE_REPO" =~ ^[Nn]$ ]]; then
        log "Updating repository..."
        cd "$REPO_DIR"
        sudo -u "$ACTUAL_USER" git pull
    fi
else
    log "Cloning repository from $REPO_URL..."
    cd "$ACTUAL_HOME"
    sudo -u "$ACTUAL_USER" git clone "$REPO_URL"
fi

# Check if installer exists
INSTALLER_DIR="$REPO_DIR/installer"
INSTALLER_SCRIPT="$INSTALLER_DIR/install.sh"

if [ ! -f "$INSTALLER_SCRIPT" ]; then
    error "Installer not found at $INSTALLER_SCRIPT"
    error "Repository structure may have changed"
    exit 1
fi

# Make installer executable
chmod +x "$INSTALLER_SCRIPT"
chmod +x "$INSTALLER_DIR"/modules/*.sh 2>/dev/null || true

log "Repository ready at $REPO_DIR"
log "Starting installer..."
echo ""

# Run the actual installer
cd "$INSTALLER_DIR"
exec bash "$INSTALLER_SCRIPT" "$@"
