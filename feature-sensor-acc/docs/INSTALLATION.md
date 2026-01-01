# Installation Guide - CNC Vibration Monitor

## 📋 Prerequisites

### Hardware Required
- ✅ RP2040 Pico W (or regular Pico if no WiFi needed)
- ✅ MPU6050 or ADXL345 IMU sensor module
- ✅ USB cable (Micro-USB or USB-C depending on Pico)
- ✅ 4 jumper wires (for I2C connection)
- ✅ 2 wires for GPIO E-stop connection
- ✅ Soldering equipment (for headers if not pre-soldered)
- 📦 Optional: 3D printed enclosure

### Software Required
- ✅ LinuxCNC 2.8 or newer
- ✅ Python 3.7+
- ✅ Arduino IDE 2.x OR PlatformIO
- ✅ USB drivers (usually auto-detected on Linux)

## 🔧 Step 1: Hardware Assembly

### 1.1 Prepare the Pico W

If your Pico doesn't have headers:
```bash
1. Solder pin headers to Pico W
   - Use 40-pin male headers (2x 20-pin)
   - Ensure good solder joints for I2C reliability
   - Double-check pin alignment
```

### 1.2 Connect MPU6050 to Pico

**Standard Wiring:**
```
MPU6050    →    Pico W
────────────────────────
VCC        →    3.3V (Pin 36)
GND        →    GND  (Pin 38 or any GND)
SDA        →    GP4  (Pin 6)
SCL        →    GP5  (Pin 7)
```

**Important Notes:**
- ⚠️ Use 3.3V, NOT 5V! MPU6050 is 3.3V device
- Keep I2C wires SHORT (< 30cm for reliability)
- Twist SDA/SCL together to reduce interference
- Use quality jumper wires or solder connections

### 1.3 E-stop GPIO Connection

Connect Pico to LinuxCNC E-stop input:

**For Parallel Port:**
```
Pico W GP15 (Pin 20)  →  Parallel Port Pin 15 (Input)
Pico W GND            →  Parallel Port GND
```

**For Mesa Cards (e.g., 7i76e):**
```
Pico W GP15 (Pin 20)  →  Mesa input pin (e.g., 7i76.0.0.input-00)
Pico W GND            →  Mesa GND
```

**Wiring Details:**
- GP15 normally HIGH (3.3V)
- E-stop condition: GP15 goes LOW (0V)
- Use shielded cable if distance > 1 meter
- Add 10kΩ pull-up resistor on LinuxCNC side if needed

### 1.4 Physical Mounting

**Recommended Location: Z-axis carriage near spindle**

Reasons:
- Maximum vibration measurement (most movement)
- Detects spindle-related issues
- Captures cutting force vibrations

**Mounting Options:**

**Option A: 3D Printed Enclosure**
```bash
# Print the enclosure STL files
cd hardware/enclosures/
# Print pico-case.stl and sensor-mount.stl
# Use PLA or PETG, 0.2mm layer height, 20% infill
```

**Option B: Simple Bracket**
- Use zip ties or small screws
- Ensure sensor is rigidly mounted (not floating)
- Orient sensor axes with machine axes if possible

**Cable Management:**
```
1. Route USB cable along existing cable bundle
2. Use cable chain/drag chain for Z-axis movement
3. Leave enough slack for full Z travel
4. Secure cables to prevent snagging
```

## 💻 Step 2: Firmware Installation

### Option A: Using Arduino IDE (Easier)

**2.1 Install Arduino IDE**
```bash
# Download from arduino.cc
# Or via package manager:
sudo snap install arduino
```

**2.2 Add RP2040 Board Support**
```
1. Arduino IDE → File → Preferences
2. Additional Boards Manager URLs:
   https://github.com/earlephilhower/arduino-pico/releases/download/global/package_rp2040_index.json
3. Tools → Board → Boards Manager
4. Search "pico"
5. Install "Raspberry Pi Pico/RP2040" by Earle F. Philhower, III
```

**2.3 Install Libraries**
```
Sketch → Include Library → Manage Libraries
Search and install:
  - Adafruit MPU6050
  - Adafruit Unified Sensor
  - Adafruit BusIO
  - ArduinoJson
  - ESPAsyncWebServer (if using WiFi)
```

**2.4 Upload Firmware**
```
1. Open pico-firmware.ino in Arduino IDE
2. Tools → Board → Raspberry Pi Pico W
3. Tools → Port → Select your Pico (e.g., /dev/ttyACM0)
4. Upload button (→)
5. Wait for "Done uploading"
```

### Option B: Using PlatformIO (Advanced)

**2.1 Install PlatformIO**
```bash
# Via VS Code extension, or CLI:
pip install platformio
```

**2.2 Build and Upload**
```bash
cd hardware/pico-firmware/
pio run --target upload
```

**2.3 Monitor Serial Output**
```bash
pio device monitor --baud 115200
```

## 🐧 Step 3: LinuxCNC Software Setup

### 3.1 Install Python Dependencies

```bash
# Navigate to software directory
cd software/hal-monitor/

# Install required packages
pip3 install -r requirements.txt

# Or manually:
pip3 install pyserial numpy matplotlib scipy pandas
```

### 3.2 Configure Serial Port Permissions

```bash
# Add your user to dialout group for serial access
sudo usermod -a -G dialout $USER

# Log out and back in for changes to take effect
# Or use: newgrp dialout

# Verify serial port
ls -l /dev/ttyACM*
# Should show: crw-rw---- 1 root dialout ...
```

### 3.3 Test HAL Component Standalone

```bash
# Make script executable
chmod +x vibration_monitor.py

# Test without LinuxCNC (requires halrun)
halrun

# In halrun shell:
loadusr -W vibration_monitor.py --port /dev/ttyACM0

# In another terminal:
halcmd show pin vibration
# Should show all pins

# Check for data:
halcmd show pin vibration.current
# Should update ~100 times/second

# Exit halrun:
exit
```

### 3.4 Copy Files to LinuxCNC Config

```bash
# Find your LinuxCNC config directory
# Usually: ~/linuxcnc/configs/your-machine-name/

# Copy HAL component
cp vibration_monitor.py ~/linuxcnc/configs/your-machine-name/
chmod +x ~/linuxcnc/configs/your-machine-name/vibration_monitor.py

# Copy config files
cp ../../config/*.json ~/linuxcnc/configs/your-machine-name/
```

### 3.5 Modify HAL Configuration

```bash
# Edit your custom HAL file
nano ~/linuxcnc/configs/your-machine-name/custom.hal

# Add lines from config/hal-config-example.hal
# At minimum, add:

# Load vibration monitor
loadusr -W vibration_monitor.py --port /dev/ttyACM0

# Wire hardware E-stop
net hw-estop parport.0.pin-15-in => iocontrol.0.emc-enable-in

# Wire software E-stop (backup)
net sw-estop vibration.estop-trigger => halui.estop.activate

# Enable monitoring
setp vibration.enable true
setp vibration.threshold-warn 2.0
setp vibration.threshold-crit 4.0

# Save and close (Ctrl+X, Y, Enter)
```

## 🧪 Step 4: Testing

### 4.1 Initial Power-On Test

```bash
# Connect Pico via USB to PC
# LED on Pico should blink during boot

# Check serial output
screen /dev/ttyACM0 115200
# Or: minicom -D /dev/ttyACM0 -b 115200

# Should see:
# VIB:BOOT,Vibration Monitor Starting...
# VIB:STATUS,Core 0 initialized - Safety monitoring active
# VIB:HEADER,timestamp,ax,ay,az,gx,gy,gz,mag,status
# VIB:DATA,1234,0.12,0.45,-9.81,0.01,0.02,0.00,1.05,OK

# Press Ctrl+A then K to exit screen
```

### 4.2 Sensor Validation

```bash
# Gently tap the sensor
# You should see:
# VIB:DATA values jump up temporarily
# VIB:WARNING message if > 2.0G

# Shake sensor vigorously
# Should see:
# VIB:CRITICAL or VIB:ESTOP messages
# Status LED changes color
```

### 4.3 E-stop Test (IMPORTANT!)

```bash
# With LinuxCNC NOT running:

# Test GPIO E-stop pin
# 1. Measure voltage on GP15: should be ~3.3V
# 2. Trigger software E-stop via serial:
#    echo "CMD:ESTOP" > /dev/ttyACM0
# 3. Voltage should drop to 0V
# 4. Manually reset Pico to clear

# Test with LinuxCNC:
# 1. Start LinuxCNC
# 2. Home machine
# 3. Shake sensor hard
# 4. Machine should E-stop immediately
# 5. Check logs in vibration_log_*.csv
```

### 4.4 HAL Pin Verification

```bash
# With LinuxCNC running
halcmd show pin vibration

# Should show:
# vibration.current    (float, OUT): <current vibration level>
# vibration.peak       (float, OUT): <peak value>
# vibration.status     (s32, OUT): 0 (OK)
# vibration.connected  (bit, OUT): 1 (TRUE)
# ...

# Watch pins update in real-time
halmeter
# Select vibration.current from list
# Move machine, watch values change
```

## 🌐 Step 5: WiFi Setup (Optional)

### 5.1 Configure WiFi Settings

```bash
# Edit network config
nano config/network.json

# For Access Point mode (default):
{
  "mode": "AP",
  "access_point": {
    "ssid": "CNC-VibMon",
    "password": "your-secure-password-here"
  }
}

# Save and re-upload firmware
```

### 5.2 Access Web Interface

```bash
# After Pico boots with WiFi enabled:

# Connect laptop/tablet to "CNC-VibMon" WiFi network
# Password: (your configured password)

# Open browser to:
http://192.168.4.1

# Or use mDNS:
http://pico-vibmon.local

# You should see web dashboard
```

## ✅ Verification Checklist

- [ ] Pico powers on and LED blinks
- [ ] Serial output shows sensor data @ ~100Hz
- [ ] Tapping sensor causes vibration spike in data
- [ ] E-stop GPIO pin changes state when triggered
- [ ] LinuxCNC HAL component loads without errors
- [ ] vibration.current updates in real-time
- [ ] Hardware E-stop halts LinuxCNC when triggered
- [ ] CSV log file is created with data
- [ ] (Optional) WiFi connects and web interface accessible
- [ ] Machine operates normally with monitor active

## 🔧 Troubleshooting

### Pico Not Detected
```bash
# Check USB connection
lsusb | grep -i pico
# Should show: "Raspberry Pi" device

# Check serial port
ls /dev/ttyACM*
# Should show /dev/ttyACM0 or similar

# Try different USB cable (data-capable, not charge-only)
```

### No Sensor Data
```bash
# Check I2C wiring (most common issue)
# Verify 3.3V power to sensor
# Check SDA/SCL not swapped

# Test I2C communication
# (Requires i2c-tools)
sudo apt-get install i2c-tools
i2cdetect -y 1
# Should show device at 0x68
```

### E-stop Not Triggering
```bash
# Verify GPIO15 wiring
# Test with multimeter: should be 3.3V normally, 0V when triggered
# Check HAL configuration for E-stop pin assignment
# Verify parport.0.pin-15-in is actually connected in HAL
```

### HAL Component Won't Load
```bash
# Check Python syntax
python3 vibration_monitor.py --port /dev/ttyACM0
# Should run without errors

# Check serial permissions
groups
# Should include 'dialout'

# Check HAL syntax
halrun -f custom.hal
# Will show errors if HAL file has issues
```

## 📚 Next Steps

After successful installation:
1. Read [CALIBRATION.md](CALIBRATION.md) to tune thresholds
2. Review [USAGE.md](USAGE.md) for daily operation
3. Run test patterns to establish baseline
4. Adjust thresholds based on your machine

## 🆘 Getting Help

If you encounter issues:
1. Check `docs/TROUBLESHOOTING.md`
2. Review serial output for error messages
3. Test components individually (sensor, HAL, WiFi)
4. Check LinuxCNC logs in `/var/log/linuxcnc.log`
