#!/bin/bash
#
# download-rt-kernel.sh
# Script om automatisch de nieuwste RT kernel en patch te downloaden
#
# Gebruik: ./download-rt-kernel.sh [output_directory]
#

set -e  # Stop bij errors

# Kleuren voor output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functie voor colored output
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check of we curl hebben
if ! command -v curl &> /dev/null; then
    error "curl is niet geïnstalleerd. Installeer met: sudo dnf install -y curl"
    exit 1
fi

if ! command -v wget &> /dev/null; then
    error "wget is niet geïnstalleerd. Installeer met: sudo dnf install -y wget"
    exit 1
fi

# Bepaal output directory
OUTPUT_DIR="${1:-$(pwd)}"

if [ ! -d "$OUTPUT_DIR" ]; then
    error "Directory $OUTPUT_DIR bestaat niet!"
    exit 1
fi

cd "$OUTPUT_DIR"
info "Werkdirectory: $OUTPUT_DIR"

# Functie om nieuwste RT versie te vinden
get_latest_rt_kernel() {
    echo "Zoeken naar nieuwste RT kernel op kernel.org..." >&2
    
    # Haal lijst van versie directories
    local versions=$(curl -s https://cdn.kernel.org/pub/linux/kernel/projects/rt/ | \
                     grep -oP 'href="\K[0-9]+\.[0-9]+(?=/)' | \
                     sort -V)
    
    if [ -z "$versions" ]; then
        echo "ERROR: Kon geen RT kernel versies vinden!" >&2
        return 1
    fi
    
    # Loop door versies van nieuw naar oud
    for ver in $(echo "$versions" | tac); do
        echo "Controleren van versie $ver..." >&2
        
        # Check of er patches zijn voor deze versie
        local patches=$(curl -s "https://cdn.kernel.org/pub/linux/kernel/projects/rt/${ver}/" 2>/dev/null | \
                       grep -oP 'patch-\K[0-9]+\.[0-9]+-rt[0-9]+' | \
                       sort -V | tail -1)
        
        if [ -n "$patches" ]; then
            # Output alleen het resultaat naar stdout
            echo "$ver|$patches"
            return 0
        fi
    done
    
    return 1
}

# Haal versie informatie op
info "Bezig met ophalen van versie informatie..."
VERSION_INFO=$(get_latest_rt_kernel)

if [ -z "$VERSION_INFO" ]; then
    error "Kon geen RT kernel vinden!"
    exit 1
fi

# Parse de versie informatie
KERNEL_VERSION=$(echo "$VERSION_INFO" | cut -d'|' -f1)
RT_PATCH=$(echo "$VERSION_INFO" | cut -d'|' -f2)
KERNEL_MAJOR=$(echo "$KERNEL_VERSION" | cut -d'.' -f1)

echo ""
info "==================================================="
info "Gevonden versies:"
info "  Kernel versie: $KERNEL_VERSION"
info "  RT patch:      $RT_PATCH"
info "  Major versie:  $KERNEL_MAJOR"
info "==================================================="
echo ""

# Bepaal URLs
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v${KERNEL_MAJOR}.x/linux-${KERNEL_VERSION}.tar.xz"
PATCH_URL="https://cdn.kernel.org/pub/linux/kernel/projects/rt/${KERNEL_VERSION}/patch-${RT_PATCH}.patch.xz"

KERNEL_FILE="linux-${KERNEL_VERSION}.tar.xz"
PATCH_FILE="patch-${RT_PATCH}.patch.xz"

# Check of bestanden al bestaan
SKIP_KERNEL=false
SKIP_PATCH=false

if [ -f "$KERNEL_FILE" ]; then
    warn "Kernel bestand bestaat al: $KERNEL_FILE"
    read -p "Opnieuw downloaden? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Kernel download overgeslagen"
        SKIP_KERNEL=true
    fi
fi

if [ -f "$PATCH_FILE" ]; then
    warn "Patch bestand bestaat al: $PATCH_FILE"
    read -p "Opnieuw downloaden? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Patch download overgeslagen"
        SKIP_PATCH=true
    fi
fi

# Download kernel
if [ "$SKIP_KERNEL" != "true" ]; then
    info "Downloaden van kernel..."
    info "URL: $KERNEL_URL"
    if wget -c "$KERNEL_URL"; then
        info "Kernel succesvol gedownload: $KERNEL_FILE"
    else
        error "Fout bij downloaden van kernel!"
        exit 1
    fi
else
    info "Kernel bestand aanwezig: $KERNEL_FILE"
fi

# Download patch
if [ "$SKIP_PATCH" != "true" ]; then
    info "Downloaden van RT patch..."
    info "URL: $PATCH_URL"
    if wget -c "$PATCH_URL"; then
        info "RT patch succesvol gedownload: $PATCH_FILE"
    else
        error "Fout bij downloaden van RT patch!"
        exit 1
    fi
else
    info "Patch bestand aanwezig: $PATCH_FILE"
fi

# Verificatie
echo ""
info "==================================================="
info "Download compleet!"
info "==================================================="
info "Bestanden:"
if [ -f "$KERNEL_FILE" ]; then
    info "  $(ls -lh $KERNEL_FILE)"
else
    warn "  Kernel bestand niet gevonden"
fi
if [ -f "$PATCH_FILE" ]; then
    info "  $(ls -lh $PATCH_FILE)"
else
    warn "  Patch bestand niet gevonden"
fi
echo ""
info "Volgende stappen:"
info "  1. Uitpakken:  tar xf $KERNEL_FILE"
info "  2. Directory:  cd linux-${KERNEL_VERSION}"
info "  3. Patchen:    xzcat ../$PATCH_FILE | patch -p1"
info "  4. Config:     cp /boot/config-\$(uname -r) .config"
info "  5. Update:     make olddefconfig"
info "  6. Menuconfig: make menuconfig"
info "     (Selecteer: General setup -> Preemption Model -> Fully Preemptible Kernel (RT))"
info "  7. Compileer:  make -j\$(nproc)"
info "  8. Installeer: sudo make modules_install && sudo make install"
info "  9. GRUB:       sudo grub2-mkconfig -o /boot/grub2/grub.cfg"
info " 10. Reboot:     sudo reboot"
info "==================================================="
echo ""

# Optioneel: Maak een simpel extract script
cat > extract-and-patch.sh << 'EXTRACT_EOF'
#!/bin/bash
set -e

KERNEL_FILE=$(ls linux-*.tar.xz 2>/dev/null | head -1)
PATCH_FILE=$(ls patch-*.patch.xz 2>/dev/null | head -1)

if [ -z "$KERNEL_FILE" ] || [ -z "$PATCH_FILE" ]; then
    echo "Error: Kernel of patch bestand niet gevonden!"
    exit 1
fi

KERNEL_DIR=$(basename "$KERNEL_FILE" .tar.xz)

echo "Uitpakken van $KERNEL_FILE..."
tar xf "$KERNEL_FILE"

echo "Toepassen van patch $PATCH_FILE..."
cd "$KERNEL_DIR"
xzcat "../$PATCH_FILE" | patch -p1

echo ""
echo "Klaar! Kernel is uitgepakt en gepatched in: $KERNEL_DIR"
echo "Ga naar de directory met: cd $KERNEL_DIR"
EXTRACT_EOF

chmod +x extract-and-patch.sh
info "Helper script aangemaakt: extract-and-patch.sh"
info "Uitvoeren met: ./extract-and-patch.sh"

exit 0