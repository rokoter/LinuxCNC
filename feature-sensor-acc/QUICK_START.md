# 🚀 Quick Start - CNC Vibration Monitor (feature-sensor-acc)

## 📦 Wat zit er in deze ZIP?

Complete project structuur voor een **CNC Trillings Monitoring & E-stop systeem** op basis van:
- **RP2040 Pico W** (€6-8) + **MPU6050** sensor (€2-3)
- **Dual E-stop**: GPIO hardware pin + USB serial backup
- **WiFi management**: Web dashboard voor configuratie (optioneel)
- **LinuxCNC HAL integratie**: Real-time monitoring

## 📁 Inhoud

```
feature-sensor-acc/
├── README.md                    ← Start hier! Project overview
├── ARCHITECTURE.md              ← Technische architectuur & dataflow
├── PROJECT_STATUS.md            ← Development status & TODO's
│
├── hardware/
│   ├── README.md               ← Hardware assembly guide + wiring
│   └── pico-firmware/          ← Arduino firmware voor Pico W
│       ├── pico-firmware.ino   ← Main firmware (dual-core)
│       ├── config.h            ← Alle configuratie defines
│       └── platformio.ini      ← Build configuratie
│
├── software/
│   ├── hal-monitor/
│   │   ├── vibration_monitor.py  ← LinuxCNC HAL component
│   │   └── requirements.txt       ← Python dependencies
│   └── web-interface/
│       ├── index.html          ← Dashboard UI
│       ├── style.css           ← Styling
│       └── app.js              ← WebSocket client
│
├── config/
│   ├── thresholds.json         ← Vibration drempelwaarden
│   ├── network.json            ← WiFi settings
│   └── hal-config-example.hal  ← LinuxCNC HAL voorbeeld
│
└── docs/
    └── INSTALLATION.md         ← Stap-voor-stap installatie
```

## ⚡ Quick Start in 3 Stappen

### 1️⃣ Hardware (15 minuten)
```
Hardware nodig:
- RP2040 Pico W
- MPU6050 module
- 4 jumper wires
- USB kabel

Aansluiten:
MPU6050 → Pico W
  VCC  →  3.3V
  GND  →  GND
  SDA  →  GP4
  SCL  →  GP5

E-stop: GP15 → LinuxCNC E-stop input
```

📖 Zie: `hardware/README.md` voor gedetailleerde wiring diagrams

### 2️⃣ Firmware Upload (10 minuten)
```bash
# Via Arduino IDE:
1. Installeer RP2040 board support
2. Installeer libraries (zie platformio.ini)
3. Open pico-firmware.ino
4. Upload naar Pico W

# Of via PlatformIO:
cd hardware/pico-firmware/
pio run --target upload
```

📖 Zie: `docs/INSTALLATION.md` stap 2

### 3️⃣ LinuxCNC Setup (20 minuten)
```bash
# Installeer Python dependencies
cd software/hal-monitor/
pip3 install -r requirements.txt

# Kopieer naar LinuxCNC config
cp vibration_monitor.py ~/linuxcnc/configs/your-machine/

# Voeg toe aan custom.hal:
loadusr -W vibration_monitor.py --port /dev/ttyACM0
net hw-estop parport.0.pin-15-in => iocontrol.0.emc-enable-in
setp vibration.enable true
```

📖 Zie: `config/hal-config-example.hal` voor complete setup

## 🎯 Belangrijke Concepten

### Dual E-stop Systeem
```
Vibration > threshold
    ↓
[1] GPIO Pin LOW (hardware) ──► LinuxCNC E-stop (instant)
[2] USB Serial "ESTOP"      ──► HAL E-stop (backup)
[3] WiFi broadcast          ──► Dashboard alert (info only)
```

### Core Architectuur
```
Pico Core 0 (Safety - altijd actief)
├─ MPU6050 sensor @ 100Hz
├─ Threshold checking
└─ E-stop triggers

Pico Core 1 (Communication - best effort)
├─ USB Serial data logging
└─ WiFi management (optioneel)
```

### WiFi = Management ONLY
- **Niet voor E-stop!** (te langzaam, kan crashen)
- **Wel voor:** Live monitoring, config changes, dashboard
- **Default:** Access Point mode op 192.168.4.1

## ⚙️ Configuratie

### Drempelwaarden Aanpassen
```json
// config/thresholds.json
{
  "warning": 2.0,     // G-force - gele LED
  "critical": 4.0,    // G-force - rode LED
  "emergency": 6.0    // G-force - E-STOP!
}
```

Start conservatief, verlaag na testen!

### WiFi Setup (optioneel)
```json
// config/network.json
{
  "mode": "AP",                    // Of "CLIENT"
  "ssid": "CNC-VibMon",
  "password": "verander-dit!"
}
```

Access dashboard: http://192.168.4.1 (AP mode)

## 🧪 Testen

### Test 1: Serial Output
```bash
screen /dev/ttyACM0 115200
# Moet zien:
# VIB:DATA,timestamp,ax,ay,az,gx,gy,gz,mag,status
# Tik op sensor → waarden springen
```

### Test 2: HAL Integration
```bash
halrun
loadusr -W vibration_monitor.py --port /dev/ttyACM0
show pin vibration
# vibration.current moet updaten ~100Hz
```

### Test 3: E-stop
```bash
# Schud sensor flink
# → LED wordt rood
# → GP15 goes LOW
# → LinuxCNC stopt
```

## 📊 Status: Work in Progress

**✅ Klaar voor gebruik:**
- Hardware ontwerp & pinout
- Firmware architectuur
- HAL component skeleton
- Documentatie

**🚧 Nog te doen:**
- Volledige error handling
- Flash storage config
- WiFi stability testing
- Production testing
- Photos/videos

Zie `PROJECT_STATUS.md` voor complete TODO lijst.

## 🆘 Problemen?

**Pico niet gevonden:**
```bash
ls /dev/ttyACM*  # Controleer USB kabel (data-capable!)
```

**Geen sensor data:**
```bash
# Check I2C wiring - meest voorkomende probleem!
# SDA/SCL verwisseld?
# 3.3V power correct?
```

**E-stop werkt niet:**
```bash
# Multimeter op GP15: moet 3.3V zijn normaal, 0V bij trigger
# Check HAL: halcmd show pin parport.0.pin-15-in
```

Zie `docs/INSTALLATION.md` sectie "Troubleshooting" voor meer.

## 📚 Meer Lezen

1. **README.md** - Volledig project overview
2. **ARCHITECTURE.md** - Technische deep-dive
3. **hardware/README.md** - Assembly guide met wiring diagrams  
4. **docs/INSTALLATION.md** - Stap-voor-stap installatie
5. **PROJECT_STATUS.md** - Development status & roadmap

## 🔒 Veiligheid

⚠️ **Dit is concept code!** Test grondig voordat je dit in productie gebruikt.

**Belangrijke checks:**
- [ ] E-stop hardware pin getest en gevalideerd
- [ ] Backup E-stop via USB getest
- [ ] Thresholds correct voor jouw machine
- [ ] Sensor goed gemonteerd (niet los)
- [ ] Kabels veilig geroute (geen snagging)
- [ ] Test run zonder werkstuk eerst

## 💬 Feedback & Vragen

Dit is een feature branch in development. Voel je vrij om:
- Issues te rapporteren
- Verbeteringen voor te stellen  
- Resultaten van je setup te delen
- Bij te dragen aan documentatie

## 🎓 Achtergrond

**Waarom dit systeem?**
- Data-driven machine tuning (vs trial & error)
- Real-time bescherming tegen overload
- Preventief onderhoud (slijtage detectie)
- Betere oppervlakte afwerking
- Machine levensduur verlengen

**Geïnspireerd door:**
- Klipper's resonance testing
- GRBL vibration analysis
- LinuxCNC input shaper

---

**Veel succes met het bouwen! 🔧**

Voor vragen: check de docs/ directory of review ARCHITECTURE.md voor technische details.
