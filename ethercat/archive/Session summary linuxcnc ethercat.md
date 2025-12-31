# LinuxCNC + EtherCAT Development - Sessie Samenvatting

Samenvatting van het ontwikkeltraject voor LinuxCNC met EtherCAT ondersteuning voor servo motor aansturing.

**Datum:** 29 December 2025  
**Doel:** LinuxCNC configuratie opzetten voor IHSV57-30-14-36-EC servo motor via EtherCAT

---

## Inhoudsopgave

- [Hardware Configuratie](#hardware-configuratie)
- [Gekozen Aanpak](#gekozen-aanpak)
- [Fedora 43 Ervaring (Blocker)](#fedora-43-ervaring-blocker)
- [Aanbevolen Oplossing](#aanbevolen-oplossing)
- [Wat is Bereikt](#wat-is-bereikt)
- [Volgende Stappen](#volgende-stappen)
- [Belangrijke Bestanden](#belangrijke-bestanden)
- [Nuttige Commando's](#nuttige-commandos)
- [Lessons Learned](#lessons-learned)

---

## Hardware Configuratie

### Computer
- **Laptop/Desktop**: Fedora 43 KDE (originele setup)
- **Ethernet NIC**: 
  - Interface: `enp0s31f6`
  - MAC adres: `e8:6a:64:89:3d:f7`
  - Type: Bedrade Ethernet (geen WiFi voor EtherCAT!)

### Servo Motor
- **Model**: IHSV57-30-14-36-EC
- **Type**: Geïntegreerde servo motor met ingebouwde driver
- **Specificaties**:
  - Vermogen: 140W
  - Voltage: 36V
  - Max snelheid: 3000 rpm
- **Communicatie**: EtherCAT (step/direction signalen)
- **Documentatie**: IHSV-EC使用手册V1_42-英文版.pdf (uploaded)

### Gebruiksscenario
- Motor draait "in de lucht" (geen belasting) voor development/testing
- Doel: Configureren als X of Y as
- Veilig testen zonder mechanische belasting

---

## Gekozen Aanpak

### Oorspronkelijk Plan: Fedora 43 KDE from scratch

**Motivatie:**
- Voorkeur voor KDE desktop omgeving tijdens development
- Moderne Fedora 43 als basis
- Real-time kernel voor deterministische timing
- EtherCAT voor professionele servo aansturing

**Benodigde componenten:**
1. RT-kernel (PREEMPT_RT)
2. IgH EtherCAT Master
3. LinuxCNC met EtherCAT ondersteuning
4. lcec (LinuxCNC EtherCAT HAL component)

---

## Fedora 43 Ervaring (Blocker)

### Wat Werkte ✅

#### 1. RT-Kernel Compilatie
- **Kernel versie**: 6.16.0-rt3
- **Status**: ✅ Succesvol gecompileerd en draait
- **Verificatie**: `uname -r` toont `6.16.0-rt3`
- **Secure Boot**: Uitgeschakeld (vereist voor zelfgecompileerde kernels)

**Belangrijke stappen:**
```bash
# Kernel sources
cd ~/linuxcnc-dev/linux-6.16

# RT patch toegepast
xzcat ../patch-6.16-rt3.patch.xz | patch -p1

# Menuconfig: Fully Preemptible Kernel (Real-Time) geselecteerd
make menuconfig

# Compilatie succesvol
make -j$(nproc)
sudo make modules_install
sudo make install
```

#### 2. EtherCAT Master (IgH)
- **Status**: ✅ Succesvol geïnstalleerd en draait
- **Locatie**: `/opt/etherlab`
- **Driver**: Generic (universeel compatibel)
- **Systemd service**: Active en enabled

**Configuratie:**
- Config file: `/opt/etherlab/etc/ethercat.conf`
- MAC adres: `e8:6a:64:89:3d:f7`
- Interface: `enp0s31f6`
- Device modules: `generic`

**Verificatie:**
```bash
sudo systemctl status ethercat
# Status: active (exited) ✅

sudo ethercat master
# Master0 detected ✅
```

#### 3. Dependencies
Alle benodigde packages geïnstalleerd:
- Development tools
- Kernel headers
- Python dependencies
- Tcl/Tk (8.6, maar dit werd een probleem - zie hieronder)
- Boost libraries
- EtherCAT build dependencies

### Wat NIET Werkte ❌

#### LinuxCNC Compilatie - Tcl 9.0 Incompatibiliteit

**Blocker**: Fedora 43 heeft Tcl 9.0, maar LinuxCNC is geschreven voor Tcl 8.x

**Error:**
```
emc/usr_intf/emcsh.cc: error: expected ',' or '...' before 'objv'
emc/usr_intf/emcsh.cc: error: 'objv' was not declared in this scope
emc/usr_intf/emcsh.cc: error: invalid conversion from 'int (*)(ClientData, Tcl_Interp*, int, Tcl_Obj*)'
```

**Oorzaak:**
- Tcl 9.0 heeft API breaking changes
- `CONST` keyword is veranderd
- Function signatures zijn gewijzigd
- LinuxCNC master branch heeft nog geen volledige Tcl 9.0 ondersteuning

**Waarom dit een showstopper is:**
- Kan niet worden omzeild zonder LinuxCNC source code aanpassingen
- Downgrade naar Tcl 8.6 op Fedora 43 is complex en breekt andere packages
- Wachten op LinuxCNC Tcl 9.0 ondersteuning kan maanden duren

### Andere Issues (Opgelost)

1. **`dnf groupinstall` werkt niet**: Fedora 43 gebruikt dnf5 → Opgelost met `@development-tools`
2. **RT-kernel packages niet beschikbaar**: Handmatig gecompileerd → Succesvol
3. **yapps2 ontbreekt**: Geïnstalleerd via pip → Succesvol
4. **libtirpc ontbreekt**: `sudo dnf install libtirpc-devel` → Succesvol
5. **libusb-1.0 ontbreekt**: `sudo dnf install libusb1-devel` → Succesvol
6. **TclX niet gevonden**: `--disable-check-runtime-deps` gebruikt → Succesvol
7. **asciidoc ontbreekt**: `sudo dnf install asciidoc` → Succesvol

---

## Aanbevolen Oplossing

### LinuxCNC ISO + KDE Plasma

**Beste aanpak voor dit project:**

1. **Download LinuxCNC 2.9 ISO** (Debian 12 Bookworm basis)
   - URL: http://linuxcnc.org/downloads/
   - Bevat: Pre-configured RT-kernel, LinuxCNC, alle dependencies

2. **Installeer LinuxCNC ISO**
   - Komt met XFCE desktop (basis)
   - RT-kernel werkt out-of-the-box
   - Alle dependencies correct geconfigureerd

3. **Installeer KDE Plasma erop**
   ```bash
   sudo apt install kde-plasma-desktop
   ```
   - Kies SDDM als display manager
   - Selecteer Plasma (X11) bij login
   - Behoud alle LinuxCNC functionaliteit

4. **Voeg EtherCAT toe**
   - Gebruik dezelfde stappen als op Fedora 43
   - IgH EtherCAT Master compileren
   - lcec (LinuxCNC EtherCAT component) installeren

**Voordelen:**
✅ Geen Tcl 9.0 problemen  
✅ RT-kernel werkt direct  
✅ Bewezen stabiele combinatie  
✅ KDE development comfort  
✅ Productie-ready  
✅ Bespaart uren troubleshooting  

---

## Wat is Bereikt

### Fedora 43 Setup (95% compleet, maar geblokkeerd)

✅ **RT-Kernel**: 6.16.0-rt3 draait perfect  
✅ **EtherCAT Master**: Geïnstalleerd en actief  
✅ **Development omgeving**: KDE Plasma volledig geconfigureerd  
✅ **Network configuratie**: Ethernet interface correct ingesteld  
✅ **Dependencies**: Alle packages geïnstalleerd  
❌ **LinuxCNC**: Kan niet compileren door Tcl 9.0  

### Documentatie Gemaakt

1. **linuxcnc-ethercat-fedora43-guide.md**
   - Complete guide voor Fedora 43 from scratch
   - RT-kernel compilatie
   - EtherCAT Master installatie
   - LinuxCNC compilatie (tot de Tcl blocker)
   - Troubleshooting sectie

2. **download-rt-kernel.sh**
   - Script om automatisch nieuwste RT-kernel te downloaden
   - Colored output met status updates
   - Resume ondersteuning
   - Helper script generator

3. **linuxcnc-iso-kde-ethercat-guide.md** ⭐ AANBEVOLEN
   - Complete guide voor LinuxCNC ISO + KDE aanpak
   - Stapsgewijze KDE installatie
   - EtherCAT integratie
   - Motor configuratie
   - Best practices

4. **Dit document**
   - Sessie samenvatting
   - Context voor nieuwe chats
   - Quick reference

---

## Volgende Stappen

### Aanbevolen Pad (LinuxCNC ISO + KDE)

1. **Download en Installeer**
   ```bash
   # Download LinuxCNC 2.9 ISO
   # Maak bootable USB
   # Installeer op target machine
   ```

2. **Update Systeem**
   ```bash
   sudo apt update
   sudo apt upgrade
   ```

3. **Installeer KDE**
   ```bash
   sudo apt install kde-plasma-desktop
   # Selecteer SDDM
   sudo reboot
   ```

4. **Installeer EtherCAT Master**
   ```bash
   cd ~/linuxcnc-dev
   git clone https://gitlab.com/etherlab.org/ethercat.git
   cd ethercat
   ./bootstrap
   ./configure --prefix=/opt/etherlab \
       --with-linux-dir=/usr/src/linux-headers-$(uname -r) \
       --enable-generic
   make -j$(nproc)
   sudo make install
   ```

5. **Configureer EtherCAT**
   - Edit `/opt/etherlab/etc/ethercat.conf`
   - Stel MAC adres in: `e8:6a:64:89:3d:f7`
   - Stel interface in: `enp0s31f6` (of equivalente naam op nieuwe systeem)

6. **Installeer lcec**
   ```bash
   cd ~/linuxcnc-dev
   git clone https://github.com/linuxcnc-ethercat/linuxcnc-ethercat.git
   cd linuxcnc-ethercat
   ./configure --with-linuxcnc=/usr --with-ethercat=/opt/etherlab
   make -j$(nproc)
   sudo make install
   ```

7. **Configureer Motor**
   - Scan motor: `sudo ethercat slaves -v`
   - Noteer Vendor ID en Product Code
   - Maak EtherCAT XML configuratie
   - Schrijf HAL bestand voor X-as

8. **Test Setup**
   - Start LinuxCNC
   - Test jog bewegingen
   - Verifieer feedback
   - Tune PID parameters

### Alternatief Pad (Blijf op Fedora 43)

**Alleen als je echt Fedora 43 wilt behouden:**

1. **Wacht op LinuxCNC Updates**
   - Monitor LinuxCNC GitHub voor Tcl 9.0 support
   - Of: Draag bij aan de fix (als je C++ developer bent)

2. **Gebruik VM**
   - Fedora 40 in VM (heeft Tcl 8.6)
   - Pass-through Ethernet NIC voor EtherCAT

3. **Container Oplossing**
   - Docker/Podman met Debian 12
   - Complex voor real-time en hardware access

**Niet aanbevolen** - te veel overhead en complexiteit

---

## Belangrijke Bestanden

### Op Fedora 43 Systeem

```
~/linuxcnc-dev/
├── linux-6.16/                    # RT-kernel source (compiled)
├── ethercat/                      # EtherCAT Master source (compiled)
└── download-rt-kernel.sh          # RT-kernel download script

/opt/etherlab/                     # EtherCAT Master installatie
├── bin/ethercat                   # EtherCAT command line tool
├── sbin/ethercatctl               # EtherCAT control script
├── etc/ethercat.conf              # EtherCAT configuratie
└── lib/                           # EtherCAT libraries

/lib/modules/6.16.0-rt3/
├── build -> ~/linuxcnc-dev/linux-6.16
└── ethercat/                      # EtherCAT kernel modules
```

### Documentatie Bestanden

- `linuxcnc-ethercat-fedora43-guide.md` - Fedora 43 guide (voor referentie)
- `linuxcnc-iso-kde-ethercat-guide.md` - ⭐ Aanbevolen nieuwe aanpak
- `download-rt-kernel.sh` - RT-kernel download helper
- `IHSV-EC使用手册V1_42-英文版.pdf` - Motor handleiding

---

## Nuttige Commando's

### Systeem Informatie
```bash
# Check kernel versie
uname -r

# Check RT capabilities
cat /proc/version | grep PREEMPT
cat /sys/kernel/realtime  # 1 = RT kernel

# Check CPU info
lscpu
```

### EtherCAT Commando's
```bash
# EtherCAT master status
sudo ethercat master

# Scan voor slaves
sudo ethercat slaves
sudo ethercat slaves -v  # Verbose met alle info

# SDO lezen (Service Data Object)
sudo ethercat upload -p 0 -t uint32 0x1000 0

# EtherCAT service beheren
sudo systemctl status ethercat
sudo systemctl start ethercat
sudo systemctl stop ethercat
sudo systemctl restart ethercat

# Logs bekijken
sudo journalctl -u ethercat.service -n 50
```

### Network Commando's
```bash
# List network interfaces
ip link show
ip addr show

# Interface details
ethtool enp0s31f6

# Bring interface up/down
sudo ip link set enp0s31f6 up
sudo ip link set enp0s31f6 down
```

### LinuxCNC Commando's
```bash
# Start LinuxCNC
linuxcnc

# Start met specifieke config
linuxcnc ~/linuxcnc/configs/my-config/my-config.ini

# HAL test (zonder GUI)
halrun -I -f custom.hal

# Latency test
latency-test

# Check LinuxCNC versie
linuxcnc --version
```

### Development Commando's
```bash
# Find files
find /path -name "*.ko"  # Kernel modules
find /path -name "ethercat*"

# Check process
ps aux | grep ethercat
ps aux | grep linuxcnc

# Monitor logs
tail -f /var/log/syslog
dmesg | grep -i ethercat

# Check module loading
lsmod | grep ec_
modinfo ec_master
```

---

## Lessons Learned

### Technische Lessen

1. **Bleeding Edge ≠ Beste Keuze voor CNC**
   - Fedora 43 is te nieuw voor LinuxCNC
   - Stabiele, oudere versies zijn betrouwbaarder
   - "If it ain't broke, don't upgrade" geldt hier!

2. **RT-Kernel Vereisten**
   - Secure Boot moet uit voor custom kernels
   - Kernel sources moeten matchen met running kernel
   - Symlinks zijn cruciaal voor module compilatie

3. **EtherCAT Best Practices**
   - Generic driver is universeel maar iets minder performant
   - Dedicated NIC is essentieel (geen WiFi!)
   - CAT5e of beter kabel kwaliteit belangrijk
   - MAC adres configuratie is kritisch

4. **Dependencies Hell**
   - Tcl/Tk versie compatibiliteit is belangrijk
   - Python versies kunnen conflicteren
   - Boost libraries moeten exact matchen

### Proces Lessen

1. **Start met Stabiele Basis**
   - LinuxCNC ISO is bewezen en getest
   - Desktop omgeving kan later toegevoegd worden
   - "Make it work, then make it pretty"

2. **Documenteer Alles**
   - Elke configuratie stap
   - MAC adressen en interface namen
   - Kernel versies en patches
   - Error messages en oplossingen

3. **Test Incrementeel**
   - Eerst RT-kernel alleen
   - Dann EtherCAT Master
   - Dan LinuxCNC
   - Dan motor configuratie

4. **Safety First**
   - Motor zonder belasting testen
   - Noodstop altijd binnen handbereik
   - Lage snelheden bij eerste tests
   - Backup van configuraties

---

## Hardware Specificaties (Voor Referentie)

### IHSV57-30-14-36-EC Motor

**Elektrisch:**
- Voltage: 36V DC
- Stroom: Max 4A
- Vermogen: 140W
- Encoder: Incremental (ingebouwd)

**Mechanisch:**
- Holding Torque: ~0.45 Nm
- Rated Speed: 3000 rpm
- Flange: 57mm (NEMA 23 compatible)

**Communicatie:**
- Protocol: EtherCAT (CoE - CANopen over EtherCAT)
- Profile: CiA 402 (Motion Control)
- PDO: Process Data Objects voor real-time
- SDO: Service Data Objects voor configuratie

**Operatie Modes:**
- CSP: Cyclic Synchronous Position (position control)
- CSV: Cyclic Synchronous Velocity (velocity control)
- CST: Cyclic Synchronous Torque (torque control)

**Voor LinuxCNC:**
- Aanbevolen: CSP mode (position control)
- Position scaling: 10000 encoder counts per revolution (te verifiëren)
- Update rate: 1ms (1kHz)

---

## Belangrijke URLs en Resources

### LinuxCNC
- Website: https://linuxcnc.org/
- Downloads: http://linuxcnc.org/downloads/
- Documentation: https://linuxcnc.org/docs/html/
- Forum: https://forum.linuxcnc.org/
- GitHub: https://github.com/LinuxCNC/linuxcnc
- Wiki: https://wiki.linuxcnc.org/

### EtherCAT
- IgH EtherCAT Master: https://etherlab.org/en/ethercat/
- GitLab: https://gitlab.com/etherlab.org/ethercat
- ETG (EtherCAT Technology Group): https://www.ethercat.org/

### LinuxCNC EtherCAT
- GitHub: https://github.com/linuxcnc-ethercat/linuxcnc-ethercat
- Documentation: In repository docs folder

### RT-Linux
- RT-Linux Patches: https://kernel.org/pub/linux/kernel/projects/rt/
- RT-Linux Wiki: https://wiki.linuxfoundation.org/realtime/start

### KDE Plasma
- Website: https://kde.org/plasma-desktop/
- Documentation: https://userbase.kde.org/

---

## Quick Start Voor Nieuwe Chat

**Als je deze samenvatting leest in een nieuwe chat, geef aan waar je staat:**

1. **"Ik heb LinuxCNC ISO + KDE geïnstalleerd"**
   → Ga verder met EtherCAT configuratie (Stap 4 in iso-guide.md)

2. **"Ik heb EtherCAT werkend"**
   → Ga verder met motor configuratie (Stap 6 in iso-guide.md)

3. **"Ik wil toch Fedora 43 proberen"**
   → Wacht op LinuxCNC Tcl 9.0 support, of gebruik VM met oudere Fedora

4. **"Ik heb een specifieke foutmelding"**
   → Deel de foutmelding en context (welke stap, welke commando)

5. **"Ik wil de HAL configuratie afmaken"**
   → Deel je huidige HAL file en motor specificaties

**Relevante informatie om te delen:**
- Huidige systeem (LinuxCNC ISO / Fedora / andere)
- Kernel versie (`uname -r`)
- EtherCAT status (`sudo ethercat master`)
- Motor status (`sudo ethercat slaves`)
- Specifieke foutmeldingen of logs

---

## Contact en Feedback

Deze documentatie is ontstaan tijdens een ontwikkel sessie op 29 december 2025. 

**Voor vragen of verbeteringen:**
- Open een issue in je GitHub repository
- Post in LinuxCNC forum met verwijzing naar deze guide
- Deel je ervaringen zodat anderen kunnen leren

**Belangrijke opmerking:**
Deze guide is bedoeld als educatieve resource. Test altijd veilig, vooral met echte machines en motoren!

---

**Succes met je LinuxCNC + EtherCAT project! 🚀**

---

## Changelog

**v1.0 - 29 December 2025**
- Initiele versie
- Fedora 43 ervaring gedocumenteerd
- LinuxCNC ISO + KDE aanpak aanbevolen
- Complete hardware en software specificaties
- Troubleshooting tips toegevoegd