# 🚀 LinuxCNC EtherCAT Bootstrap Guide

## Zero-to-Running in ONE Command!

Na een verse LinuxCNC installatie hoef je maar **één ding** te doen:

```bash
# Development version (feature-installer branch) - USE THIS NOW!
curl -sSL https://raw.githubusercontent.com/rokoter/LinuxCNC/feature-installer/installer/bootstrap.sh | sudo bash

# Stable version (main branch) - coming soon after merge!
curl -sSL https://raw.githubusercontent.com/rokoter/LinuxCNC/main/installer/bootstrap.sh | sudo bash
```

**Simpel!** Geen environment variables nodig, gewoon één commando!

Dat is alles! Het script doet:
- ✅ `sudo apt update`
- ✅ Clone repository
- ✅ Installeert EtherCAT
- ✅ Configureert realtime
- ✅ Setup machine config
- ✅ **Zero handmatige stappen!**

---

## 📋 Wat je nodig hebt

**Voor je begint:**
1. Verse LinuxCNC 2.9.2+ installatie (van ISO)
2. Internet verbinding
3. Dat is het!

**Geen apt update, geen git clone, NIETS!** Het script doet alles.

---

## 🎯 Volledige Installatie (Stap-voor-Stap)

### Stap 1: Installeer LinuxCNC (als nog niet gedaan)

Download LinuxCNC ISO:
- https://linuxcnc.org/downloads/

Flash naar USB met:
- Rufus (Windows)
- Balena Etcher (Mac/Linux)
- `dd` (Linux)

Boot van USB en installeer LinuxCNC.

### Stap 2: Boot LinuxCNC

Na installatie, start je computer op in LinuxCNC.

### Stap 3: Run Bootstrap Script

Open een terminal (Ctrl+Alt+T) en voer dit commando uit:

**Voor feature-installer branch (huidige development):**
```bash
curl -sSL https://raw.githubusercontent.com/rokoter/LinuxCNC/feature-installer/installer/bootstrap.sh | sudo bash
```

**Voor main branch (zodra gemerged):**
```bash
curl -sSL https://raw.githubusercontent.com/rokoter/LinuxCNC/main/installer/bootstrap.sh | sudo bash
```

**Dat is alles!**

Het script vraagt je:
1. Welke machine type (menu)
2. Welke git branch (main/develop/custom)
3. Hostname
4. Welke network interface voor EtherCAT

Daarna doet het **alles automatisch**:
- Updates systeem
- Installeert EtherCAT
- Configureert realtime optimalisatie
- Setup machine configuratie
- Compileert HAL components

### Stap 4: Reboot

```bash
sudo reboot
```

### Stap 5: Test

```bash
# Test latency (30 min met stress!)
latency-histogram

# Check EtherCAT slaves
ethercat slaves

# Start LinuxCNC
linuxcnc ~/linuxcnc/configs/active-machine/
```

---

## 🌿 Branch Selectie

### Feature-installer (Development)

**Gebruik dit NU om te testen:**
```bash
curl -sSL https://raw.githubusercontent.com/rokoter/LinuxCNC/feature-installer/installer/bootstrap.sh | sudo bash
```

Bootstrap.sh detecteert automatisch de branch en cloned `feature-installer`.

### Main (Stable - zodra gemerged)

**Voor productie gebruik (na merge):**
```bash
curl -sSL https://raw.githubusercontent.com/rokoter/LinuxCNC/main/installer/bootstrap.sh | sudo bash
```

### Andere branches

**Forceer een specifieke branch (optioneel):**
```bash
# Clone develop branch
BOOTSTRAP_BRANCH=develop curl -sSL https://raw.githubusercontent.com/rokoter/LinuxCNC/feature-installer/installer/bootstrap.sh | sudo -E bash

# Clone een custom branch
BOOTSTRAP_BRANCH=feature-new-servo curl -sSL https://raw.githubusercontent.com/rokoter/LinuxCNC/feature-installer/installer/bootstrap.sh | sudo -E bash
```

**Normaal niet nodig!** Bootstrap detecteert de branch automatisch van de URL.

---

## 🔧 Advanced: Manual Installation

Als je liever zelf controle hebt:

```bash
# Clone repository
cd ~
git clone https://github.com/rokoter/LinuxCNC.git
cd LinuxCNC/installer

# Run installer interactief
sudo ./install.sh

# Of volledig geautomatiseerd
sudo ./install.sh --machine xyz-gantry --branch main --hostname mill-01
```

---

## 🌿 Git Branch Selectie

**Via bootstrap:**
- Script vraagt tijdens installatie
- Kies main/develop/custom branch

**Via manual install:**
```bash
# Main branch (stable)
sudo ./install.sh --branch main

# Develop branch (testing)
sudo ./install.sh --branch develop

# Custom branch
sudo ./install.sh --branch feature/new-servo

# Local files (geen git pull)
sudo ./install.sh --local
```

---

## 🔍 Wat Wordt Geïnstalleerd?

### 1. System Packages
```
git, vim, htop, build-essential, ethtool, net-tools
```

### 2. EtherCAT Master
```
linuxcnc-ethercat (from repositories)
ethercat-master
libethercat-dev
```

### 3. HAL Components
```
cia402.comp (from dbraun1981/hal-cia402)
```

### 4. Realtime Optimizations
```
CPU isolation (last 2 cores)
GRUB parameters (isolcpus, nohz_full, rcu_nocbs)
Network interface optimization
Service disabling (bluetooth, cups, etc.)
```

### 5. Machine Configuration
```
Symbolic link: ~/linuxcnc/configs/active-machine
Git repo: ~/LinuxCNC
```

---

## 📡 Network Interface (EtherCAT)

Het script detecteert **automatisch** alle network interfaces en toont:
- Interface naam (eth0, enp3s0, etc.)
- MAC address
- Driver (e1000e, igb, r8169, etc.)
- Status (UP/DOWN)

**Aanbevelingen worden getoond:**
- ✅ Intel drivers (e1000e, igb, igc) - GOED
- ⚠️ Realtek drivers (r8169, r8168) - SLECHT

Je selecteert gewoon het nummer, script doet de rest!

**Geen handmatige edits van /etc/ethercat.conf!**

---

## 🎛️ BIOS Settings

Na installatie, configureer BIOS (eenmalig):

### Disable:
- Intel SpeedStep / EIST
- Turbo Boost
- C-States (C3, C6, C7, etc.)
- Hyper-Threading (test beide)

### Enable:
- Performance Mode

Het script **toont** deze instructies na installatie.

---

## ✅ Post-Install Checklist

### 1. Latency Test (BELANGRIJK!)
```bash
latency-histogram
```

**Tijdens test:**
- Muis bewegen
- Vensters slepen
- YouTube video (1080p)
- Grote files kopiëren

**Target:** Servo thread max < 50µs

### 2. EtherCAT Test
```bash
# List slaves
ethercat slaves

# Master info
ethercat master

# Check service
sudo systemctl status ethercat.service
```

### 3. Start LinuxCNC
```bash
cd ~/linuxcnc/configs/active-machine
linuxcnc <your-config>.ini
```

---

## 🐛 Troubleshooting

### Bootstrap script fails to download
```bash
# Alternative: manual git clone
git clone https://github.com/rokoter/LinuxCNC.git
cd LinuxCNC/installer
sudo ./install.sh
```

### No network interfaces detected
```bash
# Check interfaces manually
ip a

# Install ethtool if missing
sudo apt install ethtool
```

### EtherCAT service won't start
```bash
# Check status
sudo systemctl status ethercat.service

# Check config
cat /etc/ethercat.conf

# Check dmesg for errors
dmesg | grep -i ethercat
```

### Latency too high (>100µs)
1. Check BIOS settings (see above)
2. Run installer again (applies CPU isolation)
3. Consider different hardware (see main README)

### Permission denied on /dev/EtherCAT0
```bash
# Should be automatic, but if not:
sudo chmod 666 /dev/EtherCAT0

# Check udev rule exists
ls -la /etc/udev/rules.d/99-ethercat.rules

# Reload rules
sudo udevadm control --reload-rules
sudo reboot
```

---

## 📚 Further Reading

- [Main README](README.md) - Detailed documentation
- [LinuxCNC EtherCAT Forum](https://forum.linuxcnc.org/ethercat/45336) - Community support
- [cia402 HAL Component](https://github.com/dbraun1981/hal-cia402) - Servo driver docs

---

## 🆘 Getting Help

**Issues?**
1. GitHub Issues: https://github.com/rokoter/LinuxCNC/issues
2. LinuxCNC Forum: https://forum.linuxcnc.org/
3. Check latency first: `latency-histogram`

**Before asking for help, gather:**
```bash
# System info
uname -a
linuxcnc --version

# EtherCAT info
ethercat master
ethercat slaves
sudo systemctl status ethercat.service

# Network info
ip a
cat /etc/ethercat.conf

# Latency results
# Screenshot of latency-histogram after 30min stress test
```

---

## 🎉 Success!

Als alles werkt:
- ✅ Latency < 50µs
- ✅ `ethercat slaves` toont je hardware
- ✅ LinuxCNC start zonder errors
- ✅ Machine homet zonder problemen

**Je bent klaar om te gaan freesslaan!** 🎊

---

**Version:** 1.0.0  
**Last Updated:** 2025-01-01  
**Author:** RoKoTer
