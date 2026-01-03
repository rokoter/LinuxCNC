# v1.0.8 - Fix apt Upgrade Error on x86

## Probleem: initramfs-tools Error

Bij `apt upgrade` op N100 (x86) hardware:

```
raspi-firmware: missing /boot/firmware, did you forget to mount it?
dpkg: error processing package initramfs-tools (--configure):
 installed initramfs-tools package post-installation script subprocess returned error exit status 1
E: Sub-process /usr/bin/dpkg returned an error code (1)
```

**Oorzaak:**
- LinuxCNC Debian ISO bevat soms `raspi-firmware` package
- Dit is een Raspberry Pi package
- Werkt NIET op x86 systemen
- Blokkeert de upgrade

## Oplossing v1.0.8

**Veilige cleanup VOOR upgrade:**

```bash
# Detecteer architectuur
ARCH=$(uname -m)

# Alleen op x86/x86_64
if [[ "$ARCH" == "x86_64" ]] || [[ "$ARCH" == "i686" ]]; then
    # Verwijder incompatibel package
    apt-get remove --purge -y raspi-firmware
fi

# Nu werkt apt upgrade zonder errors
apt-get upgrade -y
```

**Op Raspberry Pi:**
- Detecteert ARM architectuur (armv7l, aarch64)
- Houdt raspi-firmware (nodig!)
- Geen changes

## Wat is er veranderd?

### install.sh - install_system_basics()

**Voor upgrade wordt nu gecheckt:**
1. Is dit x86 of ARM?
2. Is raspi-firmware geïnstalleerd?
3. Zo ja (op x86) → verwijder
4. Dan pas upgrade

### Log output:

**Op x86 (N100, Intel, AMD):**
```
[2025-01-03 11:15:00] Detected raspi-firmware on x86 system (incompatible)
[2025-01-03 11:15:00] Removing raspi-firmware to prevent upgrade errors...
[2025-01-03 11:15:05] Upgrading system packages...
```

**Op ARM (Raspberry Pi):**
```
[2025-01-03 11:15:00] ARM architecture detected (armv7l), keeping platform-specific packages
[2025-01-03 11:15:00] Upgrading system packages...
```

## Voor bestaande installaties

Als je al de error hebt gehad:

```bash
# Fix broken package state
sudo apt --fix-broken install

# Verwijder raspi-firmware (alleen op x86!)
sudo apt remove --purge raspi-firmware

# Probeer upgrade opnieuw
sudo apt update
sudo apt upgrade
```

## Architecturen Gedetecteerd

- **x86_64** - 64-bit Intel/AMD (N100, i5, i7, Ryzen, etc.)
- **i686** - 32-bit Intel/AMD (oudere systemen)
- **armv7l** - 32-bit ARM (Raspberry Pi 2/3)
- **aarch64** - 64-bit ARM (Raspberry Pi 4/5)

## Installatie

```bash
cd ~/LinuxCNC
git checkout feature-installer
unzip LinuxCNC-installer-v1.0.8.zip
chmod +x installer/*.sh installer/modules/*.sh

git add installer/
git commit -m "Update to v1.0.8 - Fix apt upgrade raspi-firmware error

- Remove incompatible raspi-firmware on x86 systems
- Preserve raspi-firmware on ARM (Raspberry Pi)
- Prevent initramfs-tools configuration errors
- Architecture detection before cleanup"

git push origin feature-installer
```

## Versie Geschiedenis

- **v1.0.8** - Fix raspi-firmware upgrade error (x86 only)
- **v1.0.7** - Auto-verify EtherCAT permissions
- **v1.0.6** - Add system package upgrade
- **v1.0.5** - BIOS recommendations visibility
- **v1.0.4** - Fix EtherCAT permissions overwrite
- **v1.0.3** - Fix unbound variable error
- **v1.0.2** - Fix bootstrap git conflict
- **v1.0.1** - Fix /home/root sudo bug
- **v1.0.0** - Initial release

Bedankt voor het testen op N100! Deze error was anders niet gevonden. 👍
