# Project Status - feature-sensor-acc

**Branch:** feature-sensor-acc  
**Status:** 🚧 Concept/Architecture Phase  
**Last Updated:** 2026-01-01

## 📊 Current State

Dit is een **concept implementatie** voor een CNC trillings monitoring systeem. De architectuur, bestandsstructuur en core concepten zijn uitgewerkt, maar er is nog ontwikkelwerk nodig voordat het production-ready is.

### ✅ Compleet

- [x] Project architectuur ontwerp
- [x] Bestandsstructuur en organisatie
- [x] Hardware specificaties en pinout
- [x] Firmware skeleton (Arduino C++)
- [x] Python HAL component skeleton
- [x] Web interface HTML/CSS/JS
- [x] Configuratie bestanden (JSON)
- [x] Documentatie structuur
- [x] Installation guide
- [x] README met overview

### 🚧 Werk in Uitvoering (TODO)

#### Hardware
- [ ] Test fysieke MPU6050 met Pico W
- [ ] Valideer I2C communicatie @ 100Hz
- [ ] Test E-stop GPIO latency
- [ ] 3D print enclosure STL files maken
- [ ] Lange termijn vibratie test

#### Firmware (Pico)
- [ ] Complete error handling
- [ ] Flash storage implementatie (LittleFS)
- [ ] Config save/load functionaliteit
- [ ] Watchdog timer implementatie
- [ ] WiFi AP/Client mode switching
- [ ] OTA update functionaliteit
- [ ] Calibration routine
- [ ] Serial command parser afmaken

#### Python HAL Component
- [ ] Robuuste serial exception handling
- [ ] CSV logging optimalisatie
- [ ] HAL pin threshold updates
- [ ] Reconnection logic verbeteren
- [ ] Statistics tracking
- [ ] Memory leak testing
- [ ] Performance profiling

#### Web Interface
- [ ] Real-time chart library integratie
- [ ] WebSocket reconnection logic
- [ ] Config validation
- [ ] Error notifications
- [ ] Mobile responsive testen
- [ ] Download log functie
- [ ] Historical data viewer

#### Documentatie
- [ ] CALIBRATION.md schrijven
- [ ] USAGE.md schrijven
- [ ] TROUBLESHOOTING.md schrijven
- [ ] Photo's/screenshots toevoegen
- [ ] Video demonstraties
- [ ] Example datasets

#### Testing
- [ ] Unit tests voor Python code
- [ ] Integration tests HAL <-> Firmware
- [ ] E-stop response time meting
- [ ] WiFi reliability tests
- [ ] Long-running stability test
- [ ] Different machine types validation

## 🎯 Development Priorities

### Phase 1: Core Functionality (Week 1-2)
**Doel:** Werkend basis systeem zonder WiFi

1. **Hardware validatie**
   - MPU6050 + Pico W op breadboard
   - Serial output @ 100Hz bevestigen
   - Basic vibration measurement testen

2. **Firmware basis**
   - Sensor reading loop stabiel maken
   - USB serial data stream testen
   - Basic threshold checking

3. **Python HAL component**
   - Serial data ontvangen
   - HAL pins updaten
   - CSV logging werkend krijgen

4. **E-stop systeem**
   - GPIO output implementeren
   - Test met dummy E-stop circuit
   - Latency meten

**Success Criteria:**
- [ ] Continuous 100Hz sensor data
- [ ] CSV log file created
- [ ] HAL pins update in real-time
- [ ] E-stop triggers binnen 100ms

### Phase 2: Safety & Reliability (Week 3)
**Doel:** Production-ready safety systeem

1. **Redundant E-stop**
   - GPIO + USB dual path
   - Watchdog timer
   - Fail-safe testing

2. **Error handling**
   - Sensor disconnect recovery
   - USB disconnect handling
   - Invalid data rejection

3. **Configuration**
   - Flash storage voor settings
   - Runtime threshold updates
   - Persistent config across reboots

**Success Criteria:**
- [ ] System survives disconnects gracefully
- [ ] E-stop triggers on sensor failure
- [ ] Config survives power cycle
- [ ] Zero crashes in 24hr test

### Phase 3: WiFi Management (Week 4)
**Doel:** Remote monitoring en configuratie

1. **WiFi stability**
   - AP mode reliable
   - WebSocket stream
   - Config API endpoints

2. **Web interface**
   - Live plotting
   - Config management
   - Status dashboard

3. **Documentation**
   - Complete installation guide
   - Usage examples
   - Troubleshooting guide

**Success Criteria:**
- [ ] Web interface accessible
- [ ] Live plot shows data
- [ ] Config changes apply
- [ ] WiFi crash doesn't affect safety

## 🔨 Known Issues / Technical Debt

### Firmware
```cpp
// TODO: Implement proper error recovery
// Current: System halts on sensor failure
// Wanted: Retry logic with exponential backoff

// TODO: Flash storage not implemented
// Current: Config hardcoded in config.h
// Wanted: LittleFS JSON config file

// TODO: WebSocket rate limiting
// Current: Sends every sample (100Hz)
// Wanted: Decimated to 10Hz for WiFi efficiency
```

### Python HAL
```python
# TODO: Better serial timeout handling
# Current: Fixed 1s timeout
# Wanted: Adaptive timeout based on sample rate

# TODO: Peak reset needs HAL pin edge detection
# Current: Level trigger (resets continuously)
# Wanted: Edge trigger (reset once per button press)

# TODO: Add CSV rotation
# Current: Single file grows unbounded
# Wanted: Daily rotation with size limits
```

### Web Interface
```javascript
// TODO: Chart.js realtime plugin needed
// Current: Manual time-series management
// Wanted: Built-in streaming mode

// TODO: Add offline mode
// Current: Requires WebSocket
// Wanted: Graceful degradation to polling
```

## 📝 Code Quality Notes

### What's Good
- ✅ Clear separation of concerns (Core 0 vs Core 1)
- ✅ Dual E-stop redundancy designed in
- ✅ Comprehensive configuration system
- ✅ Good documentation structure
- ✅ Modular code organization

### What Needs Work
- ⚠️ Error handling incomplete
- ⚠️ No unit tests yet
- ⚠️ Some TODOs in critical paths
- ⚠️ Performance not profiled
- ⚠️ Memory usage not measured

## 🧪 Testing Plan

### Hardware Tests
```
1. I2C reliability @ 400kHz
2. E-stop latency measurement
3. Long cable run (5m) testing
4. EMI immunity (near VFD)
5. Temperature stability
6. Vibration sensor self-test
```

### Software Tests
```
1. Serial buffer overflow
2. CSV file corruption
3. HAL component crash recovery
4. WiFi disconnect/reconnect
5. Concurrent web clients
6. Config save/load integrity
```

### Integration Tests
```
1. Full stack: Sensor → Pico → HAL → LinuxCNC
2. E-stop trigger during machining
3. Threshold updates during operation
4. Web config while logging
5. USB disconnect recovery
6. 48-hour continuous run
```

## 🚀 Future Enhancements (Post-MVP)

### Advanced Features
- [ ] FFT analysis on Pico (frequency domain)
- [ ] Adaptive threshold learning (ML)
- [ ] Multi-sensor support (X/Y/Z each)
- [ ] Database logging (InfluxDB)
- [ ] Grafana dashboard
- [ ] Email/SMS alerts
- [ ] Predictive maintenance
- [ ] Tool wear correlation

### Integration
- [ ] LinuxCNC input shaper integration
- [ ] Automatic feed override adjustment
- [ ] G-code pre-flight validation
- [ ] Cloud data backup
- [ ] Mobile app (React Native)

## 💡 Development Tips

### Voor development:
```bash
# Test firmware zonder LinuxCNC
pio device monitor --baud 115200

# Test HAL component standalone
halrun
loadusr -W vibration_monitor.py --port /dev/ttyACM0 --no-log

# Monitor HAL pins
watch -n 0.1 halcmd show pin vibration

# Check for memory leaks
valgrind --leak-check=full python3 vibration_monitor.py
```

### Voor debugging:
```bash
# Increase verbosity
export DEBUG_SERIAL_OUTPUT=true
export DEBUG_TIMING=true

# Log to file
python3 vibration_monitor.py 2>&1 | tee debug.log

# Monitor system resources
htop -p $(pgrep -f vibration_monitor)
```

## 📚 Resources

### Datasheets
- RP2040: https://datasheets.raspberrypi.com/rp2040/rp2040-datasheet.pdf
- MPU6050: https://invensense.tdk.com/products/motion-tracking/6-axis/mpu-6050/
- LinuxCNC HAL: http://linuxcnc.org/docs/html/hal/intro.html

### Libraries
- Adafruit MPU6050: https://github.com/adafruit/Adafruit_MPU6050
- arduino-pico: https://github.com/earlephilhower/arduino-pico
- Chart.js: https://www.chartjs.org/

### Example Projects
- Klipper resonance testing: https://www.klipper3d.org/Resonance_Compensation.html
- GRBL vibration: https://github.com/gnea/grbl/wiki

## 🤝 Contributing

Dit is een feature branch in development. Om bij te dragen:

1. Test de hardware setup
2. Report issues met debug output
3. Suggest verbeteringen voor architectuur
4. Deel resultaten van jullie machine

## 📞 Contact / Support

Voor vragen tijdens development:
- Check docs/ directory
- Review ARCHITECTURE.md
- Test met example configs
- Submit issues met logs

---

**Let op:** Dit is conceptcode. Test grondig voordat je dit in productie gebruikt. E-stop systeem moet altijd gevalideerd worden voor jouw specifieke setup.
