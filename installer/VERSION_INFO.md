# Bootstrap Versies

## 📦 Twee versies van bootstrap.sh

Er zijn twee versies van bootstrap.sh, elk met een andere `SCRIPT_BRANCH_HINT`:

### 1. bootstrap.sh (feature-installer)
```bash
SCRIPT_BRANCH_HINT="feature-installer"
```

**Gebruik:** Voor development/testing op feature-installer branch
**Upload naar:** `feature-installer` branch op GitHub

**Command:**
```bash
curl -sSL https://raw.githubusercontent.com/rokoter/LinuxCNC/feature-installer/installer/bootstrap.sh | sudo bash
```

### 2. bootstrap-main.sh (main) 
```bash
SCRIPT_BRANCH_HINT="main"
```

**Gebruik:** Voor productie na merge naar main
**Upload naar:** `main` branch op GitHub (hernoem naar `bootstrap.sh`)

**Command:**
```bash
curl -sSL https://raw.githubusercontent.com/rokoter/LinuxCNC/main/installer/bootstrap.sh | sudo bash
```

## 🔧 Hoe het werkt

De `SCRIPT_BRANCH_HINT` variabele vertelt bootstrap.sh welke branch te clonen als er geen `BOOTSTRAP_BRANCH` environment variable is gezet.

**Bij curl pipe:**
- BASH_SOURCE[0] bestaat niet
- Script gebruikt SCRIPT_BRANCH_HINT als default
- feature-installer versie → cloned feature-installer
- main versie → cloned main

**Bij wget + run:**
- BASH_SOURCE[0] bestaat wel
- Script probeert branch uit path te detecteren
- Valt terug op SCRIPT_BRANCH_HINT als detectie faalt

## 📋 Deployment Workflow

### Nu (feature-installer branch):

```bash
cd ~/LinuxCNC
git checkout feature-installer
cd installer

# Gebruik bootstrap.sh (met SCRIPT_BRANCH_HINT="feature-installer")
cp bootstrap.sh bootstrap.sh  # Al correct
git add bootstrap.sh
git commit -m "Update bootstrap for feature-installer"
git push origin feature-installer
```

### Later (na merge naar main):

```bash
cd ~/LinuxCNC
git checkout main
git merge feature-installer
cd installer

# Vervang bootstrap.sh met main versie
cp bootstrap-main.sh bootstrap.sh
git add bootstrap.sh
git commit -m "Update bootstrap for main branch"
git push origin main
```

## 🎯 Waarom twee versies?

Omdat je de **juiste branch moet clonen** afhankelijk van waar het script vandaan komt:

- `feature-installer/installer/bootstrap.sh` → moet `feature-installer` clonen
- `main/installer/bootstrap.sh` → moet `main` clonen

Anders krijg je:
- ❌ Download van feature-installer maar clone main → installer niet gevonden!
- ❌ Download van main maar clone feature-installer → oude versie!

## ✅ Met SCRIPT_BRANCH_HINT:

- ✅ Juiste versie op juiste branch
- ✅ Auto-detect werkt altijd
- ✅ Geen BOOTSTRAP_BRANCH env var nodig
- ✅ ONE command werkt: `curl ... | sudo bash`
