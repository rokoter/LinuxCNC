# v1.0.7 - Quick Fix

## Verwijderd: "Fix EtherCAT permissions" uit Next Steps

**Waarom?**
De installer doet dit al automatisch via udev rules. Na reboot zijn de permissions correct.

**Wat is er veranderd?**

### Voor (v1.0.6):
```
=== Next Steps ===
1. Configure BIOS settings
2. Reboot the system
3. Run latency test
4. Fix EtherCAT permissions: sudo chmod 666 /dev/EtherCAT0  ← VERWARREND
5. Start LinuxCNC
```

### Na (v1.0.7):
```
✓ EtherCAT permissions verified: 666

=== Next Steps ===
1. Configure BIOS settings
2. Reboot the system
3. Run latency test
4. Start LinuxCNC
```

**Automatische verificatie:**
- ✓ Toont groen vinkje als permissions correct zijn
- ⚠ Toont waarschuwing ALLEEN als er echt een probleem is
- Verklaart dat reboot het zal fixen

Dit is een kleine verbetering voor betere UX - geen onnodige handmatige stappen meer!
