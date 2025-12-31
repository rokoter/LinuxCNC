# LinuxCNC Control Panel - Mesa 7i96S

High-quality control panel voor LinuxCNC met motorized feed override fader.

## Hardware

### Components
- **Mesa 7i96S** - Ethernet FPGA I/O kaart
- **ALPS RSA0N11M9A0J** - 100mm motorized fader (hoogwaardige mixing console fader)
  - [Amazon link](https://www.amazon.nl/dp/B0FK222BQS)
- **Emergency stop button** - Met NC (Normally Closed) contact, vergrendeling
- **RGB illuminated button** - 19mm, 12-24V, momentary NO contact
  - [Amazon link](https://www.amazon.nl/dp/B097MQP582)
  - Gebruikt voor machine enable/disable
  - State indication via RGB LED (rood/groen)
- **Program start button** (toekomstig) - Aparte knop, mogelijk achter klepje voor veiligheid
- **24V power supply** - Voor Mesa kaart en motor driver
- **Motor driver** (optioneel) - Als fader motor meer stroom nodig heeft dan Mesa kan leveren
- **Resistors** - 3x 1.5kΩ - 2.2kΩ voor RGB LED stroombeperking

### ALPS RSA0N11M9 Specificaties
- **Stroke**: 100mm
- **Potentiometer**: 10kΩ linear
- **Motor**: DC motor, ~100mA
- **Voltage**: Potentiometer kan op 5V of 10V
- **Levensduur**: >100,000 cycles
- **Gebruikt in**: Yamaha, Allen & Heath, Behringer mixing consoles

## Pinout Schema

### Mesa 7i96S Terminal Blocks

```
TB2 - Digital I/O (24V logic)
═══════════════════════════════════════════════════
Pin   | Signal              | Connectie
------+---------------------+-------------------------
01    | GPIO 0 (Input)      | E-stop button (NC contact)
02    | GPIO 1 (Input)      | Enable/Start button (NO contact)
03    | GND                 | Button common
04    | +24V                | Pull-up voor inputs
05    | GPIO 5 (Output)     | RGB LED - RED channel*
06    | GPIO 6 (Output)     | RGB LED - GREEN channel*
07    | GPIO 7 (Output)     | RGB LED - BLUE channel* (reserve)
08    | PWM 0               | Fader motor PWM
09    | PWM 0 DIR           | Fader motor direction
10    | GPIO 3 (Output)     | E-stop status LED (optioneel)
11    | GPIO 4 (Output)     | Ready status LED (optioneel)
12    | GND                 | LED common / RGB common negative

* RGB LED via 1.5kΩ - 2.2kΩ current limiting resistors

TB3 - Analog Input
═══════════════════════════════════════════════════
Pin   | Signal              | Connectie
------+---------------------+-------------------------
14    | Analog 0+           | Fader potentiometer wiper
15    | Analog 0-           | GND
16    | +10V (of +5V)       | Fader pot high
17    | GND                 | Fader pot low
```

### ALPS Fader Pinout

```
ALPS RSA0N11M9 Connections:
═══════════════════════════════════════════════════

Potentiometer (6 pins op één kant):
  Pin 1: Potentiometer end (10kΩ)     → Mesa TB3-16 (+10V of +5V)
  Pin 2: (internal - not connected)
  Pin 3: Potentiometer wiper          → Mesa TB3-14 (Analog 0+)
  Pin 4: (internal - not connected)  
  Pin 5: Potentiometer end            → Mesa TB3-15/17 (GND)
  Pin 6: (internal - not connected)

Motor (4 pins op andere kant):
  Pin 1: Motor +                      → Mesa TB2-06 (PWM 0) via driver
  Pin 2: Motor -                      → Mesa TB2-07 (DIR) via driver
  Pin 3: NC (or motor shield)         → GND
  Pin 4: NC (or motor shield)         → GND

Let op: Motor pinout kan variëren per versie - meet met multimeter!
```

### Motor Driver (indien nodig)

Als de Mesa PWM output niet genoeg stroom levert (fader motor vraagt typisch 50-100mA):

```
L298N of TB6612FNG Driver:
═══════════════════════════════════════════════════
Mesa PWM 0      → Driver PWM input
Mesa DIR        → Driver DIR input
Driver OUT1     → Motor pin 1
Driver OUT2     → Motor pin 2
Driver VCC      → 24V
Driver GND      → GND
```

## Bekabeling Stap-voor-Stap

### 1. Emergency Stop
```
E-stop button (met vergrendeling):
  Common (COM)  → Mesa TB2-01 (GPIO 0)
  NC contact    → Mesa TB2-04 (+24V)
  
Let op: NC contact sluit circuit in normale toestand!
```

### 2. RGB Enable Button

**Hardware:** 19mm RGB LED illuminated button (12-24V)
- **Amazon:** https://www.amazon.nl/dp/B097MQP582

**Functie:**
- Toggle machine enable/disable
- RGB LED toont machine status
- **Program start** wordt een aparte knop (toekomstige uitbreiding)

**RGB LED bekabeling (Common Negative design):**
```
19mm RGB Button LED pinout:
  Zwart (negative-)   → Mesa TB2-12 (GND) - common cathode
  Rood (positive+)    → 2.2kΩ resistor → Mesa TB2-05 (GPIO 5)
  Groen (positive+)   → 2.2kΩ resistor → Mesa TB2-06 (GPIO 6)
  Blauw (positive+)   → 2.2kΩ resistor → Mesa TB2-07 (GPIO 7)

Switch contacts:
  Contact 1           → Mesa TB2-02 (GPIO 1)
  Contact 2           → Mesa TB2-04 (+24V)
```

**Resistor selectie:**
- Start met **2.2kΩ** voor maximale LED levensduur
- Te donker? → Verlaag naar 1.5kΩ of 1kΩ
- **NOOIT onder 680Ω** (risico op LED schade)

**LED State Indication:**

| Machine Status | E-stop | Enabled | Running | LED Kleur | LED Gedrag |
|----------------|--------|---------|---------|-----------|------------|
| Noodstop | ✓ | - | - | 🔴 **ROOD** | Continu |
| Uitgeschakeld | ✗ | ✗ | ✗ | 🔴 **ROOD** | Knippert 1Hz |
| Klaar (idle) | ✗ | ✓ | ✗ | 🟢 **GROEN** | Continu |
| Programma actief | ✗ | ✓ | ✓ | 🟢 **GROEN** | Knippert 0.5Hz |

**Gebruik:**
1. E-stop ontgrendelen → LED gaat van rood (continu) naar rood (knipperend)
2. Druk RGB button → Machine enabled → LED wordt groen (continu)
3. Start programma (via aparte knop, toekomstig) → LED knippert groen (actieve feedback)

**Bekabelingsschema:**
```
        Mesa 7i96S
        ┌─────────────┐
RGB     │             │
Button  │  TB2-05 ────┼──── 2.2kΩ ──── RED LED+
  │     │  TB2-06 ────┼──── 2.2kΩ ──── GREEN LED+
  │     │  TB2-07 ────┼──── 2.2kΩ ──── BLUE LED+
  │     │  TB2-12 ────┼──── BLACK (common -)
  │     │             │
  └─────┼─ TB2-02 ────┼──── Switch contact 1
        │  TB2-04 ────┼──── Switch contact 2 (+24V)
        └─────────────┘
```

### 3. ALPS Fader - Potentiometer
```
Wiring voor 10V range (aanbevolen):
  Pot end 1     → Mesa TB3-16 (+10V)
  Pot wiper     → Mesa TB3-14 (Analog 0+)
  Pot end 2     → Mesa TB3-17 (GND)

Of voor 5V range:
  Pot end 1     → External 5V supply
  Pot wiper     → Mesa TB3-14 (Analog 0+)
  Pot end 2     → Mesa TB3-17 (GND)
  
Let op: Als je 5V gebruikt, pas dan fader-scale-in.gain aan naar 40.0
```

### 4. ALPS Fader - Motor

**Optie A: Direct op Mesa (eenvoudig)**
```
Motor +         → Mesa TB2-06 (PWM 0)
Motor -         → Mesa TB2-07 (DIR)
```

**Optie B: Via motor driver (aanbevolen voor betrouwbaarheid)**
```
Driver IN1      → Mesa TB2-06 (PWM 0)
Driver IN2      → Mesa TB2-07 (DIR)
Driver OUT1     → Motor +
Driver OUT2     → Motor -
Driver VCC      → 24V
Driver GND      → Common GND
```

### 5. Status LEDs (optioneel)
```
Red LED (E-stop active):
  Anode (+)     → Mesa TB2-08 (GPIO 3)
  Cathode (-)   → 470Ω resistor → GND

Green LED (System ready):
  Anode (+)     → Mesa TB2-09 (GPIO 4)
  Cathode (-)   → 470Ω resistor → GND
```

## Software Setup

### 1. Mesa IP Configuratie

Standaard IP: `192.168.1.121`

Wijzig indien nodig in `control-panel.hal`:
```hal
loadrt hm2_eth board_ip="192.168.1.121" ...
```

Check verbinding:
```bash
ping 192.168.1.121
```

### 2. HAL Configuratie Laden

Voeg toe aan je INI file:
```ini
[HAL]
HALFILE = ihsv.hal
HALFILE = control-panel.hal
```

Of test standalone:
```bash
halrun -I control-panel.hal
```

### 3. Calibratie

**Fader voltage range:**
1. Beweeg fader naar minimum → meet voltage op TB3-14
2. Beweeg fader naar maximum → meet voltage op TB3-14
3. Pas `fader-scale-in.gain` aan:
   - Als max = 10V: gain = 20.0 (voor 0-200%)
   - Als max = 5V: gain = 40.0

**PID tuning:**

Start met conservatieve waardes:
```hal
setp fader-pid.Pgain 0.5
setp fader-pid.Igain 0.1
setp fader-pid.Dgain 0.01
```

Test gedrag:
- Te langzaam? → verhoog Pgain
- Oscilleert? → verhoog Dgain, verlaag Pgain
- Jittert bij stilstand? → verhoog deadband

Fine-tuning:
```bash
halcmd setp fader-pid.Pgain 0.8    # Experiment in real-time
halcmd show pin fader-*            # Monitor feedback
```

### 4. Motor Richting Test

Start LinuxCNC en test:
1. Zet feed override op 50% in GUI
2. Beweeg fader handmatig naar 100%
3. Laat los - fader moet naar 50% bewegen

**Als motor verkeerde kant beweegt:**
- Optie 1: Wissel motor draden
- Optie 2: Inverteer DIR signaal in HAL

## Startup Routine

Bij het opstarten van LinuxCNC met control panel:

1. **Power on**: RGB button toont 🔴 **ROOD continu** (e-stop actief)
2. **E-stop ontgrendelen**: RGB button gaat naar 🔴 **ROOD knipperend** (1 Hz)
3. **Druk RGB button**: Machine wordt enabled → 🟢 **GROEN continu**
4. **Fader sync**: Motor beweegt fader naar huidige LinuxCNC waarde (typisch 100%)
   - Duurt 2-5 seconden
   - Smooth beweging door PID
5. **Ready**: RGB button blijft 🟢 **GROEN continu** - klaar om programma te starten
6. **Start programma** (via aparte knop, toekomstig): LED wordt 🟢 **GROEN knipperend** (actieve feedback)
7. **Manual fader control**: Je kunt altijd handmatig fader bewegen om feed rate te wijzigen

## Gebruik

### RGB Enable Button

De RGB button heeft intelligent state-based gedrag:

**Visuele Feedback:**

| LED Display | Betekenis | Actie |
|-------------|-----------|-------|
| 🔴 Rood (continu) | E-stop actief | Ontgrendel e-stop |
| 🔴 Rood (knippert) | Machine uit, e-stop vrij | Druk om machine in te schakelen |
| 🟢 Groen (continu) | Machine aan, klaar | Gereed voor programma (aparte start knop) |
| 🟢 Groen (knippert) | Programma draait | Actieve feedback tijdens bewerking |

**Typische workflow:**
1. Power on → 🔴 Rood continu (e-stop actief)
2. Ontgrendel e-stop → 🔴 Rood knippert (druk om te enablen)
3. Druk RGB button → 🟢 Groen continu (machine enabled)
4. Start programma via aparte knop (toekomstig) → 🟢 Groen knippert (bezig)

**Knipperfrequentie aanpassen:**
```bash
# Rood (disabled state) - standaard 1 Hz (1x per seconde)
halcmd setp red-blink.frequency 1.0

# Groen (running state) - standaard 0.5 Hz (1x per 2 seconden)
halcmd setp green-blink.frequency 0.5
```

**Toekomstige uitbreiding:**
Blauwe LED is gereserveerd voor bijvoorbeeld:
- Cycle start indicator (knippert bij wachten op start)
- Paused state (continu blauw)
- Warnings (snel knipperend)

### Feed Override Aanpassen

**Met fader:**
- Schuif naar boven = sneller (max 200%)
- Schuif naar beneden = langzamer (min 0%)
- Midden = 100% (normaal)

**Met LinuxCNC GUI:**
- Wijzig feed override percentage
- Fader beweegt automatisch mee (PID regeling)

### Emergency Stop

**Activeren:**
1. Druk e-stop in → alle beweging stopt onmiddellijk
2. RGB button wordt 🔴 **ROOD continu**
3. Machine is volledig uitgeschakeld

**Reset:**
1. Los probleem op (indien van toepassing)
2. Ontgrendel e-stop door te draaien
3. RGB button gaat naar 🔴 **ROOD knipperend** (machine disabled maar veilig)
4. Druk RGB button → Machine enabled → 🟢 **GROEN continu** (ready)
5. Start programma via aparte knop (toekomstige feature)

**Let op:** E-stop reset betekent NIET dat machine automatisch enabled is! Je moet expliciet de RGB button indrukken om de machine weer in te schakelen. Dit is een veiligheidsfunctie.

## Troubleshooting

### Fader beweegt niet

**Check:**
```bash
halcmd show pin hm2_7i96s.0.pwmgen.00.*
```

Verwachte output bij 50% error:
```
hm2_7i96s.0.pwmgen.00.value  # Should be non-zero
hm2_7i96s.0.pwmgen.00.enable # Should be TRUE
```

**Mogelijke oorzaken:**
- Motor niet aangesloten → check bekabeling
- PWM frequency te hoog/laag → pas aan in HAL
- PID disabled → check fader-pid.enable
- Motor driver niet powered → check 24V

### Fader oscilleert (trilt)

**Symptoom:** Fader beweegt heen en weer rond setpoint

**Oplossing:**
```bash
# Verhoog deadband
halcmd setp fader-pid.deadband 1.0

# Verlaag Pgain
halcmd setp fader-pid.Pgain 0.3

# Verhoog Dgain (demping)
halcmd setp fader-pid.Dgain 0.05
```

### Fader reageert te langzaam

**Oplossing:**
```bash
# Verhoog Pgain
halcmd setp fader-pid.Pgain 1.0

# Verlaag deadband
halcmd setp fader-pid.deadband 0.3
```

### Analog input ruis

**Symptoom:** Fader positie springt, onrustig

**Oplossing:**
- Kortere kabel tussen fader en Mesa
- Afgeschermde kabel gebruiken
- Ground shield op één kant
- Filter toevoegen in HAL (lowpass)

**HAL filter toevoegen:**
```hal
loadrt lowpass names=fader-filter
setp fader-filter.gain 0.05  # Smoothing factor
addf fader-filter servo-thread

net fader-voltage-raw => fader-filter.in
net fader-voltage-filtered fader-filter.out => fader-scale-in.in
```

### E-stop werkt niet

**Check:**
```bash
halcmd show pin hm2_7i96s.0.gpio.000.*
```

**Verwacht:**
- E-stop losgelaten: pin = TRUE
- E-stop ingedrukt: pin = FALSE

**Als omgekeerd:**
```hal
# Voeg toe aan HAL:
setp hm2_7i96s.0.gpio.000.invert_input true
```

### RGB Enable/Start button werkt niet

**Button test:**
```bash
# Monitor button input
halcmd watch pin hm2_7i96s.0.gpio.001.in

# Druk button → waarde moet veranderen
```

**LED test:**
```bash
# Forceer kleuren individueel aan (test outputs)
halcmd setp hm2_7i96s.0.gpio.005.out true  # RED should light up
halcmd setp hm2_7i96s.0.gpio.006.out true  # GREEN should light up
halcmd setp hm2_7i96s.0.gpio.007.out true  # BLUE should light up

# Als geen enkele LED brandt: check bekabeling en resistors
```

**State machine test:**
```bash
# Check state signals
halcmd show sig rgb-sel0
halcmd show sig rgb-sel1
halcmd show sig machine-on-stable
halcmd show sig program-is-running

# Monitor live state changes
halcmd watch sig red-led-output
halcmd watch sig green-led-output
```

**Troubleshooting:**

| Probleem | Oorzaak | Oplossing |
|----------|---------|-----------|
| Alle LEDs te fel | Resistor te laag | Verhoog naar 2.2kΩ of hoger |
| Alle LEDs te zwak | Resistor te hoog | Verlaag naar 1.5kΩ of 1kΩ |
| Eén kleur werkt niet | Kapotte LED of losse draad | Check verbinding en resistor |
| LED blijft rood | Machine niet enabled | Check `halui.machine.is-on` |
| LED knippert niet | Siggen niet geladen | Check HAL file - siggen components |
| Verkeerde staat | State logic fout | Check sel0/sel1 signals |

**Weerstand calculatie:**
```
Mesa output: 24V
LED forward voltage: ~2V (red), ~3V (green/blue)
Gewenste stroom: 10mA

R = (24V - Vf) / I
R = (24V - 2V) / 0.010A = 2.2kΩ  (voor rood)
R = (24V - 3V) / 0.010A = 2.1kΩ  (voor groen/blauw)

Start met 2.2kΩ voor alle kleuren (veilig)
```

**Advanced: Custom states met BLUE channel:**

Blauwe LED is momenteel reserve. Gebruik maken:
```hal
# Bijvoorbeeld: BLUE voor paused state
net program-is-paused halui.program.is-paused => hm2_7i96s.0.gpio.007.out

# Of: BLUE knippert bij warnings
# Voeg mux4.2 toe voor BLUE channel in HAL
```

### Mesa kaart niet gevonden

**Check netwerk:**
```bash
ping 192.168.1.121
ip addr show  # Check of PC in juiste subnet zit
```

**PC moet in 192.168.1.x subnet:**
```bash
sudo ip addr add 192.168.1.100/24 dev eth0
```

## Performance Optimalisatie

### Servo Thread Tuning

Voor smoothe fader beweging:
```ini
[EMCMOT]
SERVO_PERIOD = 1000000  # 1ms (1kHz) - standaard
```

Voor zeer smooth operation:
```ini
SERVO_PERIOD = 500000   # 0.5ms (2kHz) - hogere update rate
```

Let op: Hogere rate = meer CPU load

### PWM Frequency

Fader motor optimaal bij 20-30kHz:
```hal
setp hm2_7i96s.0.pwmgen.pwm_frequency 25000
```

Te hoog (>50kHz): mogelijk motor whine
Te laag (<10kHz): motor loopt niet smooth

## Toekomstige Uitbreidingen

### Migratie naar EtherCAT

Later vervangen door Beckhoff modules:

**Huidige Mesa setup:**
- Analog in → EL3104 (4ch, 0-10V)
- Digital in → EL1008 (8ch, 24V)  
- PWM out → EL2502 (2ch PWM)

**Voordeel EtherCAT:**
- Hogere sample rate
- Betere noise immunity
- Synchronous operation
- Uitbreidbaar systeem

### Extra Features

Makkelijk toe te voegen:
- **Spindle override fader** - 2e ALPS fader op Analog 1
- **Jog wheel** - Encoder input op Mesa
- **Rapid override** - 3e fader
- **Status display** - OLED via I2C
- **Mode selector** - Rotary switch (manual/MDI/auto)

## Specificaties Overzicht

| Component | Spec | Notes |
|-----------|------|-------|
| Mesa 7i96S | Ethernet, 32 I/O | 3x analog in, 5x PWM |
| ALPS Fader | 100mm, 10kΩ | Professional grade |
| RGB Button | 19mm, 12-24V | State indication |
| Update rate | 1kHz (1ms) | Configurable |
| PWM freq | 25kHz | Adjustable |
| Voltage | 24VDC | Mesa + peripherals |
| Fader range | 0-200% | Feed override |
| RGB blink | 0.5-1 Hz | State dependent |

## Safety

⚠️ **Belangrijk:**
- E-stop moet **NC (Normally Closed)** contact zijn
- Test e-stop functie vóór eerste gebruik
- Fader motor heeft lage kracht - veilig om aan te raken
- 24V is veilig, maar voorkom kortsluiting

## Referenties

- [Mesa 7i96S Manual](http://www.mesanet.com/pdf/parallel/7i96sman.pdf)
- [LinuxCNC HAL Manual](http://linuxcnc.org/docs/html/hal/intro.html)
- [PID Tuning Guide](http://linuxcnc.org/docs/html/man/man9/pid.9.html)
- ALPS RSA0N11M9 datasheet (op aanvraag bij leverancier)

## Support

Voor vragen of problemen:
1. Check eerst deze README troubleshooting sectie
2. Test met `halrun` voor debugging
3. Monitor signals met `halcmd watch`
4. Open issue op GitHub met details

## Licentie

Deze configuratie is gebaseerd op je bestaande LinuxCNC EtherCAT setup.
Gebruik en wijzig naar eigen inzicht.

---

**Veel plezier met je Teenage Engineering-stijl control panel! 🎛️**