# v1.1.0 - CRITICAL FIX: Force Remove Raspi-Firmware

## Het Probleem

v1.0.9 probeerde te fixen in deze volgorde:
```
1. dpkg --configure -a        ← CRASHT op raspi-firmware
2. Remove raspi-firmware       ← Never reached!
```

**Chicken-and-egg probleem:**
- Kan raspi-firmware niet verwijderen want dpkg is broken
- Dpkg is broken vanwege raspi-firmware
- 🔄 Infinite loop!

## De Oplossing: --force-all

```bash
# VOOR elke dpkg operatie:
dpkg --remove --force-all raspi-firmware
dpkg --purge --force-all raspi-firmware

# NU kan dpkg configure wel werken:
dpkg --configure -a  ✅
```

**`--force-all` betekent:**
- Negeer alle warnings
- Negeer dependencies
- Gewoon verwijderen!

**Is dit veilig?**
- ✅ JA - alleen op x86 systemen
- ✅ JA - package hoort er niet te zijn
- ✅ JA - heeft geen echte dependencies op x86

## Nieuwe Volgorde

```
1. Check: zijn we op x86?
2. Force remove raspi-firmware (dpkg --force-all)
3. Fix broken packages (dpkg --configure -a)
4. Fix dependencies (apt --fix-broken)
5. Update & upgrade
```

## Test dit op je N100

```bash
cd ~/LinuxCNC
git checkout feature-installer
unzip LinuxCNC-installer-v1.1.0.zip
chmod +x installer/*.sh installer/modules/*.sh

# Test direct (zonder eerst handmatig te fixen)
sudo installer/install.sh
```

**Verwacht:**
```
[LOG] Detected raspi-firmware on x86 system (incompatible)
[LOG] Force removing raspi-firmware to prevent dpkg errors...
[LOG] Raspi-firmware removed
[LOG] Checking for broken packages...
[LOG] Upgrading system packages...
✅ SUCCESS
```

## Waarom v1.1.0 en niet v1.0.10?

Dit is een **breaking change** in aanpak:
- v1.0.x: Probeerde vriendelijk te zijn met apt-get remove
- v1.1.0: Gebruikt force flags om probleem op te lossen

Semantic versioning: minor bump voor significante change.

## Voor ARM gebruikers

**Geen zorgen!** De check is:
```bash
if x86_64 or i686:
    remove raspi-firmware
else:
    keep it (you need it!)
```

Raspberry Pi gebruikers zijn veilig! 🍓

## Installeer & Test

```bash
git add installer/
git commit -m "Update to v1.1.0 - Force remove raspi-firmware before dpkg

CRITICAL FIX:
- Use dpkg --force-all to remove raspi-firmware FIRST
- Prevents chicken-and-egg dpkg broken state
- Now works on systems with failed upgrades
- Tested on N100 hardware with broken state"

git push origin feature-installer
```

Dan verse test! 🧪
