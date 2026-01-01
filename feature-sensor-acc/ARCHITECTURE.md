# System Architecture - CNC Vibration Monitor

## 🎯 Design Principles

1. **Safety First** - E-stop systeem is kritisch pad, mag nooit falen
2. **Redundancy** - Dual E-stop (GPIO + USB)
3. **Separation of Concerns** - WiFi management mag safety niet beïnvloeden
4. **Real-time Performance** - 100Hz+ sample rate gegarandeerd
5. **Fail-Safe** - Disconnection = E-stop trigger

## 🏗️ Multi-Layer Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Layer 1: Hardware                       │
│  ┌──────────┐  I2C   ┌──────────────┐                      │
│  │ MPU6050  │◄──────►│  RP2040      │                      │
│  │ Sensor   │        │  Pico W      │                      │
│  └──────────┘        └──────┬───────┘                      │
│                             │                               │
└─────────────────────────────┼───────────────────────────────┘
                              │
┌─────────────────────────────┼───────────────────────────────┐
│              Layer 2: Embedded Firmware                     │
│                             │                               │
│  ┌──────────────────────────▼────────────────────────────┐ │
│  │           Dual-Core Task Distribution                 │ │
│  │                                                        │ │
│  │  Core 0 (Safety Critical - 100% CPU time)             │ │
│  │  ┌─────────────────────────────────────────────────┐  │ │
│  │  │ • Sensor Reading @ 100Hz                        │  │ │
│  │  │ • Vibration Calculation                         │  │ │
│  │  │ • Threshold Checking                            │  │ │
│  │  │ • E-stop Trigger (GPIO + Serial)                │  │ │
│  │  │ • Watchdog Timer                                │  │ │
│  │  └─────────────────────────────────────────────────┘  │ │
│  │                                                        │ │
│  │  Core 1 (Non-Critical - Best Effort)                  │ │
│  │  ┌─────────────────────────────────────────────────┐  │ │
│  │  │ • USB Serial Communication                      │  │ │
│  │  │ • WiFi Management (optional)                    │  │ │
│  │  │ • WebSocket Server                              │  │ │
│  │  │ • Config Updates                                │  │ │
│  │  └─────────────────────────────────────────────────┘  │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                             │
│  Output Interfaces:                                        │
│  ├─ GPIO15 (E-stop pin) ──────────────────┐                │
│  ├─ USB Serial ────────────────────────┐  │                │
│  └─ WiFi WebServer (port 80) ────────┐ │  │                │
│                                       │ │  │                │
└───────────────────────────────────────┼─┼──┼────────────────┘
                                        │ │  │
┌───────────────────────────────────────┼─┼──┼────────────────┐
│          Layer 3: LinuxCNC PC         │ │  │                │
│                                       │ │  │                │
│  ┌────────────────────────────────────▼─▼──▼─────────────┐ │
│  │  Python HAL Component (vibration_monitor.py)         │ │
│  │                                                       │ │
│  │  Thread 1: USB Serial Monitor                        │ │
│  │  ├─ Read sensor data                                 │ │
│  │  ├─ Update HAL pins (vibration.current)             │ │
│  │  ├─ Check for E-stop messages                       │ │
│  │  └─ Trigger software E-stop if needed               │ │
│  │                                                       │ │
│  │  Thread 2: Data Logger                               │ │
│  │  ├─ Write CSV files                                  │ │
│  │  └─ Buffered I/O (non-blocking)                     │ │
│  │                                                       │ │
│  │  HAL Pins:                                           │ │
│  │  ├─ vibration.current (float, out)                  │ │
│  │  ├─ vibration.peak (float, out)                     │ │
│  │  ├─ vibration.estop-trigger (bit, out)              │ │
│  │  └─ vibration.connected (bit, out)                  │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌────────────────────────────────────────────────────────┐│
│  │  LinuxCNC HAL Configuration                           ││
│  │                                                        ││
│  │  Hardware E-stop Chain:                               ││
│  │  parport.0.pin-15-in ◄─── Pico GPIO15                ││
│  │       │                                               ││
│  │       └──► iocontrol.0.emc-enable-in                 ││
│  │                                                        ││
│  │  Software E-stop Chain:                               ││
│  │  vibration.estop-trigger ──► halui.estop.activate    ││
│  └────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
                                        │
┌───────────────────────────────────────┼─────────────────────┐
│       Layer 4: User Interface         │                     │
│                                       │                     │
│  ┌────────────────────────────────────▼──────────────────┐ │
│  │  Web Dashboard (WiFi Optional)                        │ │
│  │  http://pico-vibmon.local                             │ │
│  │                                                        │ │
│  │  WebSocket Connection (live data)                     │ │
│  │  ├─ Real-time vibration plot                         │ │
│  │  ├─ Status indicator                                 │ │
│  │  └─ Alert notifications                              │ │
│  │                                                        │ │
│  │  REST API (configuration)                             │ │
│  │  ├─ GET  /api/config                                 │ │
│  │  ├─ POST /api/config                                 │ │
│  │  └─ GET  /api/status                                 │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## 🔄 Data Flow

### Critical Path (Safety - <1ms latency)

```
[MPU6050] 100Hz sample
    ↓ I2C read (400kHz)
[Pico Core 0] Calculate acceleration magnitude
    ↓
[Threshold Check] if (accel > EMERGENCY_THRESHOLD)
    ↓
[GPIO15] Set LOW (pull-down)
    ↓ <100µs
[LinuxCNC Parallel Port] Read E-stop pin
    ↓ Hardware interrupt
[LinuxCNC Motion] IMMEDIATE STOP
```

### Data Logging Path (Non-Critical - ~10ms latency)

```
[Pico Core 0] Sensor data
    ↓ Inter-core FIFO
[Pico Core 1] Format as CSV
    ↓ USB Serial (115200 baud)
[Python HAL] pyserial.readline()
    ↓ Parse data
[CSV Logger] Buffered write to file
```

### Management Path (Non-Critical - 100ms+ latency)

```
[Web Browser] User clicks "Update Config"
    ↓ HTTP POST
[Pico WiFi] Receive JSON config
    ↓ Validate values
[Flash Storage] Save to LittleFS
    ↓ Apply changes
[Pico Core 0] Update thresholds in RAM
```

## 📊 State Machine

### Pico Firmware States

```
┌─────────────┐
│   BOOT      │
│ Init I2C    │
│ Load config │
└──────┬──────┘
       │
       ▼
┌─────────────┐     Sensor fail
│  INIT       │────────────────┐
│ Test sensor │                │
│ Calibrate   │                │
└──────┬──────┘                │
       │                       │
       │ Success               │
       ▼                       │
┌─────────────┐                │
│   READY     │                │
│ Waiting...  │                │
└──────┬──────┘                │
       │                       │
       │ Start signal          │
       ▼                       │
┌─────────────┐  Vib > WARN    │
│  MONITORING │───────────┐    │
│ Reading     │           │    │
│ @ 100Hz     │           ▼    │
└──────┬──────┘     ┌──────────▼──┐
       │            │   WARNING   │
       │            │ Yellow LED  │
       │            └──────┬──────┘
       │ Vib > CRIT        │
       │                   │ Vib normal
       ▼                   │
┌─────────────┐            │
│  CRITICAL   │            │
│  Red LED    │◄───────────┘
└──────┬──────┘
       │
       │ Vib > EMERGENCY
       ▼
┌─────────────┐
│   E-STOP    │
│ GPIO LOW    │
│ Serial msg  │
│ HALT        │
└─────────────┘
       │
       │ Manual reset required
       ▼
   [BOOT]
```

## 🔐 Safety Mechanisms

### 1. Watchdog Timer
```cpp
// Pico Core 0 resets watchdog every cycle
void loop_core0() {
  watchdog_update();  // Must be called < 1 second
  
  read_sensor();
  check_thresholds();
  
  if (!watchdog_caused_reboot()) {
    // Normal operation
  } else {
    // System recovered from hang
    trigger_emergency_stop();
  }
}
```

### 2. Fail-Safe GPIO
```
GPIO15 Configuration:
- Internal pull-up enabled (default HIGH)
- Active LOW trigger
- On disconnect/crash: pin floats HIGH → E-stop triggered
- Normal operation: Pico actively drives HIGH
- E-stop condition: Pico drives LOW
```

### 3. USB Serial Timeout
```python
# Python HAL component
SERIAL_TIMEOUT = 1.0  # seconds

while running:
    try:
        data = ser.readline(timeout=SERIAL_TIMEOUT)
        last_seen = time.time()
    except:
        # No data received
        if time.time() - last_seen > SERIAL_TIMEOUT:
            # Connection lost - trigger software E-stop
            hal['estop-trigger'] = True
```

### 4. Dual Threshold System
```
Threshold Levels:
├─ INFO     (< 1.0G)  : Normal operation
├─ WARNING  (1.0-2.0G): Log event, yellow LED
├─ CRITICAL (2.0-4.0G): Red LED, reduce feed
└─ EMERGENCY (> 4.0G) : E-STOP triggered

Hysteresis: 0.2G to prevent oscillation
```

## 💾 Data Structures

### Sensor Data Packet (Pico → PC)
```c
struct SensorData {
  uint32_t timestamp_ms;
  float accel_x;    // m/s² 
  float accel_y;
  float accel_z;
  float gyro_x;     // rad/s
  float gyro_y;
  float gyro_z;
  float magnitude;  // √(ax² + ay² + az²)
  uint8_t status;   // OK/WARNING/CRITICAL/EMERGENCY
};

// Serialized as CSV:
// timestamp,ax,ay,az,gx,gy,gz,mag,status\n
```

### Configuration (JSON in Flash)
```json
{
  "version": 1,
  "sensor": {
    "sample_rate": 100,
    "i2c_address": "0x68",
    "accel_range": 4,
    "gyro_range": 500
  },
  "thresholds": {
    "warning": 2.0,
    "critical": 4.0,
    "emergency": 6.0,
    "hysteresis": 0.2
  },
  "estop": {
    "gpio_pin": 15,
    "active_low": true,
    "usb_enabled": true
  },
  "network": {
    "wifi_enabled": true,
    "mode": "AP",
    "ssid": "CNC-VibMon",
    "password": "changeme"
  }
}
```

## 🔌 Interface Specifications

### USB Serial Protocol

**Baud Rate**: 115200  
**Format**: CSV lines, newline terminated  
**Direction**: Bidirectional

**Pico → PC (Data Stream)**
```
# Header (sent once on boot)
VIB:HEADER,timestamp,ax,ay,az,gx,gy,gz,mag,status

# Data (100 Hz)
VIB:DATA,1234567,0.12,0.45,-9.81,0.01,0.02,0.00,9.83,OK
VIB:DATA,1234577,0.15,0.48,-9.79,0.02,0.01,0.01,9.81,OK

# Events
VIB:WARNING,1234670,2.3
VIB:CRITICAL,1234780,4.5
VIB:ESTOP,1234790,6.8

# Status
VIB:STATUS,connected,v1.0.0,192.168.4.1
```

**PC → Pico (Commands)**
```
CMD:GET_CONFIG
CMD:SET_THRESHOLD,warning,2.5
CMD:SET_THRESHOLD,emergency,7.0
CMD:RESET
CMD:CALIBRATE
```

### WiFi WebSocket Protocol

**Port**: 81  
**Format**: JSON  
**Update Rate**: 10 Hz (reduced from sensor rate)

```javascript
// Server → Client (live data)
{
  "type": "data",
  "timestamp": 1234567890,
  "vibration": {
    "current": 1.23,
    "peak": 2.45,
    "status": "OK"
  },
  "accel": [0.12, 0.45, -9.81],
  "gyro": [0.01, 0.02, 0.00]
}

// Server → Client (event)
{
  "type": "event",
  "level": "WARNING",
  "timestamp": 1234567890,
  "value": 2.3
}

// Client → Server (config update)
{
  "type": "config",
  "thresholds": {
    "warning": 2.0,
    "critical": 4.0
  }
}
```

### HAL Pin Interface

```
vibration.current        (float out) - Current vibration level (G)
vibration.peak           (float out) - Peak since last reset
vibration.rms            (float out) - RMS over last second
vibration.status         (s32 out)   - 0=OK, 1=WARN, 2=CRIT, 3=ESTOP
vibration.estop-trigger  (bit out)   - Software E-stop signal
vibration.connected      (bit out)   - USB connection status
vibration.threshold-warn (float in)  - Warning threshold (runtime adjust)
vibration.threshold-crit (float in)  - Critical threshold
vibration.enable         (bit in)    - Enable monitoring
vibration.reset-peak     (bit in)    - Reset peak value
```

## ⚡ Performance Requirements

| Metric | Target | Critical |
|--------|--------|----------|
| Sample Rate | 100 Hz | > 50 Hz |
| E-stop Latency | < 10 ms | < 100 ms |
| USB Data Rate | 100 packets/s | > 10 packets/s |
| WiFi Update | 10 Hz | Best effort |
| CPU Core 0 | < 80% | < 95% |
| CPU Core 1 | Any | Any |
| RAM Usage | < 200 KB | < 240 KB |
| Flash Storage | < 1 MB | < 2 MB |

## 🔄 Update Strategy

### Firmware Updates
1. **Via USB** (recommended)
   - Hold BOOTSEL button
   - Drag UF2 file
   - Auto-reboot

2. **OTA via WiFi** (future)
   - Upload via web interface
   - Verify checksum
   - Flash update
   - Watchdog-protected

### Configuration Updates
1. **Web Interface** - Instant apply
2. **USB Serial** - Send CMD:SET_*
3. **Config File** - Upload JSON via web

## 📝 Error Handling

### Sensor Failures
```
I2C Communication Fail:
├─ Retry 3x with backoff
├─ If persistent: Enter ERROR state
├─ Trigger E-stop (fail-safe)
└─ Log error via USB/WiFi
```

### Connection Loss
```
USB Disconnect:
├─ Core 0: Continue sensor reading (safety)
├─ Core 1: Buffer last 1000 samples
└─ On reconnect: Flush buffer, resume

WiFi Disconnect:
├─ No impact on safety
└─ Auto-reconnect in background
```

### Power Issues
```
Brownout Detection:
├─ Trigger immediate E-stop
├─ Save critical state to flash
└─ Watchdog will reset system
```

---

**Last Updated**: 2026-01-01  
**Version**: 1.0 (Concept)
