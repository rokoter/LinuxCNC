#!/bin/bash
################################################################################
# LinuxCNC Machine Auto-Installer
# Author: RoKoTer
# Description: Automated installation and configuration for LinuxCNC machines
################################################################################

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default configuration
DEFAULT_GIT_REPO="https://github.com/rokoter/LinuxCNC.git"
DEFAULT_GIT_BRANCH="main"
DEFAULT_HOSTNAME="linuxcnc"

# Determine the actual user (not root when using sudo)
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    ACTUAL_USER="$SUDO_USER"
    ACTUAL_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    ACTUAL_USER="$USER"
    ACTUAL_HOME="$HOME"
fi

DEFAULT_USERNAME="$ACTUAL_USER"

# Default machine configuration (can be overridden by command line args)
MACHINE_TYPE="ihsv-single"
MACHINE_NAME="IHSV-57 Single Axis"
CONFIG_PATH="ethercat/ihsv-homing"
GIT_BRANCH="main"
GIT_PULL=true
HOSTNAME="$DEFAULT_HOSTNAME"
SKIP_UPGRADE=false  # Default: do upgrade (can override with --no-upgrade)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# Helper Functions
################################################################################

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

fatal() {
    error "$*"
    exit 1
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        fatal "This script must be run as root. Use: sudo $0"
    fi
}

################################################################################
# Configuration Menu
################################################################################

show_banner() {
    clear
    echo -e "${BLUE}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║     LinuxCNC Machine Auto-Installer                          ║
║     Version 1.0.6                                            ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

show_machine_menu() {
    echo ""
    echo "=== Select Machine Type ==="
    echo "1) IHSV-57 Single Axis (Test Setup)"
    echo "2) XYZ Gantry (3-axis)"
    echo "3) XYYZ Gantry (4-axis with dual Y)"
    echo "4) Custom Configuration"
    echo "0) Exit"
    echo ""
    read -p "Choice [1]: " MACHINE_CHOICE
    MACHINE_CHOICE=${MACHINE_CHOICE:-1}
}

show_git_menu() {
    echo ""
    echo "=== Git Configuration ==="
    echo "1) main branch (stable, production)"
    echo "2) develop branch (testing)"
    echo "3) Custom branch"
    echo "4) Use local files (no git pull)"
    echo ""
    read -p "Choice [1]: " GIT_CHOICE
    GIT_CHOICE=${GIT_CHOICE:-1}
}

configure_machine() {
    case $MACHINE_CHOICE in
        1)
            MACHINE_TYPE="ihsv-single"
            MACHINE_NAME="IHSV-57 Single Axis"
            CONFIG_PATH="ethercat/ihsv-homing"
            ;;
        2)
            MACHINE_TYPE="xyz-gantry"
            MACHINE_NAME="XYZ Gantry"
            CONFIG_PATH="ethercat/xyz-gantry"
            ;;
        3)
            MACHINE_TYPE="xyyz-gantry"
            MACHINE_NAME="XYYZ Gantry (Dual Y)"
            CONFIG_PATH="ethercat/xyyz-gantry"
            ;;
        4)
            read -p "Machine type: " MACHINE_TYPE
            read -p "Config path: " CONFIG_PATH
            MACHINE_NAME="Custom ($MACHINE_TYPE)"
            ;;
        0)
            echo "Installation cancelled."
            exit 0
            ;;
        *)
            warn "Invalid choice, using default (IHSV-57 Single Axis)"
            MACHINE_TYPE="ihsv-single"
            MACHINE_NAME="IHSV-57 Single Axis"
            CONFIG_PATH="ethercat/ihsv-homing"
            ;;
    esac
}

configure_git() {
    case $GIT_CHOICE in
        1)
            GIT_BRANCH="main"
            GIT_PULL=true
            ;;
        2)
            GIT_BRANCH="develop"
            GIT_PULL=true
            ;;
        3)
            read -p "Branch name: " GIT_BRANCH
            GIT_PULL=true
            ;;
        4)
            GIT_PULL=false
            warn "Using local files only - no git pull"
            ;;
        *)
            warn "Invalid choice, using main branch"
            GIT_BRANCH="main"
            GIT_PULL=true
            ;;
    esac
}

get_hostname() {
    echo ""
    read -p "Hostname [$DEFAULT_HOSTNAME]: " HOSTNAME
    HOSTNAME=${HOSTNAME:-$DEFAULT_HOSTNAME}
}

show_summary() {
    echo ""
    echo "=== Installation Summary ==="
    echo "Machine Type:     $MACHINE_NAME"
    echo "Config Path:      $CONFIG_PATH"
    echo "Git Branch:       ${GIT_BRANCH:-local files}"
    echo "Hostname:         $HOSTNAME"
    echo "Username:         $DEFAULT_USERNAME"
    echo ""
    read -p "Proceed with installation? [y/N]: " CONFIRM
    
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi
}

################################################################################
# Installation Modules
################################################################################

run_module() {
    local module_name=$1
    local module_script="$SCRIPT_DIR/modules/${module_name}.sh"
    
    if [ -f "$module_script" ]; then
        log "Running module: $module_name"
        # shellcheck source=/dev/null
        source "$module_script"
    else
        warn "Module not found: $module_script"
        warn "Creating placeholder for: $module_name"
        cat > "$module_script" << EOF
#!/bin/bash
# Module: $module_name
# TODO: Implement this module

log "Module $module_name - Not yet implemented"
# Add your implementation here
EOF
        chmod +x "$module_script"
    fi
}

install_system_basics() {
    log "Setting up system basics..."
    
    # Set hostname
    hostnamectl set-hostname "$HOSTNAME"
    
    # Update system
    log "Updating package lists..."
    apt-get update
    
    # Check if we should upgrade
    if [ "$SKIP_UPGRADE" = false ]; then
        # Interactive mode - ask user
        if [ -t 0 ]; then
            echo ""
            echo "==================================================================="
            echo "System Update"
            echo "==================================================================="
            echo ""
            echo "It is recommended to upgrade all system packages before installing"
            echo "LinuxCNC and EtherCAT components."
            echo ""
            echo "This may download ~500MB and take 5-10 minutes."
            echo ""
            read -p "Upgrade system packages now? [Y/n]: " DO_UPGRADE
            
            if [[ "$DO_UPGRADE" =~ ^[Nn]$ ]]; then
                warn "Skipping system upgrade"
                warn "You may encounter package conflicts or missing dependencies"
            else
                log "Upgrading system packages..."
                apt-get upgrade -y
                log "System upgrade complete"
            fi
        else
            # Non-interactive mode - just do it
            log "Upgrading system packages (non-interactive mode)..."
            apt-get upgrade -y
            log "System upgrade complete"
        fi
    else
        warn "Skipping system upgrade (--no-upgrade flag set)"
    fi
    
    # Install essential packages
    log "Installing essential packages..."
    apt-get install -y \
        git \
        vim \
        htop \
        net-tools \
        ethtool \
        build-essential \
        linux-headers-$(uname -r)
}

clone_or_update_repo() {
    if [ "$GIT_PULL" = false ]; then
        log "Skipping git operations (using local files)"
        return 0
    fi
    
    local repo_dir="$ACTUAL_HOME/LinuxCNC"
    
    # Ensure home directory exists
    if [ ! -d "$ACTUAL_HOME" ]; then
        error "Home directory $ACTUAL_HOME does not exist!"
        return 1
    fi
    
    if [ -d "$repo_dir" ]; then
        log "Repository exists, updating..."
        cd "$repo_dir" || {
            error "Failed to change to repository directory"
            return 1
        }
        
        # Check for local changes
        if ! git diff-index --quiet HEAD -- 2>/dev/null; then
            warn "Local changes detected in repository"
            echo ""
            echo "Options:"
            echo "1) Stash changes and pull (RECOMMENDED)"
            echo "2) Commit changes locally"
            echo "3) Discard local changes (DESTRUCTIVE)"
            echo "4) Skip git update (use local files)"
            echo ""
            read -p "Choice [1]: " GIT_CHOICE
            GIT_CHOICE=${GIT_CHOICE:-1}
            
            case $GIT_CHOICE in
                1)
                    log "Stashing local changes..."
                    git stash push -m "Auto-stash before installer update - $(date +%Y%m%d-%H%M%S)"
                    ;;
                2)
                    log "Committing local changes..."
                    git add -A
                    git commit -m "Auto-commit before installer update - $(date +%Y%m%d-%H%M%S)"
                    ;;
                3)
                    warn "Discarding local changes..."
                    git reset --hard HEAD
                    git clean -fd
                    ;;
                4)
                    log "Skipping git update, using local files"
                    return 0
                    ;;
                *)
                    error "Invalid choice, aborting"
                    return 1
                    ;;
            esac
        fi
        
        # Now safe to checkout and pull
        git fetch origin
        git checkout "$GIT_BRANCH" || {
            error "Failed to checkout branch $GIT_BRANCH"
            warn "You may need to manually resolve git issues"
            return 1
        }
        git pull origin "$GIT_BRANCH" || {
            warn "Git pull failed, continuing with current version"
        }
    else
        log "Cloning repository..."
        cd "$ACTUAL_HOME" || {
            error "Failed to change to home directory"
            return 1
        }
        git clone -b "$GIT_BRANCH" "$DEFAULT_GIT_REPO"
        chown -R "$DEFAULT_USERNAME:$DEFAULT_USERNAME" "$repo_dir"
    fi
    
    log "Repository location: $repo_dir"
}

################################################################################
# Main Installation Flow
################################################################################

main() {
    show_banner
    
    # Check prerequisites
    check_root
    
    # Run pre-flight checks
    run_module "preflight-checks"
    
    # Interactive configuration
    show_machine_menu
    configure_machine
    
    show_git_menu
    configure_git
    
    get_hostname
    
    # Show summary and confirm
    show_summary
    
    log "Starting installation..."
    
    # Run installation steps
    install_system_basics
    clone_or_update_repo
    
    # Run modular installation steps
    run_module "install-ethercat"
    run_module "install-linuxcnc"
    run_module "optimize-realtime"
    run_module "setup-machine-config"
    
    # Final summary
    echo ""
    echo "=================================================================="
    log "Installation complete!"
    echo "=================================================================="
    echo ""
    
    # Show BIOS recommendations
    echo "⚙️  IMPORTANT: BIOS Configuration Required"
    echo ""
    echo "For optimal realtime performance, configure your BIOS:"
    echo ""
    echo "DISABLE:"
    echo "  • Intel SpeedStep / EIST"
    echo "  • Turbo Boost / Turbo Mode"  
    echo "  • C-States (C3, C6, C7, etc.)"
    echo "  • Package C-State"
    echo "  • Enhanced Halt State (C1E)"
    echo "  • Hyper-Threading (test both)"
    echo ""
    echo "ENABLE:"
    echo "  • Performance Mode"
    echo ""
    echo "📄 Full instructions saved to: ~/BIOS_RECOMMENDATIONS.txt"
    echo ""
    echo "=================================================================="
    echo ""
    echo "=== Next Steps ==="
    echo "1. Configure BIOS settings (see above)"
    echo "2. Reboot the system: sudo reboot"
    echo "3. Run latency test: latency-histogram (target: <50µs)"
    echo "4. Fix EtherCAT permissions: sudo chmod 666 /dev/EtherCAT0"
    echo "5. Start LinuxCNC: linuxcnc ~/linuxcnc/configs/active-machine/<config>.ini"
    echo ""
    echo "Configuration: $ACTUAL_HOME/LinuxCNC/$CONFIG_PATH"
    echo ""
    echo "=================================================================="
    echo ""
    
    read -p "Reboot now? [y/N]: " REBOOT_NOW
    if [[ "$REBOOT_NOW" =~ ^[Yy]$ ]]; then
        log "Rebooting system..."
        reboot
    fi
}

################################################################################
# Command Line Arguments Support
################################################################################

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --machine)
                MACHINE_TYPE="$2"
                # Set MACHINE_NAME and CONFIG_PATH based on type
                case $MACHINE_TYPE in
                    ihsv-single)
                        MACHINE_NAME="IHSV-57 Single Axis"
                        CONFIG_PATH="ethercat/ihsv-homing"
                        ;;
                    xyz-gantry)
                        MACHINE_NAME="XYZ Gantry"
                        CONFIG_PATH="ethercat/xyz-gantry"
                        ;;
                    xyyz-gantry)
                        MACHINE_NAME="XYYZ Gantry (Dual Y)"
                        CONFIG_PATH="ethercat/xyyz-gantry"
                        ;;
                    *)
                        MACHINE_NAME="Custom ($MACHINE_TYPE)"
                        CONFIG_PATH="$MACHINE_TYPE"
                        ;;
                esac
                shift 2
                ;;
            --branch)
                GIT_BRANCH="$2"
                GIT_PULL=true
                shift 2
                ;;
            --hostname)
                HOSTNAME="$2"
                shift 2
                ;;
            --local)
                GIT_PULL=false
                shift
                ;;
            --no-upgrade)
                SKIP_UPGRADE=true
                shift
                ;;
            --upgrade)
                SKIP_UPGRADE=false
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Automated LinuxCNC machine installer

OPTIONS:
    --machine TYPE      Machine type (ihsv-single, xyz-gantry, xyyz-gantry)
    --branch BRANCH     Git branch to use (main, develop, custom)
    --hostname NAME     Set hostname
    --local             Use local files, skip git pull
    --upgrade           Force system package upgrade (default in non-interactive)
    --no-upgrade        Skip system package upgrade
    --help              Show this help message

EXAMPLES:
    # Interactive mode (will ask about upgrade)
    sudo $0

    # Automated mode with upgrade
    sudo $0 --machine xyz-gantry --branch main --hostname mill-01

    # Skip system upgrade (faster, but may have issues)
    sudo $0 --machine ihsv-single --no-upgrade

    # Use local files
    sudo $0 --local

EOF
}

################################################################################
# Entry Point
################################################################################

# Parse command line arguments if provided
if [ $# -gt 0 ]; then
    parse_args "$@"
    # Run non-interactively
    check_root
    
    # Run pre-flight checks
    run_module "preflight-checks"
    
    # Show what we're doing
    show_summary
    
    # Start installation
    log "Starting installation..."
    install_system_basics
    clone_or_update_repo
    run_module "install-ethercat"
    run_module "install-linuxcnc"
    run_module "optimize-realtime"
    run_module "setup-machine-config"
    
    # Final summary
    echo ""
    echo "=================================================================="
    log "Installation complete!"
    echo "=================================================================="
    echo ""
    
    # Show BIOS recommendations
    echo "⚙️  IMPORTANT: BIOS Configuration Required"
    echo ""
    echo "For optimal realtime performance, configure your BIOS:"
    echo ""
    echo "DISABLE:"
    echo "  • Intel SpeedStep / EIST"
    echo "  • Turbo Boost / Turbo Mode"
    echo "  • C-States (C3, C6, C7, etc.)"
    echo "  • Package C-State"
    echo "  • Enhanced Halt State (C1E)"
    echo "  • Hyper-Threading (test both)"
    echo ""
    echo "ENABLE:"
    echo "  • Performance Mode"
    echo ""
    echo "📄 Full instructions saved to: ~/BIOS_RECOMMENDATIONS.txt"
    echo ""
    echo "=================================================================="
    echo ""
    echo "=== Next Steps ==="
    echo "1. Configure BIOS settings (see above)"
    echo "2. Reboot the system: sudo reboot"
    echo "3. Run latency test: latency-histogram (target: <50µs)"
    echo "4. Fix EtherCAT permissions: sudo chmod 666 /dev/EtherCAT0"
    echo "5. Start LinuxCNC: linuxcnc ~/linuxcnc/configs/active-machine/<config>.ini"
    echo ""
    echo "Configuration: $ACTUAL_HOME/LinuxCNC/$CONFIG_PATH"
    echo ""
    echo "=================================================================="
    echo ""
else
    # Run interactively
    main
fi
