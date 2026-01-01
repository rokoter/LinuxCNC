# Hardware Setup Guide

## 📦 Bill of Materials (BOM)

| Component | Quantity | Est. Price | Notes |
|-----------|----------|------------|-------|
| RP2040 Pico W | 1 | €6-8 | WiFi version recommended |
| MPU6050 Module | 1 | €2-3 | 6-axis IMU (accel + gyro) |
| USB Cable | 1 | €2-5 | Micro-USB or USB-C (data capable) |
| Jumper Wires | 4 | €1 | Female-to-female for I2C |
| Wire for E-stop | 2m | €2 | 22-24 AWG, twisted pair |
| Pin Headers | 1 set | €1 | 40-pin (2x 20) if not pre-soldered |
| **Total** | - | **€14-22** | Approximate |

### Optional Components
- 3D printed enclosure (filament ~€1)
- Status LED (already on Pico, but can add external)
- Terminal blocks for secure connections
- Shielded cable for long E-stop runs

## 🔌 Wiring Diagram

### Complete Connection Map

```
┌─────────────────────────────────────────────────────────────┐
│                    RP2040 Pico W Pinout                     │
│                  (Top View, USB facing up)                  │
│                                                             │
│   ┌─────────────────────────────────────────────────┐      │
│   │                     USB Port                     │      │
│   └─────────────────────────────────────────────────┘      │
│                                                             │
│   GP0  ●  ● VBUS                  VBUS ●  ● GP27            │
│   GP1  ●  ● VSYS                  GND  ●  ● GP26            │
│   GND  ●  ● EN                    3V3E ●  ● RUN             │
│   GP2  ●  ● 3V3 ──────┐           3V3  ●  ● GP22 (SCL WiFi) │
│   GP3  ●  ● VREF      │                ●  ● GND             │
│   GP4  ●══════════════╪═══MPU SDA      ●  ● GP21 (SDA WiFi) │
│   GP5  ●══════════════╪═══MPU SCL      ●  ● GP20            │
│   GND  ●══════════════╪═══MPU GND      ●  ● GP19            │
│   GP6  ●  ●           └═══MPU VCC      ●  ● GP18            │
│   GP7  ●  ●                            ●  ● GND             │
│   GP8  ●  ●                            ●  ● GP17            │
│   GP9  ●  ●                            ●  ● GP16 (LED)      │
│   GND  ●  ●                            ●══● GP15 ══E-stop═╗ │
│   GP10 ●  ●                            ●  ● GP14 (Trig in) │ │
│   GP11 ●  ●                            ●  ● GND ═════════╗ │ │
│   GP12 ●  ●                            ●  ● GP13          │ │ │
│   GP13 ●  ●                        GND ●  ● AGND          │ │ │
│   GND  ●  ●                            ●  ● 3V3           │ │ │
│   GP14 ●  ● GP15                       ●  ● ADC_VREF      │ │ │
│                                                           │ │ │
└───────────────────────────────────────────────────────────┼─┼─┘
                                                            │ │
┌───────────────────────────────────────────────────────────┼─┼───┐
│                      MPU6050 Module                       │ │   │
├───────────────────────────────────────────────────────────┘ │   │
│                                                             │   │
│   ┌─────────┐                                              │   │
│   │  ○ VCC  │◄════════════════════════════════════════════┘   │
│   │  ○ GND  │◄════════════════════════════════════════════════┘
│   │  ○ SCL  │◄═══════════════════(GP5)
│   │  ○ SDA  │◄═══════════════════(GP4)
│   │  ○ XDA  │  (Not used)
│   │  ○ XCL  │  (Not used)
│   │  ○ AD0  │  (Leave floating or GND for 0x68 address)
│   │  ○ INT  │  (Optional - not used in this design)
│   └─────────┘
│
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│               LinuxCNC E-stop Connection                    │
│                                                             │
│   Pico W GP15 ────────┬─────► Parallel Port Pin 15 (In)    │
│                       │                                     │
│   Pico W GND ─────────┴─────► Parallel Port GND            │
│                                                             │
│   Alternative for Mesa cards:                              │
│   Pico W GP15 ────────────► Mesa 7i76.0.0.input-00        │
│   Pico W GND ─────────────► Mesa GND                       │
│                                                             │
└─────────────────────────────────────────────────────────────┘

Signal Details:
═══ Power lines (3.3V, GND)
─── Signal lines (I2C, GPIO)
```

## 📍 Pin Assignments

| Pico Pin | Signal | MPU6050 | LinuxCNC | Description |
|----------|--------|---------|----------|-------------|
| GP4 (Pin 6) | SDA | SDA | - | I2C Data |
| GP5 (Pin 7) | SCL | SCL | - | I2C Clock |
| 3.3V (Pin 36) | Power | VCC | - | 3.3V Supply |
| GND (Pin 38) | Ground | GND | GND | Common Ground |
| GP15 (Pin 20) | E-stop Out | - | E-stop In | Active LOW trigger |
| GP16 (Pin 21) | Status LED | - | - | Optional external LED |
| GP14 (Pin 19) | Trigger In | - | Optional | Sync signal from LinuxCNC |
| USB | Data + Power | - | USB Port | Serial data + 5V power |

## 🔧 Assembly Instructions

### Step 1: Prepare Components

1. **Check Pico W**
   - Verify it's the "W" model (WiFi) if you want WiFi features
   - Regular Pico works fine if WiFi not needed

2. **Check MPU6050 Module**
   - Most modules come ready to use
   - Some have pull-up resistors already installed
   - Verify it's 3.3V compatible (most are)

### Step 2: Solder Headers (if needed)

```
1. Insert 40-pin headers into Pico W
2. Place Pico in breadboard to hold headers straight
3. Solder all pins
4. Check for cold joints or bridges
5. Test with multimeter for shorts
```

### Step 3: I2C Connections

**Using Jumper Wires (Temporary/Testing):**
```
MPU6050 VCC  → Pico 3.3V (Pin 36)  [Red wire]
MPU6050 GND  → Pico GND (Pin 38)   [Black wire]
MPU6050 SDA  → Pico GP4 (Pin 6)    [Yellow/Green wire]
MPU6050 SCL  → Pico GP5 (Pin 7)    [Blue/White wire]
```

**For Permanent Installation (Soldered):**
```
1. Cut wires to appropriate length (10-30cm)
2. Tin all wire ends
3. Solder to Pico pin headers
4. Solder to MPU6050 module
5. Add heat shrink tubing for insulation
6. Test continuity with multimeter
```

**Best Practices:**
- Keep I2C wires SHORT (< 30cm ideal)
- Twist SDA and SCL together
- Keep away from power wires
- Use shielded cable if > 50cm

### Step 4: E-stop GPIO Connection

**For Parallel Port:**
```
Wire 1: Pico GP15 (Pin 20) → DB25 Pin 15 (Input 7)
Wire 2: Pico GND (any GND) → DB25 Pin 18-25 (GND)
```

**Wiring Tips:**
- Use twisted pair wire (Cat5 ethernet cable works well)
- Solder to DB25 connector pins or use crimp terminals
- Add ferrite bead if cable is long (>1m)
- Test with multimeter:
  - Normal: GP15 = 3.3V
  - E-stop: GP15 = 0V

**For Mesa Cards:**
```
Consult your Mesa card manual for input pin connections
Usually screw terminals, so no soldering needed
Example for 7i76e: Use any general purpose input
```

### Step 5: USB Connection

```
1. Use quality USB cable (not charge-only cable)
2. Connect Pico to LinuxCNC PC
3. Verify enumeration: ls /dev/ttyACM*
4. Should show /dev/ttyACM0 or similar
```

## 🏠 Physical Mounting

### Location Recommendations

**Best: Z-axis carriage near spindle**
- Maximum vibration amplitude
- Detects spindle issues
- Captures cutting forces
- Most critical axis

**Alternative: X or Y axis**
- Still useful data
- May miss vertical vibrations
- Good for gantry issues

**Not Recommended: Fixed frame**
- Minimal vibration
- Won't detect axis-specific issues

### Mounting Methods

**Option 1: 3D Printed Enclosure**
```
Files: hardware/enclosures/pico-case.stl
       hardware/enclosures/sensor-mount.stl

Print Settings:
- Material: PLA or PETG
- Layer height: 0.2mm
- Infill: 20%
- Supports: Yes (for screw holes)

Mounting:
1. Insert Pico + MPU6050 into case
2. Close lid
3. Mount to Z-axis carriage with M3 screws
```

**Option 2: Zip Ties + Foam**
```
1. Wrap Pico in anti-static foam
2. Use zip ties to secure to carriage
3. Ensure rigid mounting (no flex)
4. Protect from coolant/chips
```

**Option 3: Custom Bracket**
```
1. Bend sheet metal or cut acrylic
2. Drill mounting holes
3. Use standoffs for Pico
4. Secure to machine
```

### Cable Routing

```
Z-axis routing:
                  ┌─ PC (LinuxCNC)
                  │
            USB Cable (follows Z movement)
                  │
         ┌────────▼────────┐
         │  Cable Chain    │  ← Use existing cable management
         │                 │
         └────────┬────────┘
                  │
         ┌────────▼────────┐
         │    Pico W       │  ← On Z-carriage
         │    + MPU6050    │
         └─────────────────┘
                  │
         ┌────────▼────────┐
         │    Spindle      │  ← Near spindle for best data
         └─────────────────┘

Important:
- Leave slack for full Z travel (+ 10cm extra)
- Use cable chain or drag chain
- Avoid sharp bends
- Secure to prevent snagging
- Test full Z range before operation
```

## ✅ Testing & Verification

### Power-On Test

```bash
1. Connect USB cable only (no E-stop wire yet)
2. Pico LED should blink rapidly
3. Check serial output:
   screen /dev/ttyACM0 115200
   
4. Should see:
   VIB:BOOT,Vibration Monitor Starting...
   VIB:STATUS,Core 0 initialized
   VIB:HEADER,timestamp,ax,ay,az,...
   VIB:DATA,1234,0.12,0.45,-9.81,...
   
5. Tap sensor - values should spike
```

### I2C Connection Test

```bash
# Install i2c-tools if not present
sudo apt-get install i2c-tools

# Scan for MPU6050 (address 0x68)
# Note: This tests the Linux I2C, not Pico's
# Pico's I2C is internal and doesn't appear on Linux

# Check Pico serial output instead:
# Should see continuous VIB:DATA messages
# If stuck at "MPU6050 not found", check wiring
```

### E-stop GPIO Test

```bash
# With multimeter on GP15:
# Normal: 3.3V
# Shake sensor hard: Should drop to 0V briefly

# If doesn't trigger, check:
# - Firmware uploaded correctly
# - Threshold not too high
# - Sensor working (check serial data)
```

### Full System Test

```bash
1. Start LinuxCNC
2. Check HAL: halcmd show pin vibration
3. Move machine axes
4. Watch vibration.current update
5. Tap machine - should see spikes
6. Verify E-stop works when triggered
```

## 🔍 Troubleshooting Hardware

| Problem | Possible Cause | Solution |
|---------|---------------|----------|
| Pico not detected | Bad USB cable | Try different cable (must be data cable) |
| No sensor data | I2C wiring | Check SDA/SCL not swapped, verify 3.3V |
| Noisy readings | Poor grounding | Shorten wires, add ground wire |
| E-stop not working | GPIO wiring | Verify GP15 connection, check polarity |
| WiFi not working | Wrong Pico model | Verify it's Pico W (with WiFi chip) |
| Vibration too sensitive | Wrong threshold | Adjust in config, start higher |

## 📐 Mechanical Considerations

### Sensor Orientation

```
Recommended:
┌─────────┐
│ MPU6050 │  ← Z-axis (up/down) aligned with machine Z
│         │  ← X-axis aligned with machine X
│    ↑Z   │  ← Y-axis aligned with machine Y
│   X→    │
└─────────┘

Note: Orientation not critical - software calculates
total magnitude anyway. But alignment helps debugging.
```

### Vibration Isolation

**Do NOT isolate the sensor!**
- Mount rigidly to axis
- Want to measure actual vibration
- Rubber mounts will filter data

**Protect from:**
- Direct chip impact (use cover)
- Coolant (waterproof case)
- Thermal expansion (allow air flow)

## 📸 Example Installations

(Would include photos here in final version)

```
1. Z-axis mount next to spindle
2. Wiring through cable chain
3. Connection to parallel port
4. Complete assembled system
5. Alternative mounting options
```

## 🔗 Related Files

- `../pico-firmware/` - Firmware to upload
- `../../docs/INSTALLATION.md` - Software installation
- `../../config/` - Configuration files
- `enclosures/` - 3D printable cases (STL files)

---

**Safety Note:** Always disconnect power before wiring. Double-check polarity. Test E-stop function before regular use.
