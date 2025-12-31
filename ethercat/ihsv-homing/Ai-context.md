# LinuxCNC IHSV EtherCAT Setup - AI Context Document

## Project Overview

Working LinuxCNC 2.9.7 configuration for JMC IHSV57/60-EC integrated EtherCAT servo motors. This document provides context for AI assistants to help with this setup.

## Hardware Configuration

### Motor Details
- **Model**: JMC IHSV57/60-EC integrated servo motor
- **Communication**: EtherCAT (100Mbps)
- **Vendor ID**: 0x66668888
- **Product Code**: 0x2019a301
- **Encoder**: 1000 line incremental encoder (4000 counts/rev in quadrature)
- **Protocol**: CIA402 motion control protocol
- **Connector**: 10-pin control signal port (CN1)

### Mechanical Setup
- **Test machine**: TTC450 Z-axis repurposed as X-axis for testing
- **Lead screw**: 4mm pitch (4mm travel per revolution)
- **Travel range**: 80mm (MIN_LIMIT=0, MAX_LIMIT=80)
- **Current SCALE**: 1000 counts/mm (verified accurate)

### EtherCAT Configuration
- **Master**: LinuxCNC built-in EtherCAT master
- **Driver**: lcec (LinuxCNc EtherCAT)
- **Cycle time**: 1ms (1000000ns)
- **Control mode**: CSP (Cyclic Synchronous Position mode)

## Critical Configuration Details

### Pin Mapping Issue - IMPORTANT!

**The motor has internal limit switch handling that causes problems.**

When using the dedicated limit/home pins (Pin 2/CW-, Pin 3/HW+, Pin 4/CCW+), the motor firmware stops internally when these pins activate, causing LinuxCNC "following error" faults.

**Solution**: Use **Pin 5 (DI3 - Probe 1 input)** for the home switch because it has NO motor-internal function.

#### CN1 10-Pin Connector Pinout
```
Pin 1  (COM)   - Common (GND)
Pin 2  (CW-)   - Clockwise limit (do NOT use - has motor-internal function)
Pin 3  (HW+)   - Home switch (do NOT use - has motor-internal function)
Pin 4  (CCW+)  - Counter-clockwise limit (do NOT use - has motor-internal function)
Pin 5  (DI3)   - Probe 1 input (USE THIS for home switch - no motor-internal function)
Pin 6  (DI4)   - Probe 2 input
Pin 7  (DO0+)  - Alarm output +
Pin 8  (DO0-)  - Alarm output -
Pin 9  (DO1+)  - In-place output +
Pin 10 (DO1-)  - In-place output -
```

#### Digital Input Bit Mapping (0x60FD)
Tested and verified with halshow:
```
Bit 0  = Pin 2 (CW-)   → lcec.0.0.in-positive-limit
Bit 1  = Pin 4 (CCW+)  → lcec.0.0.in-negative-limit
Bit 2  = Pin 3 (HW+)   → lcec.0.0.in-home
Bit 9  = Pin 5 (DI3)   → lcec.0.0.in-probe1 ← USED FOR HOMING
```

### Current Wiring
```
+5V external ──[NO Switch]──► Pin 5 (DI3)
GND ───────────────────────► Pin 1 (COM)
```

## File Structure

### Active Configuration Files
Located in `~/linuxcnc/configs/ihsv-homing/`:

1. **ethercat-conf-ihsv.xml**
   - EtherCAT slave configuration
   - PDO mappings for RxPDO (0x1600) and TxPDO (0x1A00)
   - Bit mapping for digital inputs (0x60FD) with Pin 5 as in-probe1

2. **cia402-ihsv-home-variant.hal**
   - HAL connections between EtherCAT, CIA402, and motion components
   - Uses `lcec.0.0.in-probe1` for homing (Pin 5)
   - Hardware limits are DISABLED (soft limits only)
   - pos-scale set to 1000

3. **cia402-ihsv-home-variant.ini**
   - Machine configuration with 1 joint (X-axis)
   - Homing sequence: HOME=3, HOME_OFFSET=-0.5
   - Velocities: MAX_VELOCITY=100, MAX_ACCELERATION=500
   - Soft limits: MIN_LIMIT=0, MAX_LIMIT=80

4. **tool.tbl**
   - Minimal tool table to prevent startup error

### Documentation Files
- README.md - User-facing documentation
- schroefas-kalibratie.txt - Lead screw calibration guide (Dutch)
- corrected-pinmapping.txt - Pin mapping reference

## Current Parameter Values

### Motion Parameters
```ini
[TRAJ]
DEFAULT_LINEAR_VELOCITY = 10    # mm/s
MAX_LINEAR_VELOCITY = 100       # mm/s

[AXIS_X] and [JOINT_0]
MAX_VELOCITY = 100              # mm/s
MAX_ACCELERATION = 500          # mm/s²
STEPGEN_MAXVEL = 125           # 25% higher
STEPGEN_MAXACCEL = 625         # 25% higher
```

### Homing Parameters
```ini
HOME = 3                        # Final homed position
HOME_OFFSET = -0.5              # Switch location relative to origin
HOME_SEQUENCE = 0
HOME_SEARCH_VEL = -10          # Search velocity (negative = left)
HOME_LATCH_VEL = -2            # Latch velocity (same sign as search)
HOME_IGNORE_LIMITS = YES
HOME_USE_INDEX = NO
HOME_IS_SHARED = 1             # Shared home/limit configuration
```

### CIA402 Parameters
```hal
setp cia402.0.csp-mode 1       # Cyclic Synchronous Position mode
setp cia402.0.pos-scale 1000   # counts/mm (verified accurate)
```

## Known Issues and Solutions

### Issue: "Joint following error" during homing
- **Cause**: Motor internal limit switch handling stops motor before LinuxCNC
- **Solution**: Use Pin 5 (DI3) instead of dedicated home/limit pins
- **Status**: RESOLVED

### Issue: SDO download errors (0x2007:0x02, abort_code 06020000)
- **Cause**: Attempted to disable motor-internal limit functions via SDO
- **Why it fails**: These parameters are read-only or don't exist in this firmware
- **Solution**: Not needed when using Pin 5 (DI3) which has no motor-internal function
- **Status**: WORKAROUND IMPLEMENTED

### Issue: Switch on Pin 5 not detected in halshow
- **Cause**: Incorrect bit position in XML (was bit 16, actually bit 9)
- **Solution**: Verified with debug XML mapping all 32 bits individually
- **Status**: RESOLVED

## Tested and Working Features

✅ EtherCAT communication (motor reaches OPERATIONAL state)
✅ Position control (verified 80mm = exactly 80mm with measuring tool)
✅ Homing sequence (search, back-off, latch, final move)
✅ Jogging in both directions
✅ MDI commands (G0, G1 with various feed rates)
✅ G-code programs with loops and variable speeds
✅ Soft limits (MIN=0, MAX=80)

## Common User Questions

### "Why not use the dedicated home switch pin?"
The motor has firmware-level limit handling that cannot be disabled via SDO. Using dedicated pins causes the motor to stop internally, leading to following errors.

### "How do I add hardware limits?"
For production, add separate limit switches on unused pins (Pin 6 DI4, or external I/O module). Current config uses soft limits only.

### "How do I calibrate the scale?"
Current SCALE=1000 is verified accurate. If needed: measure actual travel for a commanded distance, then:
`New SCALE = Current SCALE × (Commanded / Measured)`

### "Can I increase speed?"
Yes. Increase MAX_VELOCITY and MAX_ACCELERATION in both [AXIS_X] and [JOINT_0] sections. Remember to increase STEPGEN values by 25%. Test incrementally.

### "Why does F1000 seem slow?"
F values are in mm/min, not mm/s. F6000 = 100mm/s (current maximum).

## Expansion Plans

### Adding More Axes
To add Y or Z motors:
1. Add slave entries in XML (idx="1", idx="2", etc.)
2. Duplicate motor section in HAL (cia402.1, cia402.2)
3. Add JOINT_1, JOINT_2 in INI
4. Update COORDINATES and JOINTS count
5. Each axis needs its own home switch

### Production Improvements
- [ ] Add hardware limit switches on separate pins
- [ ] Tune acceleration for actual mechanical load
- [ ] Add E-stop circuit
- [ ] Consider closed-loop tuning if needed
- [ ] Test full travel range under load

## Useful Commands

### Diagnostics
```bash
# Check EtherCAT slave status
sudo ethercat slaves

# View PDO mapping
ethercat pdos

# Monitor HAL pins
halshow

# Watch specific pin
watch -n 0.1 'halcmd show pin lcec.0.0.in-probe1'
```

### Testing
```bash
# Start LinuxCNC
linuxcnc ~/linuxcnc/configs/ihsv-homing/cia402-ihsv-home-variant.ini

# MDI commands
G90 G0 X80    # Rapid to 80mm
G90 G0 X0     # Return to origin
G1 X50 F6000  # Linear move at 100mm/s
```

## Reference Documents

- LinuxCNC Homing: https://linuxcnc.org/docs/html/config/ini-homing.html
- CIA402 Standard: IEC 61800-7-201 for motion control
- IHSV Manual: Parameter P2-07 controls DI port functions
- lcec driver: https://github.com/linuxcnc-ethercat/linuxcnc-ethercat

## Session History Summary

This configuration was developed through iterative testing:
1. Basic EtherCAT communication established
2. Pin mapping verified using halshow and debug XML
3. Discovered motor-internal limit handling issue
4. Switched from Pin 2/3/4 to Pin 5 (DI3) for homing
5. Tuned homing sequence (search + latch velocities)
6. Verified position accuracy (SCALE=1000 confirmed)
7. Tested various motion patterns and speeds

**Current Status**: Fully functional single-axis test configuration, ready for expansion to multi-axis machine.

---

## Notes for AI Assistants

When helping with this setup:
- ALWAYS remember Pin 5 (DI3/in-probe1) is used for homing, NOT the dedicated pins
- Motor-internal limit handling is the key issue that drove this design choice
- User prefers concise, practical answers over lengthy explanations
- Configuration is in Dutch locale but prefer English for technical docs
- This is a test setup on a TTC450, final machine will be different
- User is experienced enough to edit config files directly
- Focus on LinuxCNC/EtherCAT/motion control specifics, not basic CNC concepts