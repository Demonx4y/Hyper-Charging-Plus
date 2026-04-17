# Changelog

---

## Hyper Charging+ v2.0

This update introduces a live awareness notification system, game bypass charging mode, battery protection, deeper thermal control, improved device compatibility, and a series of stability fixes compared to v1.1.

### Awareness Notification
- Added companion system app that displays a persistent charging notification
- Live current (mA), temperature and battery percentage shown in real time
- Estimated time to full charge shown during normal charging
- Estimated battery time remaining shown when unplugged and discharging
- Notification updates in real time as values change
- Notification stays accurate even after extended idle periods — refreshes automatically in the background
- Game mode icon when bypass charging is active
- Battery full indicator shown when charging stops at 100% — notification freezes at the exact moment charging stops, capturing the temperature, percentage and time your phone reached full charge
- Service auto starts on boot and runs silently in the background
- Notification clears correctly and immediately when charger is unplugged

### Game Bypass Mode
- Charging automatically pauses when a game is detected in the foreground
- Foreground app name shown in bypass notification
- Bypass time remaining countdown shown in notification
- Prevents battery heat buildup during gaming sessions
- Charging resumes instantly when game is closed or screen turns off
- Minimum battery floor of 20% before bypass is allowed
- If while playing games battery drops to 20%, bypass reactivates automatically only when battery reaches 25% and stays there for 20 seconds
- Maximum bypass session capped at 4 hours for safety
- Bypass stays active regardless of notification interactions during gameplay
- If temperature reaches 48°C during gameplay, charging stops automatically and bypass exits cleanly
- Bypass enforcer runs as a persistent background process — restarts automatically if the process dies unexpectedly
- Re-entering a game after switching to another app always re-detects the optimal bypass method fresh

### Battery Protection
- Current capped at 1.15A when battery reaches 99%
- Notifications continue to update normally at 99%
- When battery hits 100%, a 2-minute timer starts — charging stops after 2 minutes at genuine 100%
- Battery percentage tapering takes priority over thermal tier current at 99%
- Keeps current gentle at 99%–100%, reducing electrochemical stress before the final stop
- Full taper ladder: 3.15A at 85% → 2.65A at 90% → 2.15A at 95% → 1.15A at 99% → stop at 100%
- Charging re-enables automatically when battery drops below 100%
- Charging re-enables automatically when temperature drops below 46°C after thermal cutoff — approximately 2°C hysteresis from the 48°C cutoff

### Thermal Engine
- Expanded from 4 to 12 thermal tiers for finer current control
- Added ULTRA tier below 36°C — 12.65A for 90W+ devices when battery is cool
- WARM LOW raised from 3.65A to 4.15A at 40.9°C–41.9°C — better ceiling before the warm zone step-down begins
- WARM LIGHT tier at 41.9°C–42.9°C at 3.65A — renamed from WARM, sits between WARM LOW and the new WARM tier
- WARM tier at 42.9°C–43.9°C at 3.15A — new tier filling the gap, smooth 0.5A step down from WARM LIGHT
- WARM HIGH shifted to 43.9°C–44.9°C at 2.65A — 0.5A step down from WARM
- HOT tier covers 44.9°C–45.9°C at 2.15A — 0.5A step from WARM HIGH
- VERY HOT tier covers 45.9°C–46.9°C at 1.65A — dedicated temperature boundary and current target
- CRITICAL tier at 46.9°C–47.9°C at 1.15A — final step before cutoff
- Emergency cutoff at 48°C — charging disabled entirely, re-enables at 46°C — 2°C hysteresis prevents cycling near the cutoff boundary
- Every step from 40.9°C to 47.9°C is 0.5A or less — smooth, gradual step-down across the warm and hot zones
- COOL tier tightened to 36.9°C–37.9°C — peak speed only when genuinely cool
- COOL LOW tier at 37.9°C–38.9°C at 7.65A — bridges the gap between COOL and NORMAL
- NORMAL tier at 38.9°C–39.9°C raised to 6.65A — smoother step from COOL LOW
- NORMAL LOW tier at 39.9°C–40.9°C at 6.15A — dedicated transition tier before the warm zone
- All tier current values include a +150mA headroom to compensate for real-world line and conversion losses
- Battery percentage tapering applies on top of thermal tiers — caps at 3.15A from 85%, 2.65A from 90%, 2.15A from 95%

### Device Compatibility
- Universal charger detection across all known power supply interfaces
- Multi-node fallback system for charging control and sensor readings
- Battery capacity auto correction for devices reporting in different units
- Automatic bypass method selection at boot — adapts to the most effective method for each device
- Extended charging node support for devices that use additional PMIC current control nodes — activates only on compatible hardware, silently skipped on others
- USB SDP, CDP and HVDCP current paths now independently forced where available — prevents USB host port 500mA cap from limiting charging speed
- QC fast charge permission nodes expanded — hvdcp_opti and hvdcp3 paths explicitly enabled on supported hardware
- MediaTek hardware bypass path included for devices that support it — activates only where applicable
- Devices without bypass capability fall back to a reduced current mode automatically
- Redmi/MIUI devices: hardware trickle phase below ~15% is kernel-enforced and cannot be overridden by any module

### Stability and Logging
- Bypass enforcer runs persistently and recovers automatically if interrupted
- Bypass method re-evaluated on every new game session for optimal performance
- Charging state and status bar icon clear correctly on every unplug
- Auto detect battery capacity from device for charge estimation
- Charge time estimation protected against low current and unrealistic values
- Voltage reading added to log for better diagnostics
- Thermal tier changes logged with precise decimal temperature — log now shows exact value at tier boundary instead of truncated integer
- Log auto clears when size exceeds limit
- Charging loop runs every 0.6 seconds for responsive thermal and current adjustments
- Fast charge paths re-negotiated on every thermal tier transition — ensures consistent current delivery when crossing tier boundaries
- USB disconnect debounce prevents false inactive notifications
- Notification and service stop correctly when module is disabled — no stale notification left behind

---

## Hyper Charging+ v1.1

This update focused on improving charging stability, thermal behavior, and consistency.

### Changes and Improvements
- Added a multi step thermal ladder for smoother current scaling and better thermal behaviour
- Charging power now adapts more gradually as temperature rises
- Improved stability during long charging sessions
- Reduced sudden current drops under moderate heat
- Improved behavior across different chargers and cables
- Charging current reasserted every loop for consistent delivery
- Safer handling near higher temperature ranges
- Charging loop tuned for consistency

---

## Hyper Charging+ v1.0

The first release of Hyper Charging+. A focused, minimal thermal-aware charging loop that continuously maintains the maximum safe current against Android's charging limits.

### Charging Engine
- 3-tier thermal ladder adapts current based on real battery temperature
- COOL below 42°C: requests 6.5A for maximum available speed in safe conditions
- WARM at 42–46°C: steps down to 3.0A to balance speed and heat
- HOT above 46°C: holds at 2.2A to maintain safe fast charging under heat
- Continuous reassertion every 0.6s maintains target current against system overrides
- Writes to all known USB, main, and battery current nodes every 0.6s for consistent current delivery
- Force-enables fast charge paths each loop (force_fast_charge, allow_hvdcp3, pd_allowed) to keep negotiation active

### Why It Works
Android's charging system re-applies limits continuously during runtime. A single one-time write is overridden within seconds. Hyper Charging+ runs a continuous loop that maintains the desired current while scaling intelligently with temperature.
