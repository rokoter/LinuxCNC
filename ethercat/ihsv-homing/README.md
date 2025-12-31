# IHSV57/60-EC EtherCAT LinuxCNC Configuration

Working LinuxCNC configuration for JMC IHSV57/60-EC integrated servo motors with EtherCAT communication.

## Hardware Setup

- **Motor**: JMC IHSV57/60-EC (Vendor ID: 0x66668888, Product Code: 0x2019a301)
- **Communication**: EtherCAT via RJ45
- **Test machine**: TTC450 Z-axis (4mm lead screw)
- **Encoder**: 1000 line (4000 counts/rev in quadrature mode)

## Key Configuration Details

### Motor Scale Calculation
```
SCALE = encoder counts per revolution / lead screw pitch
SCALE = 4000 / 4mm = 1000 counts/mm
```

Set in `cia402-ihsv-home-variant.hal`:
```hal
setp cia402.0.pos-scale 1000
```

### Home Switch Configuration

**Important**: We use **Pin 5 (DI3)** instead of the dedicated home/limit pins (Pin 2/3/4).

**Why?** The IHSV motor has internal limit switch handling that cannot be easily disabled via SDO. When using the dedicated limit pins (CW-, HW+, CCW+), the motor firmware stops movement internally, causing following errors in LinuxCNC.

**Solution**: Use Pin 5 (DI3 - Probe 1 input) which has no special motor-internal function.

#### Pin Mapping (0x60FD Digital Inputs)
```
Bit 0 = Pin 2 (CW-)   - Positive limit (has motor-internal function)
Bit 1 = Pin 4 (CCW+)  - Negative limit (has motor-internal function)  
Bit 2 = Pin 3 (HW+)   - Home switch (has motor-internal function)
Bit 9 = Pin 5 (DI3)   - Probe 1 (NO motor-internal function) ✓ Used for homing
```

#### Wiring
```
+5V ──[Switch]──► Pin 5 (DI3)
GND ────────────► Pin 1 (COM)
```

### Homing Sequence

The configuration uses LinuxCNC homing sequence 1 (same sign for search and latch velocities):

```ini
HOME = 3                    # Final position after homing (3mm from origin)
HOME_OFFSET = -0.5          # Switch is 0.5mm before machine origin
HOME_SEARCH_VEL = -10       # Search towards negative direction at 10mm/s
HOME_LATCH_VEL = -2         # Precise latch at 2mm/s (same direction)
HOME_IGNORE_LIMITS = YES    # Required when using shared switch
HOME_IS_SHARED = 1          # Indicates shared home/limit switch
```

**Homing behavior:**
1. Move left at 10mm/s until switch activates
2. Back off from switch
3. Slowly approach switch again at 2mm/s for precise position
4. Move to HOME position (3mm)

### Soft Limits Only

Hardware limit switches are disabled. The machine relies on software limits:
```ini
MIN_LIMIT = 0
MAX_LIMIT = 80
```

For production use, consider adding separate limit switches on different pins.

## Files Overview

### Core Configuration
- `ethercat-conf-ihsv.xml` - EtherCAT slave configuration with PDO mappings
- `cia402-ihsv-home-variant.hal` - HAL connections for motor, homing, and I/O
- `cia402-ihsv-home-variant.ini` - Machine parameters, limits, and homing sequence
- `tool.tbl` - Tool table (required to prevent startup error)

### Documentation
- `schroefas-kalibratie.txt` - Lead screw calibration guide (Dutch)
- `corrected-pinmapping.txt` - Pin mapping reference

## Velocity Settings

Current safe settings for testing:
```ini
MAX_VELOCITY = 100           # 100 mm/s
MAX_ACCELERATION = 500       # 500 mm/s²
DEFAULT_LINEAR_VELOCITY = 10 # Default for G1 without F word
```

For G-code feed rates, remember: **F is in mm/min**
- F6000 = 100 mm/s (maximum)
- F3000 = 50 mm/s
- F1200 = 20 mm/s

## Quick Start

1. Copy files to LinuxCNC config directory
2. Connect motor to EtherCAT master
3. Wire home switch to Pin 5 (DI3) and Pin 1 (COM)
4. Start LinuxCNC:
```bash
linuxcnc ~/linuxcnc/configs/ihsv-homing/cia402-ihsv-home-variant.ini
```
5. Home the machine (motor must start right of the switch)
6. Test with MDI: `G90 G0 X80`

## Troubleshooting

### "Joint following error" during homing
- Cause: Motor stops internally due to limit pin activation
- Solution: Use Pin 5 (DI3) instead of dedicated home/limit pins

### Home switch not detected
- Check in halshow: `lcec.0.0.in-probe1` should go TRUE when switch closes
- Verify wiring: +5V to switch, switch to Pin 5, Pin 1 to GND

### SDO download errors (0x2007)
- Expected - motor parameters are read-only in some firmware versions
- Configuration works without SDO changes when using Pin 5

## Adding Multiple Axes

To add Y/Z axes:
1. Add slave entries in `ethercat-conf-ihsv.xml`
2. Duplicate motor sections in HAL file
3. Add JOINT_1, JOINT_2 sections in INI file
4. Update TRAJ COORDINATES and KINS JOINTS

## Production Recommendations

- [ ] Add separate limit switches on Pin 2 and Pin 4
- [ ] Calibrate SCALE precisely using actual measurement
- [ ] Tune acceleration for your mechanical setup
- [ ] Add E-stop circuit
- [ ] Test position accuracy over full travel range

## References

- [LinuxCNC Homing Configuration](https://linuxcnc.org/docs/html/config/ini-homing.html)
- [IHSV-EC Manual](https://www.jmc-motor.com/) - Parameter P2-07 for DI function selection
- [lcec EtherCAT HAL driver](https://github.com/linuxcnc-ethercat/linuxcnc-ethercat)

## License

Configuration files are provided as-is for educational and personal use.

## Credits

Configuration developed and tested on LinuxCNC 2.9.7 with IHSV57-30-80-EC motor.