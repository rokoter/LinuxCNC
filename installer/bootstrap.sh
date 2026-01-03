#!/bin/bash
################################################################################
# LinuxCNC EtherCAT Bootstrap Script
# 
# One-command installation from fresh LinuxCNC install
#
# Usage (feature-installer branch - CURRENT):
#   curl -sSL https://raw.githubusercontent.com/rokoter/LinuxCNC/feature-installer/installer/bootstrap.sh | sudo bash
#
# Usage (main branch - after merge):
#   curl -sSL https://raw.githubusercontent.com/rokoter/LinuxCNC/main/installer/bootstrap.sh | sudo bash
#
# Force specific branch (optional):
#   BOOTSTRAP_BRANCH=develop curl -sSL https://raw.../bootstrap.sh | sudo -E bash
#
# Or download and run:
#   wget https://raw.githubusercontent.com/rokoter/LinuxCNC/feature-installer/installer/bootstrap.sh
#   sudo bash bootstrap.sh
#
################################################################################

# SCRIPT METADATA - AUTO-UPDATED BY BUILD PROCESS
# This helps bootstrap detect which branch it came from
SCRIPT_BRANCH_HINT="feature-installer"

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

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
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

# Detect which branch this bootstrap script came from
# Try to auto-detect from the script's own path if downloaded via wget/curl
# Otherwise fall back to environment variable or default

if [ -z "${BOOTSTRAP_BRANCH:-}" ]; then
    # Try to detect from script location if we can
    # When piped from curl, BASH_SOURCE doesn't exist, so use conditional
    SCRIPT_PATH=""
    if [ -n "${BASH_SOURCE[0]:-}" ]; then
        SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "")"
    fi
    
    # Use embedded hint as default (this is set at top of script)
    DETECTED_BRANCH="${SCRIPT_BRANCH_HINT:-main}"
    
    # If script path contains a branch indicator, try to parse it
    # This works if the script was downloaded to a predictable location
    # But when piped from curl, SCRIPT_PATH will be empty
    
    if [[ -n "$SCRIPT_PATH" && "$SCRIPT_PATH" =~ feature-installer ]]; then
        DETECTED_BRANCH="feature-installer"
    fi
    
    BRANCH="$DETECTED_BRANCH"
    log "Auto-detected branch: $BRANCH"
    if [ "$BRANCH" != "${SCRIPT_BRANCH_HINT}" ]; then
        log "(Detected from script path)"
    fi
    log "(Override with: BOOTSTRAP_BRANCH=your-branch)"
else
    BRANCH="$BOOTSTRAP_BRANCH"
    log "Using specified branch: $BRANCH"
fi

if [ -d "$REPO_DIR" ]; then
    log "Repository already exists at $REPO_DIR"
    read -p "Pull latest changes? [Y/n]: " UPDATE_REPO
    if [[ ! "$UPDATE_REPO" =~ ^[Nn]$ ]]; then
        log "Updating repository (branch: $BRANCH)..."
        cd "$REPO_DIR"
        sudo -u "$ACTUAL_USER" git fetch origin
        
        # Try to checkout the branch, create tracking branch if needed
        sudo -u "$ACTUAL_USER" git checkout "$BRANCH" 2>/dev/null || \
            sudo -u "$ACTUAL_USER" git checkout -b "$BRANCH" "origin/$BRANCH" 2>/dev/null || {
            warn "Could not checkout branch $BRANCH"
            warn "Available branches:"
            sudo -u "$ACTUAL_USER" git branch -r
            exit 1
        }
        
        sudo -u "$ACTUAL_USER" git pull origin "$BRANCH"
    fi
else
    log "Cloning repository from $REPO_URL (branch: $BRANCH)..."
    cd "$ACTUAL_HOME"
    
    # Try to clone the specific branch
    sudo -u "$ACTUAL_USER" git clone -b "$BRANCH" "$REPO_URL" 2>/dev/null || {
        warn "Failed to clone branch $BRANCH directly"
        log "Cloning default branch and checking out $BRANCH..."
        sudo -u "$ACTUAL_USER" git clone "$REPO_URL"
        cd "$REPO_DIR"
        sudo -u "$ACTUAL_USER" git checkout "$BRANCH" || {
            error "Branch $BRANCH does not exist!"
            error "Available branches:"
            sudo -u "$ACTUAL_USER" git branch -r
            exit 1
        }
    }
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

# Since bootstrap already cloned/updated the repo, tell installer to use local files
# This prevents git conflicts during installation
INSTALLER_ARGS="--local $@"

# Redirect stdin from /dev/tty so interactive prompts work
# Even when bootstrap was piped from curl
if [ -t 0 ]; then
    # stdin is already a terminal
    exec bash "$INSTALLER_SCRIPT" $INSTALLER_ARGS
else
    # stdin is NOT a terminal (piped from curl), redirect from /dev/tty
    exec bash "$INSTALLER_SCRIPT" $INSTALLER_ARGS < /dev/tty
fi
