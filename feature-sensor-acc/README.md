# CNC Vibration Monitoring & Safety System

## 🎯 Overzicht

Real-time trillings monitoring systeem voor LinuxCNC machines met dual E-stop beveiliging en remote management via WiFi.

### Kernfunctionaliteit

1. **Realtime Vibration Monitoring** - IMU sensor op Z-axis meet trillingen tijdens operatie
2. **Dual E-stop System** - Redundante beveiliging via GPIO hardware pin + USB serial
3. **WiFi Management Interface** - Web dashboard voor configuratie en monitoring (non-critical)
4. **Data Logging** - Continue logging naar CSV voor analyse en tuning

## 🏗️ Systeem Architectuur

```
┌──────────────────────────────────────────────────────────┐
│                    RP2040 Pico W                         │
├──────────────────────────────────────────────────────────┤
│  Core 0: Safety (realtime, altijd actief)               │
│  ├─ MPU6050 @ 100Hz                                     │
│  ├─ Threshold checking                                  │
│  └─ E-stop triggers (USB + GPIO)                        │
│                                                          │
│  Core 1: Management (non-blocking)                      │
│  ├─ USB Serial (primary data)                           │
│  └─ WiFi WebServer (management only)                    │
└──────────────────────────────────────────────────────────┘
         │              │              │
    ┌────▼───┐    ┌─────▼─────┐  ┌────▼─────┐
    │MPU6050 │    │USB Serial │  │GPIO Pin  │
    └────────┘    └─────┬─────┘  └────┬─────┘
                        │              │
                   ┌────▼──────────────▼─────┐
                   │   LinuxCNC PC           │
                   │  - Python HAL monitor   │
                   │  - Data logging         │
                   │  - E-stop processing    │
                   └─────────────────────────┘
```

## 🔌 Hardware Setup

### Componenten
- **RP2040 Pico W** - Microcontroller met WiFi
- **MPU6050** - 6-axis IMU sensor (accelerometer + gyroscope)
- **USB kabel** - Data + power naar LinuxCNC PC
- **1x GPIO draad** - Hardware E-stop naar LinuxCNC

### Pinout
```
Pico W          MPU6050
────────────────────────
3.3V       →    VCC
GND        →    GND
GP4 (SDA)  →    SDA
GP5 (SCL)  →    SCL

Pico W          LinuxCNC
────────────────────────
GP15       →    E-stop input pin (parallel port/Mesa)
GND        →    GND
USB        →    USB poort PC
```

### Montage Locatie
- **Sensor**: Z-axis carriage, nabij spindel
- **Kabel routing**: Via bestaande kabelgoot langs Z-beweging
- **Behuizing**: 3D-printed enclosure (STL's in `/hardware/enclosures/`)

## 📂 Project Structuur

```
feature-sensor-acc/
├── README.md                          # Dit bestand
├── ARCHITECTURE.md                    # Gedetailleerde architectuur
├── hardware/
│   ├── README.md                      # Hardware setup guide
│   ├── wiring-diagram.md             # Aansluit schema
│   ├── pico-firmware/
│   │   ├── pico-firmware.ino         # Arduino code voor Pico W
│   │   ├── config.h                  # Configuratie defines
│   │   ├── sensor.cpp                # MPU6050 interface
│   │   ├── safety.cpp                # E-stop logica
│   │   ├── webserver.cpp             # WiFi management
│   │   └── platformio.ini            # PlatformIO config
│   └── enclosures/
│       ├── pico-case.stl             # 3D print behuizing
│       └── sensor-mount.stl          # Sensor montage bracket
├── software/
│   ├── hal-monitor/
│   │   ├── vibration_monitor.py      # LinuxCNC HAL component
│   │   ├── requirements.txt
│   │   └── README.md
│   ├── data-logger/
│   │   ├── logger.py                 # CSV data logging
│   │   ├── analyzer.py               # Analyse tool (FFT, plots)
│   │   └── config.json               # Logging configuratie
│   └── web-interface/
│       ├── index.html                # Dashboard
│       ├── config.html               # Settings pagina
│       ├── app.js                    # WebSocket client
│       └── style.css
├── config/
│   ├── thresholds.json               # Vibration drempels
│   ├── network.json                  # WiFi settings
│   └── hal-config-example.hal        # LinuxCNC HAL voorbeeld
├── docs/
│   ├── INSTALLATION.md               # Installatie handleiding
│   ├── CALIBRATION.md                # Calibratie procedure
│   ├── USAGE.md                      # Gebruikers handleiding
│   └── TROUBLESHOOTING.md            # Probleemoplossing
└── tests/
    ├── test-patterns/
    │   └── vibration-test.ngc        # G-code test patronen
    └── validation/
        └── simulate-vibration.py     # Test zonder hardware
```

## 🚀 Quick Start

### 1. Hardware Assemblage
```bash
# Zie hardware/README.md voor gedetailleerde instructies
1. Soldeer pin headers op Pico W
2. Verbind MPU6050 via I2C
3. Monteer op Z-axis
4. Route USB kabel naar PC
5. Verbind GPIO15 naar E-stop input
```

### 2. Firmware Upload
```bash
cd hardware/pico-firmware/
# Via Arduino IDE of PlatformIO
pio run --target upload
```

### 3. LinuxCNC HAL Setup
```bash
cd software/hal-monitor/
pip install -r requirements.txt
# Kopieer naar LinuxCNC config directory
cp vibration_monitor.py ~/linuxcnc/configs/your-machine/
# Voeg toe aan HAL file (zie config/hal-config-example.hal)
```

### 4. Test Verbinding
```bash
# Check USB serial
python3 software/data-logger/logger.py --test

# Check WiFi (optioneel)
# Browse naar http://pico.local (na WiFi configuratie)
```

## ⚙️ Configuratie

### Vibration Thresholds
Edit `config/thresholds.json`:
```json
{
  "warning": 2.0,    // G-force - gele LED
  "critical": 4.0,   // G-force - rode LED  
  "emergency": 6.0   // G-force - trigger E-stop
}
```

### WiFi Setup
Edit `config/network.json`:
```json
{
  "mode": "AP",              // "AP" of "CLIENT"
  "ssid": "CNC-VibMon",
  "password": "your-password",
  "hostname": "pico-vibmon"
}
```

## 🛡️ E-stop Systeem

### Dual Redundancy
1. **GPIO Hardware Pin** (primary)
   - Direct naar LinuxCNC E-stop input
   - Instant hardware interrupt
   - Fail-safe (disconnected = E-stop)

2. **USB Serial** (backup)
   - Software E-stop via HAL
   - Milliseconden latency
   - Logging van event

### E-stop Flow
```
Vibration > threshold
    ↓
[Pico] GPIO pin LOW
    ↓
[LinuxCNC] Hardware E-stop triggered
    ↓
[Parallel] USB "ESTOP:CRITICAL" bericht
    ↓
[Python HAL] Log event + backup E-stop
    ↓
[Optional] WiFi broadcast voor dashboard alert
```

## 📊 Gebruik Cases

### 1. Calibration Mode
- Run G-code test patterns
- Log naar CSV voor analyse
- Optimaliseer MAX_ACCEL en MAX_JERK parameters
- Identificeer resonance frequencies

### 2. Production Monitoring
- Real-time vibration tracking
- Automatische E-stop bij abnormale waarden
- Tool wear detectie
- Crash prevention

### 3. Preventive Maintenance
- Historical trend analysis
- Bearing wear monitoring
- Loose components detection
- Predictive alerts

## 🌐 Web Interface

### Dashboard Features
- **Live Plot** - Real-time vibration graph (WebSocket)
- **Status Indicator** - OK / WARNING / CRITICAL
- **Configuration** - Adjust thresholds zonder herstart
- **History** - View logged data
- **Diagnostics** - Sensor health, connection status

### Access
```
Mode: Access Point (default)
URL: http://192.168.4.1

Mode: Client (joined existing WiFi)
URL: http://pico-vibmon.local
```

## 📈 Development Roadmap

### Phase 1: Core Functionality ✅
- [x] Sensor reading @ 100Hz
- [x] USB serial communication
- [x] Basic threshold checking
- [ ] GPIO E-stop implementation

### Phase 2: Safety System
- [ ] Dual E-stop testing
- [ ] Fail-safe validation
- [ ] LED status indicators
- [ ] Python HAL component

### Phase 3: WiFi Management
- [ ] Web server basic
- [ ] Config interface
- [ ] WebSocket live data

### Phase 4: Advanced Features
- [ ] Historical data analysis
- [ ] Adaptive thresholds
- [ ] OTA firmware updates
- [ ] Multi-sensor support

## 🔧 Dependencies

### Hardware
- RP2040 Pico W (€6-8)
- MPU6050 module (€2-3)
- USB kabel + enkele draden

### Software - Pico
- Arduino IDE 2.x of PlatformIO
- arduino-pico core
- Adafruit MPU6050 library
- ESPAsyncWebServer (voor WiFi)

### Software - PC
- Python 3.7+
- pyserial
- numpy, matplotlib, scipy (voor analyse)
- LinuxCNC 2.8+

## 📝 Documentatie

Zie `/docs/` directory voor:
- **INSTALLATION.md** - Stap-voor-stap installatie
- **CALIBRATION.md** - Calibratie procedures
- **USAGE.md** - Dagelijks gebruik
- **TROUBLESHOOTING.md** - Veel voorkomende problemen

## 🤝 Contributing

Dit is een work-in-progress feature branch. Feedback welkom!

## 📄 License

MIT License - zie LICENSE bestand

## 🔗 Related Projects

- LinuxCNC Input Shaper
- Klipper Resonance Testing
- GRBL Vibration Analysis

---

**Status**: 🚧 In Development - Concept fase
**Last Updated**: 2026-01-01
