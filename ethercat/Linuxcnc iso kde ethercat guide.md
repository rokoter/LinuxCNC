# LinuxCNC ISO + KDE Plasma + EtherCAT

Complete handleiding voor het installeren van KDE Plasma op de officiële LinuxCNC ISO en het toevoegen van EtherCAT ondersteuning.

## Inhoudsopgave

- [Waarom deze aanpak?](#waarom-deze-aanpak)
- [Vereisten](#vereisten)
- [Stap 1: LinuxCNC ISO Installeren](#stap-1-linuxcnc-iso-installeren)
- [Stap 2: Systeem Updaten](#stap-2-systeem-updaten)
- [Stap 3: KDE Plasma Installeren](#stap-3-kde-plasma-installeren)
- [Stap 4: EtherCAT Master Installeren](#stap-4-ethercat-master-installeren)
- [Stap 5: LinuxCNC EtherCAT Component](#stap-5-linuxcnc-ethercat-component)
- [Stap 6: Motor Configuratie](#stap-6-motor-configuratie)
- [Troubleshooting](#troubleshooting)
- [Bronnen](#bronnen)

## Waarom deze aanpak?

Deze methode combineert het beste van beide werelden:

✅ **Stabiele basis**: LinuxCNC ISO met pre-configured RT-kernel  
✅ **Geen compatibility issues**: Bewezen werkende versies van alle dependencies  
✅ **Development comfort**: KDE Plasma voor moderne development ervaring  
✅ **Tijdsbesparing**: Geen uren troubleshooting van kernel compilatie  
✅ **Production ready**: Direct bruikbaar voor echte machines  

**Vergeleken met Fedora 43 from scratch:**
- ❌ Fedora 43: Tcl 9.0 incompatibiliteit met LinuxCNC
- ❌ Fedora 43: RT-kernel handmatig compileren (1+ uur)
- ✅ LinuxCNC ISO: Alles werkt out-of-the-box

## Vereisten

### Hardware
- Computer met minimaal 2GB RAM (4GB+ aanbevolen)
- 20GB vrije schijfruimte
- Dedicated Ethernet NIC voor EtherCAT
- USB stick (4GB+) voor installatie

### Downloads
- [LinuxCNC 2.9 ISO](http://linuxcnc.org/downloads/) (~2.8 GB)
- Tool om bootable USB te maken (Etcher, Rufus, dd)

## Stap 1: LinuxCNC ISO Installeren

### 1.1 Download de ISO

Ga naar [linuxcnc.org/downloads](http://linuxcnc.org/downloads/) en download:
- **LinuxCNC 2.9** (Debian 12 Bookworm met PREEMPT_RT kernel)

### 1.2 Maak Bootable USB

**Op Linux:**
```bash
# Vind je USB device
lsblk

# Schrijf ISO naar USB (vervang sdX met jouw USB device!)
sudo dd if=linuxcnc-2.9.x-amd64.iso of=/dev/sdX bs=4M status=progress
sync
```

**Op Windows:**
- Gebruik [Rufus](https://rufus.ie/) of [Etcher](https://etcher.balena.io/)

### 1.3 Installeer LinuxCNC

1. Boot van USB stick
2. Selecteer "Install LinuxCNC"
3. Volg de installatie wizard:
   - Taal: Nederlands (of Engels)
   - Locatie: Netherlands
   - Toetsenbord: Netherlands
   - Gebruikersnaam: bijv. `linuxcnc`
   - Hostname: bijv. `linuxcnc-machine`
4. Partitionering: Gebruik hele schijf (of handmatig indien gewenst)
5. Wacht tot installatie compleet is
6. Reboot

### 1.4 Eerste login

Na reboot log je in met de gebruiker die je hebt aangemaakt. Je ziet nu een XFCE desktop omgeving.

## Stap 2: Systeem Updaten

Open een terminal en update het systeem:

```bash
# Update package lists
sudo apt update

# Upgrade installed packages
sudo apt upgrade -y

# Reboot if kernel was updated
sudo reboot
```

**Verifieer de RT-kernel:**

```bash
uname -r
# Output moet eindigen op -rt, bijvoorbeeld: 6.1.0-rt7-amd64
```

## Stap 3: KDE Plasma Installeren

### 3.1 Installeer KDE Plasma

Je hebt drie opties, kies één:

**Optie A: Minimale KDE installatie (aanbevolen voor LinuxCNC)**
```bash
sudo apt install kde-plasma-desktop
```

**Optie B: Standaard KDE installatie**
```bash
sudo apt install kde-standard
```

**Optie C: Volledige KDE installatie (alle applicaties)**
```bash
sudo apt install kde-full
```

Tijdens de installatie:
- Wordt gevraagd welke **display manager** je wilt gebruiken
- Selecteer: **sddm** (de KDE display manager)
- Gebruik de pijltjestoetsen om te navigeren en Enter om te selecteren

### 3.2 Installeer aanvullende KDE tools (optioneel)

```bash
# Development tools
sudo apt install kate konsole dolphin

# System monitoring
sudo apt install ksysguard

# KDE Configuratie
sudo apt install systemsettings5
```

### 3.3 Reboot naar KDE

```bash
sudo reboot
```

Na reboot:
1. Bij het login scherm (SDDM), klik op het **tandwiel-icoontje** rechtsonder
2. Selecteer **"Plasma (X11)"** (aanbevolen) of **"Plasma (Wayland)"**
3. Log in met je gebruikersnaam en wachtwoord

Je hebt nu een volledige KDE Plasma desktop! 🎉

### 3.4 KDE aanpassen (optioneel)

KDE is zeer configureerbaar. Enkele tips:

```bash
# Open systeem instellingen
systemsettings5

# Of via menu: System Settings
```

Aanbevolen instellingen:
- **Appearance** → Kies je favoriete thema
- **Workspace Behavior** → Configureer shortcuts
- **Display and Monitor** → Stel resolutie in

## Stap 4: EtherCAT Master Installeren

Nu gaan we EtherCAT ondersteuning toevoegen.

### 4.1 Installeer build dependencies

```bash
sudo apt install -y \
    git \
    build-essential \
    autoconf \
    automake \
    libtool \
    linux-headers-$(uname -r)
```

### 4.2 Clone en compileer IgH EtherCAT Master

```bash
# Maak development directory
mkdir -p ~/linuxcnc-dev
cd ~/linuxcnc-dev

# Clone EtherCAT repository
git clone https://gitlab.com/etherlab.org/ethercat.git
cd ethercat

# Bootstrap
./bootstrap

# Configureer
# Let op: gebruik generic driver voor maximale compatibiliteit
./configure \
    --prefix=/opt/etherlab \
    --with-linux-dir=/usr/src/linux-headers-$(uname -r) \
    --enable-generic \
    --disable-8139too \
    --disable-e100 \
    --disable-e1000 \
    --disable-e1000e \
    --disable-r8169

# Compileer (5-10 minuten)
make -j$(nproc)

# Installeer
sudo make install
sudo depmod -a
```

### 4.3 Configureer EtherCAT Master

**Bepaal je Ethernet interface:**

```bash
ip link show
```

Zoek je bedrade Ethernet interface en noteer:
- **Interface naam** (bijv. `enp0s31f6`, `eth0`, `eno1`)
- **MAC adres** (bijv. `e8:6a:64:89:3d:f7`)

**Bewerk de configuratie:**

```bash
# Bewerk EtherCAT configuratie
sudo nano /opt/etherlab/etc/ethercat.conf
```

Zoek en wijzig de volgende regels:

```bash
# Interface MAC adres (vervang met jouw MAC!)
MASTER0_DEVICE="e8:6a:64:89:3d:f7"

# Driver module
DEVICE_MODULES="generic"

# Interface om automatisch up/down te brengen
UPDOWN_INTERFACES="enp0s31f6"  # Vervang met jouw interface naam!
```

Opslaan: `Ctrl+O`, Enter, `Ctrl+X`

**Of automatisch met sed:**

```bash
# Pas deze variabelen aan!
MAC_ADDRESS="e8:6a:64:89:3d:f7"     # Jouw MAC adres
INTERFACE="enp0s31f6"                # Jouw interface naam

# Pas configuratie aan
sudo sed -i "s/^MASTER0_DEVICE=\"\"$/MASTER0_DEVICE=\"$MAC_ADDRESS\"/" /opt/etherlab/etc/ethercat.conf
sudo sed -i 's/^DEVICE_MODULES=""$/DEVICE_MODULES="generic"/' /opt/etherlab/etc/ethercat.conf
sudo sed -i "s/^UPDOWN_INTERFACES=\"\"$/UPDOWN_INTERFACES=\"$INTERFACE\"/" /opt/etherlab/etc/ethercat.conf
```

### 4.4 Installeer systemd service

```bash
# Maak systemd service
sudo tee /etc/systemd/system/ethercat.service << EOF
[Unit]
Description=EtherCAT Master
After=network.target

[Service]
Type=forking
ExecStart=/opt/etherlab/sbin/ethercatctl start
ExecStop=/opt/etherlab/sbin/ethercatctl stop
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd
sudo systemctl daemon-reload

# Enable en start service
sudo systemctl enable ethercat
sudo systemctl start ethercat

# Check status
sudo systemctl status ethercat
```

**Verwachte output:**
```
● ethercat.service - EtherCAT Master
     Active: active (exited) since ...
```

### 4.5 Voeg omgevingsvariabelen toe

```bash
# Voeg toe aan bashrc
tee -a ~/.bashrc << 'EOF'

# EtherCAT environment
export PATH=/opt/etherlab/bin:/opt/etherlab/sbin:$PATH
export LD_LIBRARY_PATH=/opt/etherlab/lib:$LD_LIBRARY_PATH
EOF

# Reload bashrc
source ~/.bashrc
```

### 4.6 Test EtherCAT Master

```bash
# Check EtherCAT master status
sudo ethercat master

# Verwachte output:
# Master0
#   Phase: Idle
#   Active: no
#   Slaves: 0

# Met motor aangesloten en ingeschakeld:
sudo ethercat slaves

# Dit zou je motor moeten tonen, bijvoorbeeld:
# 0  0:0  PREOP  +  IHSV-EC Integrated Servo
```

## Stap 5: LinuxCNC EtherCAT Component

Installeer de LinuxCNC EtherCAT (lcec) HAL component.

### 5.1 Installeer dependencies

```bash
sudo apt install -y libxml2-dev
```

### 5.2 Clone en compileer lcec

```bash
cd ~/linuxcnc-dev

# Clone repository
git clone https://github.com/linuxcnc-ethercat/linuxcnc-ethercat.git
cd linuxcnc-ethercat

# Configureer
./configure \
    --with-linuxcnc=/usr \
    --with-ethercat=/opt/etherlab

# Compileer
make -j$(nproc)

# Installeer
sudo make install

# Verifieer installatie
ls -la /usr/lib/linuxcnc/modules/lcec*
```

## Stap 6: Motor Configuratie

### 6.1 Verzamel motor informatie

Met je IHSV57-30-14-36-EC motor aangesloten en ingeschakeld:

```bash
# Scan voor EtherCAT slaves
sudo ethercat slaves -v

# Noteer:
# - Vendor ID
# - Product Code
# - Revision Number
```

### 6.2 Maak LinuxCNC configuratie

**Start LinuxCNC configuratie wizard:**

```bash
# Start de configuratie wizard
stepconf
```

Of voor gevorderde gebruikers:

```bash
# Handmatig configuratie aanmaken
mkdir -p ~/linuxcnc/configs/ethercat-test
cd ~/linuxcnc/configs/ethercat-test
```

### 6.3 EtherCAT XML configuratie

Maak een basis EtherCAT configuratie bestand:

```bash
nano ~/linuxcnc/configs/ethercat-test/ethercat-conf.xml
```

Basis template:

```xml
<?xml version="1.0" encoding="utf-8"?>
<masters>
  <master idx="0" appTimePeriod="1000000" refClockSyncCycles="1">
    <slave idx="0" type="generic" vid="00000000" pid="00000000" configPdos="true">
      <dcConf assignActivate="300" sync0Cycle="*1" sync0Shift="0"/>
    </slave>
  </master>
</masters>
```

**Vervang `vid` en `pid` met de waarden van je motor!**

### 6.4 HAL configuratie basis

Voorbeeld HAL configuratie (`custom.hal`):

```hal
# Load EtherCAT components
loadrt lcec
loadrt cia402 count=1

# Add to servo thread
addf lcec.read-all servo-thread
addf cia402.0.read-all servo-thread
addf motion-command-handler servo-thread
addf motion-controller servo-thread
addf cia402.0.write-all servo-thread
addf lcec.write-all servo-thread

# Configure servo parameters
setp cia402.0.csp-mode 1
setp cia402.0.pos-scale 10000

# Connect signals
net x-pos-cmd axis.0.motor-pos-cmd => cia402.0.pos-cmd
net x-pos-fb cia402.0.pos-fb => axis.0.motor-pos-fb
net x-enable axis.0.amp-enable-out => cia402.0.enable

# EtherCAT to CiA402 connections
net ec-servo-status lcec.0.0.cia-state => cia402.0.status-word
net ec-servo-control cia402.0.control-word => lcec.0.0.cia-controlword
net ec-servo-pos-cmd cia402.0.position-cmd => lcec.0.0.cia-position-cmd
net ec-servo-pos-fb lcec.0.0.cia-position-fb => cia402.0.position-fb
```

**Belangrijk:** Dit is een basis voorbeeld. De exacte configuratie hangt af van je motor en machine setup.

### 6.5 Test de configuratie

```bash
# Start LinuxCNC met je configuratie
linuxcnc ~/linuxcnc/configs/ethercat-test/ethercat-test.ini
```

**Veiligheidscheck:**
- Motor moet vrij kunnen draaien (niet belast)
- Noodstop binnen handbereik
- Begin met lage snelheden

## Troubleshooting

### EtherCAT service start niet

```bash
# Check logs
sudo journalctl -u ethercat.service -n 50

# Check configuratie
cat /opt/etherlab/etc/ethercat.conf

# Test handmatig
sudo /opt/etherlab/sbin/ethercatctl start
```

### Geen slaves gevonden

```bash
# Check of motor stroom heeft
# Check Ethernet kabel (CAT5e of hoger)
# Check interface status
ip link show

# Check EtherCAT master
sudo ethercat master
sudo ethercat slaves
```

### LinuxCNC start niet

```bash
# Check LinuxCNC logs
cat ~/linuxcnc_debug.txt
cat ~/linuxcnc_print.txt

# Test HAL configuratie
halrun -I -f ~/linuxcnc/configs/ethercat-test/custom.hal
```

### KDE issues

**SDDM start niet:**
```bash
# Check display manager
sudo systemctl status sddm

# Herstart display manager
sudo systemctl restart sddm

# Of switch terug naar lightdm
sudo dpkg-reconfigure sddm
```

**Wil terug naar XFCE:**
```bash
# Bij login scherm, selecteer "Xfce Session" in het tandwiel menu
```

**KDE volledig verwijderen:**
```bash
sudo apt remove kde-plasma-desktop kde-standard kde-full
sudo apt autoremove
sudo dpkg-reconfigure lightdm
```

## Tips en Best Practices

### Development Workflow

1. **IDE in KDE**: Installeer je favoriete IDE
   ```bash
   sudo apt install qtcreator  # Voor Qt/C++ development
   sudo apt install code       # Visual Studio Code
   ```

2. **Terminal**: Gebruik Konsole (KDE's terminal)
   ```bash
   konsole &
   ```

3. **File Management**: Dolphin file manager is krachtig
   ```bash
   dolphin &
   ```

### EtherCAT Best Practices

1. **Dedicated NIC**: Gebruik een aparte NIC voor EtherCAT
2. **Kabel kwaliteit**: Gebruik CAT5e of hoger
3. **Latency testing**: Test altijd latency voor productie
   ```bash
   latency-test
   ```

### LinuxCNC Development

1. **Config backup**: Backup je configuraties regelmatig
   ```bash
   tar -czf ~/linuxcnc-config-backup-$(date +%Y%m%d).tar.gz ~/linuxcnc/configs/
   ```

2. **Test mode**: Test altijd zonder belasting eerst
3. **Log everything**: Enable debug logging tijdens development

## Geavanceerde Configuratie

### CPU Isolation (optioneel)

Voor betere real-time performance:

```bash
# Edit GRUB configuratie
sudo nano /etc/default/grub

# Voeg toe aan GRUB_CMDLINE_LINUX:
# isolcpus=2,3 nohz_full=2,3 rcu_nocbs=2,3

# Update GRUB
sudo update-grub
sudo reboot
```

### Network Interface Optimalisatie

```bash
# Disable power management
sudo ethtool -s enp0s31f6 wol d

# Increase ring buffers
sudo ethtool -G enp0s31f6 rx 4096 tx 4096

# Disable offloading (voor EtherCAT)
sudo ethtool -K enp0s31f6 gro off tso off gso off
```

## Voordelen van deze Setup

✅ **Stabiel**: Bewezen LinuxCNC basis  
✅ **Modern**: KDE Plasma desktop  
✅ **Productie-ready**: Direct bruikbaar  
✅ **Development-friendly**: Alle tools beschikbaar  
✅ **Community support**: Grote LinuxCNC community  
✅ **Lange termijn support**: Debian 12 basis  

## Bronnen

### Officiële Documentatie
- [LinuxCNC Documentation](https://linuxcnc.org/docs/html/)
- [LinuxCNC Downloads](http://linuxcnc.org/downloads/)
- [IgH EtherCAT Master](https://etherlab.org/en/ethercat/)
- [LinuxCNC EtherCAT (lcec)](https://github.com/linuxcnc-ethercat/linuxcnc-ethercat)

### Community
- [LinuxCNC Forum](https://forum.linuxcnc.org/)
- [LinuxCNC Wiki](https://wiki.linuxcnc.org/)

### KDE
- [KDE Plasma Desktop](https://kde.org/plasma-desktop/)
- [KDE UserBase](https://userbase.kde.org/)

## Conclusie

Deze aanpak geeft je het beste van beide werelden:
- Een stabiele, geteste LinuxCNC basis
- Een moderne, comfortabele development omgeving
- EtherCAT ondersteuning voor professionele servo aansturing

Je bespaart uren troubleshooting vergeleken met een from-scratch installatie op Fedora 43, en je hebt een productie-ready systeem.

**Volgende stappen:**
1. Installeer LinuxCNC ISO
2. Voeg KDE Plasma toe
3. Installeer EtherCAT support
4. Configureer je machine
5. Start met testen!

---

**Laatst bijgewerkt:** December 2025  
**Versie:** 1.0  
**Getest op:** LinuxCNC 2.9 (Debian 12 Bookworm) met KDE Plasma 5.27  

## Disclaimer

Deze handleiding is bedoeld als educatieve resource. De auteur is niet verantwoordelijk voor schade aan hardware of letsel als gevolg van het volgen van deze instructies. Werk altijd veilig met machines en elektronica.