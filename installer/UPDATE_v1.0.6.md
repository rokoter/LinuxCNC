# LinuxCNC Installer v1.0.6 Update

## Added: System Package Upgrade

### Probleem
Forum guide zegt:
```bash
sudo apt update
sudo apt install linuxcnc-ethercat
```

Maar de installer deed alleen `apt update`, geen `apt upgrade`. Dit kan leiden tot:
- Verouderde packages
- Package conflicts
- Missing dependencies
- ~691 MB aan updates die niet geïnstalleerd werden

### Oplossing v1.0.6

**System package upgrade nu toegevoegd!**

#### Interactive Mode
Gebruiker krijgt een prompt:
```
===================================================================
System Update
===================================================================

It is recommended to upgrade all system packages before installing
LinuxCNC and EtherCAT components.

This may download ~500MB and take 5-10 minutes.

Upgrade system packages now? [Y/n]:
```

- **Default: Yes** (druk Enter = upgrade)
- Kan skippen met 'n' als je snel wilt testen

#### Non-Interactive Mode
Upgrades **automatisch** (tenzij `--no-upgrade` gebruikt wordt)

#### Command-Line Flags
```bash
# Force upgrade (default in non-interactive)
sudo ./install.sh --upgrade

# Skip upgrade (voor snelle tests)
sudo ./install.sh --no-upgrade
```

## Waarom is dit belangrijk?

Van je screenshot zie ik:
```
255 upgraded, 5 newly installed, 0 to remove and 0 not upgraded.
Need to get 691 MB of archives.
```

Dit zijn **691 MB aan updates** die de installer eerst miste!

Updates kunnen bevatten:
- Security fixes
- Bug fixes voor LinuxCNC/EtherCAT
- Kernel updates
- Library updates die dependencies fixen

## Wijzigingen

### installer/install.sh
- Versie 1.0.6
- Added `SKIP_UPGRADE` variable (default: false)
- Added interactive upgrade prompt
- Added `--upgrade` and `--no-upgrade` flags
- Updated help text

### installer/CHANGELOG.md
- v1.0.6 entry

## Installatie

```bash
cd ~/LinuxCNC
git checkout feature-installer
unzip LinuxCNC-installer-v1.0.6.zip
chmod +x installer/*.sh installer/modules/*.sh

git add installer/
git commit -m "Update to v1.0.6 - Add system package upgrade

- Add apt upgrade to follow forum best practice
- Interactive prompt for user confirmation
- Auto-upgrade in non-interactive mode
- Add --upgrade and --no-upgrade flags"

git push origin feature-installer
```

## Gebruik

### Interactive (standaard)
```bash
sudo ./installer/install.sh
# Krijgt prompt, kan Yes/No kiezen
```

### Auto-upgrade
```bash
sudo ./installer/install.sh --machine ihsv-single
# Upgrades automatisch in non-interactive mode
```

### Skip upgrade (snel testen)
```bash
sudo ./installer/install.sh --no-upgrade
# Skipt upgrade, snel maar risico op conflicts
```

## Voor Bestaande Installaties

Als je v1.0.5 of eerder hebt, run handmatig:
```bash
sudo apt update
sudo apt upgrade -y
```

## Timing

- **apt update**: ~5 seconden
- **apt upgrade**: ~5-10 minuten (afhankelijk van download speed)
- **Total install time**: nu ~15-20 minuten in plaats van ~10 minuten

Maar je krijgt een **volledig up-to-date systeem**! 

## Versie Geschiedenis

- **v1.0.6** - Add system package upgrade
- **v1.0.5** - BIOS recommendations visibility
- **v1.0.4** - Fix EtherCAT permissions overwrite
- **v1.0.3** - Fix unbound variable error
- **v1.0.2** - Fix bootstrap git conflict
- **v1.0.1** - Fix /home/root sudo bug, add pre-flight checks
- **v1.0.0** - Initial release
