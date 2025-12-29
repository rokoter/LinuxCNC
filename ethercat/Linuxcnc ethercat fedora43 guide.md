# LinuxCNC met EtherCAT op Fedora 43 KDE

Complete installatiehandleiding voor LinuxCNC met EtherCAT ondersteuning op Fedora 43 KDE, specifiek voor servo motor ontwikkeling (IHSV57-30-14-36-EC).

## Inhoudsopgave

- [Overzicht](#overzicht)
- [Vereisten](#vereisten)
- [Installatie Stappen](#installatie-stappen)
  - [Stap 1: Voorbereiding Fedora 43 KDE](#stap-1-voorbereiding-fedora-43-kde)
  - [Stap 2: RT-kernel Installeren](#stap-2-rt-kernel-installeren)
  - [Stap 3: RT-kernel Tuning](#stap-3-rt-kernel-tuning)
  - [Stap 4: IgH EtherCAT Master](#stap-4-igh-ethercat-master)
  - [Stap 5: LinuxCNC Dependencies](#stap-5-linuxcnc-dependencies)
  - [Stap 6: LinuxCNC Compileren](#stap-6-linuxcnc-compileren)
  - [Stap 7: Omgevingsvariabelen](#stap-7-omgevingsvariabelen)
  - [Stap 8: EtherCAT Testen](#stap-8-ethercat-testen)
  - [Stap 9: LinuxCNC EtherCAT Component](#stap-9-linuxcnc-ethercat-component)
  - [Stap 10: Motor Configuratie](#stap-10-motor-configuratie)
- [Troubleshooting](#troubleshooting)
- [Bronnen](#bronnen)

## Overzicht

Deze handleiding beschrijft het complete proces om LinuxCNC met EtherCAT ondersteuning te installeren op Fedora 43 KDE. Het doel is om geïntegreerde servo motoren (zoals de IHSV57-30-14-36-EC) aan te kunnen sturen via EtherCAT communicatie.

**Update December 2025:** De precompiled RT-kernel packages zijn momenteel niet beschikbaar in Fedora 43 repositories. Deze guide biedt meerdere opties, inclusief het compileren van een RT-kernel of het gebruik van de standaard preemptible kernel voor development.

### Wat wordt geïnstalleerd?

- Real-Time (RT) kernel voor deterministische timing
- IgH EtherCAT Master voor EtherCAT communicatie
- LinuxCNC 2.9 met EtherCAT ondersteuning
- LinuxCNC-EtherCAT (lcec) HAL component

## Vereisten

### Hardware
- Computer met Fedora 43 KDE (laptop of desktop)
- Dedicated Ethernet NIC voor EtherCAT (geen WiFi)
  - Intel NIC sterk aanbevolen voor productie
  - USB 3.0 Ethernet adapter mogelijk voor ontwikkeling
- EtherCAT servo motor (bijv. IHSV57-30-14-36-EC)

### Software
- Fedora 43 KDE (vers geïnstalleerd)
- Internetverbinding voor downloads
- Sudo/root toegang

### Kennis
- Basis Linux command-line kennis
- Basis begrip van real-time systemen (nuttig)

## Installatie Stappen

### Stap 1: Voorbereiding Fedora 43 KDE

Update het systeem en installeer benodigde ontwikkeltools:

```bash
# Systeem updaten
sudo dnf update -y

# Basis ontwikkeltools installeren
# Fedora 43 gebruikt dnf5 met @ syntax voor groepen
sudo dnf install -y @development-tools

# Als @development-tools niet werkt, probeer:
# sudo dnf install -y @c-development

# Benodigde packages installeren
sudo dnf install -y git gcc-c++ make automake autoconf libtool \
    kernel-devel kernel-headers elfutils-libelf-devel \
    python3-devel gtk3-devel mesa-libGL-devel mesa-libGLU-devel \
    readline-devel ncurses-devel libmodbus-devel
```

### Stap 2: RT-kernel Installeren

**Belangrijke Opmerking voor Fedora 43:** De precompiled RT-kernel packages zijn momenteel niet beschikbaar in de standaard Fedora 43 repositories. Er zijn twee opties:

#### Optie A: Wacht op officiële RT-kernel (Aanbevolen voor beginners)

Fedora brengt meestal RT-kernels uit, maar mogelijk met vertraging. Check regelmatig:

```bash
# Check of RT-kernel beschikbaar is
sudo dnf search kernel-rt

# Als beschikbaar, installeer:
sudo dnf install -y kernel-rt kernel-rt-devel kernel-rt-modules kernel-rt-modules-extra
```

#### Optie B: Compileer RT-kernel vanaf source (Gevorderd)

Voor nu kunnen we een RT-kernel compileren vanaf source. Ik heb een script gemaakt dat automatisch de nieuwste versie downloadt:

**Download het helper script:**

```bash
# Maak development directory aan (als die nog niet bestaat)
mkdir -p ~/linuxcnc-dev
cd ~/linuxcnc-dev

# Download het script
wget https://raw.githubusercontent.com/[jouw-repo]/download-rt-kernel.sh
# Of kopieer het handmatig (zie download-rt-kernel.sh in de repo)

chmod +x download-rt-kernel.sh

# Voer het script uit
./download-rt-kernel.sh
```

Het script zal automatisch:
- De nieuwste RT kernel versie vinden
- Kernel source en RT patch downloaden
- Een helper script maken om uit te pakken en te patchen

**Handmatige methode (als je het script niet wilt gebruiken):**

```bash
# Installeer extra build dependencies
sudo dnf install -y rpm-build rpmdevtools ncurses-devel hmaccalc \
    zlib-devel binutils-devel elfutils-libelf-devel openssl-devel \
    perl-devel perl-generators pesign bc dwarves bison flex

# Maak development directory aan (als die nog niet bestaat)
mkdir -p ~/linuxcnc-dev
cd ~/linuxcnc-dev

# Vind de nieuwste versie op: https://kernel.org/pub/linux/kernel/projects/rt/
# Bijvoorbeeld voor 6.12:
KERNEL_VERSION="6.12"
RT_PATCH="6.12-rt11"

wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KERNEL_VERSION}.tar.xz
wget https://cdn.kernel.org/pub/linux/kernel/projects/rt/6.12/patch-${RT_PATCH}.patch.xz

# Uitpakken
tar xf linux-${KERNEL_VERSION}.tar.xz
cd linux-${KERNEL_VERSION}
xzcat ../patch-${RT_PATCH}.patch.xz | patch -p1

# Kopieer huidige kernel config
cp /boot/config-$(uname -r) .config
make olddefconfig

# Enable RT PREEMPT
# Gebruik menuconfig om PREEMPT_RT te selecteren:
# General setup -> Preemption Model -> Fully Preemptible Kernel (RT)
make menuconfig

# Compileer (dit duurt 30-60 minuten)
make -j$(nproc)
sudo make modules_install
sudo make install

# Update GRUB
sudo grub2-mkconfig -o /boot/grub2/grub.cfg

# Reboot
sudo reboot
```

#### Optie C: Gebruik standaard kernel met PREEMPT (Voor Development)

Voor initial development en testing kun je ook de standaard Fedora kernel gebruiken die al `CONFIG_PREEMPT` heeft:

```bash
# Check huidige preemption model
cat /boot/config-$(uname -r) | grep PREEMPT

# Als je CONFIG_PREEMPT=y ziet, heb je al een preemptible kernel
# Dit is goed genoeg voor development en testing
```

De standaard Fedora kernel heeft meestal `CONFIG_PREEMPT=y` wat geschikt is voor development. Voor productie is een echte RT-kernel (`PREEMPT_RT`) beter.

**Verificatie na reboot:**

```bash
# Controleer kernel versie
uname -r

# Check preemption model
cat /proc/version
# Of
grep PREEMPT /boot/config-$(uname -r)
```

### Stap 3: RT-kernel Tuning

Configureer het systeem voor optimale real-time performance:

```bash
# Creëer RT configuratie bestand voor process prioriteiten
sudo tee /etc/security/limits.d/99-rtprio.conf << EOF
@realtime soft rtprio 99
@realtime soft memlock unlimited
@realtime hard rtprio 99
@realtime hard memlock unlimited
EOF

# Maak realtime groep en voeg jezelf toe
sudo groupadd realtime
sudo usermod -a -G realtime $USER

# Kernel parameters voor betere real-time performance
sudo tee /etc/sysctl.d/99-realtime.conf << EOF
# Real-time tuning
kernel.sched_rt_runtime_us = -1
vm.swappiness = 10
EOF

# Laad de nieuwe sysctl settings
sudo sysctl -p /etc/sysctl.d/99-realtime.conf
```

**Belangrijk:** Log uit en weer in (of herstart) zodat de groep wijzigingen actief worden.

### Stap 4: IgH EtherCAT Master

Installeer de IgH EtherCAT Master - de industrie-standaard EtherCAT stack voor Linux:

```bash
# Maak development directory aan
mkdir -p ~/linuxcnc-dev
cd ~/linuxcnc-dev

# Clone IgH EtherCAT repository
git clone https://gitlab.com/etherlab.org/ethercat.git
cd ethercat

# Bootstrap (voor git repository)
./bootstrap

# Maak symlink naar kernel sources (voor zelfgecompileerde RT-kernel)
sudo rm -f /lib/modules/$(uname -r)/build
sudo ln -s ~/linuxcnc-dev/linux-6.16 /lib/modules/$(uname -r)/build

# Configureer voor jouw kernel
# Let op: we gebruiken --enable-generic (werkt met alle NICs)
# en --enable-igb=no omdat de igb driver mogelijk niet beschikbaar is voor alle kernel versies
./configure --prefix=/opt/etherlab \
    --with-linux-dir=/lib/modules/$(uname -r)/build \
    --enable-generic \
    --enable-8139too=no \
    --enable-e100=no \
    --enable-e1000=no \
    --enable-e1000e=no \
    --enable-r8169=no \
    --enable-igb=no

# Compileer (gebruikt alle CPU cores)
make -j$(nproc)

# Installeer
sudo make install
sudo depmod
```

**Belangrijke opmerkingen:**
- De **generic driver** (`--enable-generic`) werkt met vrijwel alle Ethernet NICs
- De symlink naar de kernel sources is nodig voor zelfgecompileerde kernels
- Voor productie kun je later een specifieke driver gebruiken voor betere performance
- Voor development en testing is de generic driver perfect geschikt

#### EtherCAT Master Configureren

```bash
# Bepaal het MAC adres van je Ethernet NIC
ip link show
# Zoek je Ethernet interface en noteer zowel de naam als het MAC adres
# Voorbeeld: enp0s31f6 met MAC e8:6a:64:89:3d:f7

# Bewerk de EtherCAT configuratie file
sudo nano /opt/etherlab/etc/ethercat.conf
```

**In de config file, zoek en wijzig de volgende regels:**

1. `MASTER0_DEVICE=""` → `MASTER0_DEVICE="e8:6a:64:89:3d:f7"` (jouw MAC adres)
2. `DEVICE_MODULES=""` → `DEVICE_MODULES="generic"`
3. `UPDOWN_INTERFACES=""` → `UPDOWN_INTERFACES="enp0s31f6"` (jouw interface naam)

**Of gebruik sed om automatisch te wijzigen:**

```bash
# Pas deze variabelen aan naar jouw situatie!
MAC_ADDRESS="e8:6a:64:89:3d:f7"     # Vervang met jouw MAC adres
INTERFACE="enp0s31f6"                # Vervang met jouw interface naam

# Automatisch aanpassen
sudo sed -i "s/^MASTER0_DEVICE=\"\"$/MASTER0_DEVICE=\"$MAC_ADDRESS\"/" /opt/etherlab/etc/ethercat.conf
sudo sed -i 's/^DEVICE_MODULES=""$/DEVICE_MODULES="generic"/' /opt/etherlab/etc/ethercat.conf
sudo sed -i "s/^UPDOWN_INTERFACES=\"\"$/UPDOWN_INTERFACES=\"$INTERFACE\"/" /opt/etherlab/etc/ethercat.conf

# Verifieer de wijzigingen
grep -E "MASTER0_DEVICE|DEVICE_MODULES|UPDOWN_INTERFACES" /opt/etherlab/etc/ethercat.conf
```

**Belangrijk:** 
- Gebruik het MAC adres van je **bedrade** Ethernet interface (niet WiFi)
- De interface moet een fysieke Ethernet poort zijn voor EtherCAT

#### Systemd Service Installeren

```bash
# Creëer systemd service file (let op: ethercatctl staat in /sbin, niet /bin)
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

# Herlaad systemd en enable service
sudo systemctl daemon-reload
sudo systemctl enable ethercat
sudo systemctl start ethercat

# Check status
sudo systemctl status ethercat
```

**Verwachte output:** `Active: active (exited)` - dit is correct voor een forking service.

### Stap 5: LinuxCNC Dependencies

Installeer alle benodigde dependencies voor LinuxCNC:

```bash
sudo dnf install -y \
    tcl-devel tk-devel bwidget tclx python3-tkinter \
    boost-devel libudev-devel yapps2 intltool \
    python3-lxml python3-configobj desktop-file-utils \
    python3-xlib mesa-libGLU-devel libXaw-devel
```

### Stap 6: LinuxCNC Compileren

Compileer LinuxCNC vanaf source met EtherCAT ondersteuning:

```bash
cd ~/linuxcnc-dev

# Clone LinuxCNC repository
git clone https://github.com/LinuxCNC/linuxcnc.git
cd linuxcnc

# Checkout stable versie (of master voor nieuwste features)
git checkout 2.9

# Configureer met EtherCAT support
cd src
./autogen.sh

./configure \
    --with-realtime=uspace \
    --enable-non-distributable=yes \
    --with-boost-python=boost_python3 \
    CPPFLAGS="-I/opt/etherlab/include" \
    LDFLAGS="-L/opt/etherlab/lib"

# Compileer (dit duurt 10-30 minuten afhankelijk van je systeem)
make -j$(nproc)

# Installeer
sudo make install
```

### Stap 7: Omgevingsvariabelen

Configureer de omgevingsvariabelen voor LinuxCNC en EtherCAT:

```bash
# Voeg toe aan je .bashrc
tee -a ~/.bashrc << 'EOF'

# LinuxCNC environment
if [ -f /usr/local/etc/linuxcnc/linuxcnc.sh ]; then
    . /usr/local/etc/linuxcnc/linuxcnc.sh
fi

# EtherCAT environment
export PATH=/opt/etherlab/bin:/opt/etherlab/sbin:$PATH
export LD_LIBRARY_PATH=/opt/etherlab/lib:$LD_LIBRARY_PATH
EOF

# Herlaad .bashrc
source ~/.bashrc
```

### Stap 8: EtherCAT Testen

Test of de EtherCAT master correct werkt:

```bash
# Check EtherCAT master status
sudo /opt/etherlab/bin/ethercat master

# Verwachte output:
# Master0
#   Phase: Idle
#   Active: no
#   Slaves: 0

# Met motor aangesloten en ingeschakeld:
sudo /opt/etherlab/bin/ethercat slaves

# Dit zou je servo motor moeten tonen, bijvoorbeeld:
# 0  0:0  PREOP  +  IHSV-EC Integrated Servo
```

**Belangrijke EtherCAT commando's:**

```bash
# Gedetailleerde slave informatie
sudo ethercat slaves -v

# SDO (Service Data Object) lezen
sudo ethercat upload -p 0 -t uint32 0x1000 0

# Alias toewijzen aan slave
sudo ethercat alias -p 0 0x1000

# XML beschrijving genereren (voor configuratie)
sudo ethercat xml -p 0 > ~/ihsv57_slave.xml
```

### Stap 9: LinuxCNC EtherCAT Component

Installeer de LinuxCNC EtherCAT (lcec) HAL component:

```bash
cd ~/linuxcnc-dev

# Clone linuxcnc-ethercat repository
git clone https://github.com/linuxcnc-ethercat/linuxcnc-ethercat.git
cd linuxcnc-ethercat

# Installeer extra dependencies
sudo dnf install -y libxml2-devel

# Configureer
./configure \
    --with-linuxcnc=/usr/local \
    --with-ethercat=/opt/etherlab

# Compileer en installeer
make -j$(nproc)
sudo make install

# Verificatie
ls -la /usr/local/lib/linuxcnc/modules/lcec*
```

### Stap 10: Motor Configuratie

Nu kunnen we een basis LinuxCNC configuratie maken voor de IHSV57 motor.

#### Slave Informatie Verzamelen

```bash
# Met motor aangesloten en ingeschakeld:
sudo ethercat slaves -v

# Noteer de volgende informatie:
# - Vendor ID (bijvoorbeeld: 0x00000000)
# - Product Code (bijvoorbeeld: 0x00000000)
# - Revision Number
```

#### Basis LinuxCNC Configuratie Aanmaken

```bash
# Start LinuxCNC configuratie wizard
linuxcnc

# Of gebruik Stepconf Wizard voor basis configuratie
stepconf
```

#### EtherCAT XML Configuratie

Creëer een EtherCAT configuratie bestand `ethercat-conf.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<masters>
  <master idx="0" appTimePeriod="1000000" refClockSyncCycles="1">
    <slave idx="0" type="IHSV_EC" name="servo">
      <dcConf assignActivate="300" sync0Cycle="*1" sync0Shift="0"/>
    </slave>
  </master>
</masters>
```

#### HAL Configuratie

Voeg toe aan je HAL configuratie bestand (bijvoorbeeld `custom.hal`):

```hal
# Load EtherCAT master
loadrt lcec
loadrt cia402 count=1

# Load motion controller
loadrt [KINS]KINEMATICS
loadrt [EMCMOT]EMCMOT servo_period_nsec=[EMCMOT]SERVO_PERIOD num_joints=[KINS]JOINTS

# Add EtherCAT master to servo thread
addf lcec.read-all servo-thread
addf cia402.0.read-all servo-thread
addf motion-command-handler servo-thread
addf motion-controller servo-thread
addf cia402.0.write-all servo-thread
addf lcec.write-all servo-thread

# Configure servo drive (pas aan voor jouw motor)
setp cia402.0.csp-mode 1
setp cia402.0.pos-scale 10000

# Connect position command
net x-pos-cmd axis.0.motor-pos-cmd => cia402.0.pos-cmd
net x-pos-fb cia402.0.pos-fb => axis.0.motor-pos-fb

# Connect enable
net x-enable axis.0.amp-enable-out => cia402.0.enable

# EtherCAT slave to CiA402
net ec-servo-status lcec.0.servo.cia-state => cia402.0.status-word
net ec-servo-control cia402.0.control-word => lcec.0.servo.cia-controlword
net ec-servo-pos-cmd cia402.0.position-cmd => lcec.0.servo.cia-position-cmd
net ec-servo-pos-fb lcec.0.servo.cia-position-fb => cia402.0.position-fb
```

**Opmerking:** Deze HAL configuratie is een basis voorbeeld. De exacte configuratie hangt af van:
- De EtherCAT slave configuratie van je motor
- De gewenste sturingmode (CSV, CSP, CST)
- Je machine kinematica

## Troubleshooting

### EtherCAT Master Start Niet

```bash
# Check journalctl logs
sudo journalctl -u ethercat.service -n 50

# Check of de NIC correct is geconfigureerd
cat /etc/sysconfig/ethercat

# Test handmatig
sudo /opt/etherlab/bin/ethercatctl start
```

### Geen Slaves Gevonden

```bash
# Check of de motor is aangesloten en heeft stroom
# Check Ethernet kabel (gebruik CAT5e of hoger)

# Check EtherCAT state
sudo ethercat master
sudo ethercat slaves

# Check dmesg voor errors
sudo dmesg | grep -i ethercat
```

### Hoge Latency

```bash
# Run latency test
latency-test

# Verwachte waarden:
# - Base thread: < 10000 ns (niet gebruikt in servo setup)
# - Servo thread: < 50000 ns (goed), < 100000 ns (acceptabel)

# Als latency te hoog:
# 1. Isoleer CPU cores voor real-time
# 2. Disable CPU power management
# 3. Disable hyperthreading
# 4. Check IRQ conflicts
```

### LinuxCNC Start Niet

```bash
# Check environment
echo $PATH | grep linuxcnc
echo $LD_LIBRARY_PATH | grep etherlab

# Test LinuxCNC
linuxcnc --version

# Check debug output
linuxcnc -d 5
```

### EtherCAT HAL Component Laadt Niet

```bash
# Check of lcec module bestaat
ls -la /usr/local/lib/linuxcnc/modules/lcec*

# Test laden van module
halcmd loadrt lcec

# Check errors
dmesg | tail -n 50
```

## Geavanceerde Configuratie

### CPU Isolation voor Real-Time

Voor productie-systemen kan je CPU cores isoleren:

```bash
# Edit GRUB configuratie
sudo nano /etc/default/grub

# Voeg toe aan GRUB_CMDLINE_LINUX:
# isolcpus=2,3 nohz_full=2,3 rcu_nocbs=2,3

# Update GRUB
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
sudo reboot
```

### IRQ Tuning

```bash
# Vind IRQ van je EtherCAT NIC
cat /proc/interrupts | grep eth

# Bind IRQ aan specifieke CPU core
sudo tee /etc/systemd/system/irqbalance.service.d/override.conf << EOF
[Service]
Environment="IRQBALANCE_BANNED_CPUS=0c"
EOF

sudo systemctl daemon-reload
sudo systemctl restart irqbalance
```

### Network Interface Optimalisatie

```bash
# Disable network power management
sudo ethtool -s enp3s0 wol d

# Increase ring buffers
sudo ethtool -G enp3s0 rx 4096 tx 4096

# Disable offloading
sudo ethtool -K enp3s0 gro off
sudo ethtool -K enp3s0 tso off
sudo ethtool -K enp3s0 gso off
```

## Testen van de Motor

Basis test procedure (VOORZICHTIG):

1. **Safety first:**
   - Motor moet vrij kunnen draaien (niet belast)
   - Noodstop binnen handbereik
   - Begin met lage snelheden

2. **Start LinuxCNC:**
   ```bash
   linuxcnc /path/to/your/config.ini
   ```

3. **Enable machine:**
   - F1 (estop uit)
   - F2 (machine aan)

4. **Test jog:**
   - Selecteer X-as
   - Gebruik pijltjestoetsen voor kleine bewegingen
   - Monitor feedback positie

5. **G-code test:**
   ```gcode
   G21 (millimeters)
   G90 (absolute mode)
   F100 (feed rate)
   G0 X10
   G0 X0
   ```

## Bronnen

### Officiële Documentatie
- [LinuxCNC Documentatie](https://linuxcnc.org/docs/html/)
- [IgH EtherCAT Master](https://etherlab.org/en/ethercat/)
- [LinuxCNC EtherCAT](https://github.com/linuxcnc-ethercat/linuxcnc-ethercat)

### Community
- [LinuxCNC Forum](https://forum.linuxcnc.org/)
- [LinuxCNC Wiki](https://wiki.linuxcnc.org/)

### Hardware Informatie
- IHSV57-30-14-36-EC Servo Motor Handleiding
- EtherCAT specificaties: [ETG](https://www.ethercat.org/)

## Licentie

Deze handleiding is vrij beschikbaar voor persoonlijk en educatief gebruik.

## Bijdragen

Verbeteringen en correcties zijn welkom! Open een issue of pull request op GitHub.

## Disclaimer

Deze handleiding is bedoeld als educatieve resource. De auteur is niet verantwoordelijk voor schade aan hardware of letsel als gevolg van het volgen van deze instructies. Werk altijd veilig met machines en elektronica.

---

**Laatst bijgewerkt:** December 2025  
**Versie:** 1.0  
**Getest op:** Fedora 43 KDE, LinuxCNC 2.9, kernel-rt 6.11.5