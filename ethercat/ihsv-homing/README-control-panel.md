# LinuxCNC Control Panel - Mesa 7i96S

High-quality control panel voor LinuxCNC met motorized feed override fader.

## Hardware

### Components
- **Mesa 7i96S** - Ethernet FPGA I/O kaart
- **ALPS RSA0N11M9A0J** - 100mm motorized fader (hoogwaardige mixing console fader)
- **Emergency stop button** - Met NC (Normally Closed) contact, vergrendeling
- **Start pulse button** - NO (Normally Open) momentary contact
  - *Optioneel:* **Heschen 16mm** momentary met ingebouwde 12V LED (wit/rood/blauw/groen/geel)
- **24V power supply** - Voor Mesa kaart en motor driver
- **Motor driver** (optioneel) - Als fader motor meer stroom nodig heeft dan Mesa kan leveren

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
02    | GPIO 1 (Input)      | Start button (NO contact)
03    | GND                 | Button common
04    | +24V                | Pull-up voor inputs
05    | -                   | -
06    | PWM 0               | Fader motor PWM
07    | PWM 0 DIR           | Fader motor direction
08    | GPIO 3 (Output)     | E-stop LED (rood)
09    | GPIO 4 (Output)     | Ready LED (groen)
10    | GPIO 5 (Output)     | Start button LED (optioneel)*
11    | GND                 | LED common

* Only used if Heschen button with LED is installed

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

### 2. Start Button
```
Start button (momentary):
  One side      → Mesa TB2-02 (GPIO 1)
  Other side    → Mesa TB2-04 (+24V)
  
Pull-down via Mesa interne resistor
```

#### 2b. Start Button with LED (Optional - Heschen 16mm)

Als je de **Heschen 16mm drukknop met LED** gebruikt:

```
Heschen 16mm momentary button pinout:
  NO contact    → Mesa TB2-02 (GPIO 1)
  COM contact   → Mesa TB2-04 (+24V)
  NC contact    → Niet gebruikt
  
LED connections - OPTIE A (met weerstand):
  LED+          → Mesa TB2-10 (GPIO 5)
  LED-          → 1.2kΩ resistor → GND
  
LED connections - OPTIE B (met transistor, aanbevolen):
  Mesa TB2-10   → 1kΩ → Base (2N2222 NPN)
  Collector     → LED+
  Emitter       → GND
  LED-          → 12V supply GND
```

**LED gedrag:**
- E-stop actief: LED UIT
- Standby (geen e-stop, machine idle): LED KNIPPERT (1x per 2 sec)
- Machine running: LED brandt CONTINU

**Activeren in HAL:**
Open `control-panel.hal` en verwijder de comment tekens (`#`) bij de sectie:
```hal
# ============================================================================
# START BUTTON LED (OPTIONAL)
# ============================================================================
```

Alle regels onder deze sectie die met `#` beginnen moeten actief gemaakt worden.

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

Bij het opstarten van LinuxCNC:

1. **E-stop check**: Rode LED moet branden als e-stop ingedrukt
2. **Fader sync**: Motor beweegt fader naar huidige LinuxCNC waarde (typisch 100%)
   - Duurt 2-5 seconden
   - Smooth beweging door PID
3. **Ready**: Groene LED gaat aan
4. **Manual override**: Je kunt nu handmatig fader bewegen om feed rate te wijzigen

## Gebruik

### Start Button LED (indien geïnstalleerd)

De Heschen start button heeft intelligent LED gedrag:

| Machine Status | E-stop | Program Running | LED Gedrag |
|----------------|--------|-----------------|------------|
| Noodstop actief | JA | - | **UIT** |
| Standby | NEE | NEE | **KNIPPERT** (1x / 2 sec) |
| Actief | NEE | JA | **AAN** (continu) |

**Gebruik:**
- LED uit? → Check e-stop, ontgrendel en druk start
- LED knippert? → Machine klaar, druk start om programma te beginnen
- LED brandt? → Machine draait programma

### Feed Override Aanpassen

**Met fader:**
- Schuif naar boven = sneller (max 200%)
- Schuif naar beneden = langzamer (min 0%)
- Midden = 100% (normaal)

**Met LinuxCNC GUI:**
- Wijzig feed override percentage
- Fader beweegt automatisch mee (PID regeling)

### Emergency Stop

1. Druk e-stop in → alle beweging stopt
2. Rode LED brandt
3. Ontgrendel e-stop
4. Druk **Start** button → systeem reset
5. Groene LED brandt → ready

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

### Start button doet niets

**Check:**
```bash
halcmd show sig start-button
```

**Debug:**
```bash
# Monitor input
halcmd watch pin hm2_7i96s.0.gpio.001.in

# Druk button → waarde moet veranderen
```

### Start button LED werkt niet (optioneel feature)

**Check of LED sectie geactiveerd is:**
```bash
halcmd show pin led-blink.square
# Als "NOT FOUND" → LED sectie is nog uitgecomment
```

**Activeren:**
1. Open `control-panel.hal`
2. Zoek sectie `# START BUTTON LED (OPTIONAL)`
3. Verwijder `#` voor alle regels onder deze sectie
4. Herstart LinuxCNC

**LED gedrag testen:**
```bash
# Forceer LED aan (test output)
halcmd setp hm2_7i96s.0.gpio.005.out true

# LED moet nu branden - zo niet: check bekabeling
```

**Knipperfrequentie aanpassen:**
```bash
# Langzaam (elke 4 sec)
halcmd setp led-blink.frequency 0.25

# Snel (elke seconde)
halcmd setp led-blink.frequency 1.0
```

**Weerstand check (Optie A):**
- Heschen LED is 12V, Mesa output is 24V
- Zonder weerstand: LED gaat kapot!
- Gebruik 1.2kΩ - 1.5kΩ resistor
- LED te fel? Verhoog naar 2.2kΩ
- LED te zwak? Verlaag naar 820Ω (maar niet lager dan 680Ω!)

**Transistor circuit (Optie B - aanbevolen):**
```
Mesa GPIO 5 (24V) → 1kΩ → Base (2N2222)
                           Collector → LED+ (12V)
                           Emitter → GND
LED- → 12V GND

Test transistor:
- Meet voltage Base-Emitter: ~0.7V wanneer aan
- Meet voltage Collector-Emitter: ~0.2V wanneer aan
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
| Update rate | 1kHz (1ms) | Configurable |
| PWM freq | 25kHz | Adjustable |
| Voltage | 24VDC | Mesa + peripherals |
| Fader range | 0-200% | Feed override |

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
