# ⚡ Hyper Charging+

Hyper Charging+ is a fast-charging Magisk module that improves how your device manages and sustains charging power using its existing hardware.

It adapts charging current in real time based on battery temperature and charging conditions, with the goal of maintaining stable and consistent fast charging when conditions allow. It also includes a live awareness notification, game bypass charging mode, automatic battery protection, estimated charge time, and critical temperature safety during gaming.

This module does not unlock hardware limits or replace charging protocols. It works alongside the device's normal charging system.

---

## 🔋 What Hyper Charging+ Does

- Requests higher charging current when the battery is cool
- Gradually scales charging current down as temperature increases
- Helps reduce sudden throttling and unstable current drops
- Maintains smoother charging behavior during long sessions
- Pauses charging automatically when gaming to reduce heat
- Stops charging and exits game bypass cleanly if temperature reaches 48°C during gameplay
- Displays a live notification with charging status, current, temperature and estimated time
- Improved compatibility across a wider range of devices
- Compatible with a wide range of devices — automatically adapts to the most effective charging and bypass method for each device
- Game bypass effectiveness depends on hardware and kernel support — devices without bypass capability will fall back to a reduced current mode instead
- Use a charger with at least 15W (3A) or higher output for best bypass performance. Chargers below 2A may not provide enough power to sustain the device during gaming.
The logic is continuous and adaptive rather than one-time tweaks.

---

## 🧠 How It Works

Android charging systems frequently re-apply limits during runtime. Single writes to charging nodes are often overridden quickly.

Hyper Charging+ uses a lightweight loop that:
- Monitors battery temperature and charging state every 0.6 seconds
- Adjusts requested current dynamically across 12 thermal tiers
- Writes to multiple standard power supply nodes with device fallbacks — including USB SDP, CDP, HVDCP, QC fast charge paths, and BMS interfaces where available
- Detects foreground games and activates bypass mode automatically
- Auto detects battery capacity for charge time estimation
- Checks for critical temperature even inside game bypass mode
- Re-negotiates fast charging paths on every thermal tier transition for consistent current delivery

This allows the module to cooperate with the system instead of fighting it, keeping charging behavior more consistent over time.

---

## ⚡ Charging Protocol Behavior

Hyper Charging+ does not replace or bypass charging protocols.

- Proprietary fast-charging systems continue to operate normally
- The module does not spoof protocols or force unsupported modes
- Standard charging paths are optimized where possible
- Acts as an active Software-Defined Charging Protocol, delivering smart thermal management, CC/CV safety curves, and peak speeds even if you aren't using the original OEM charger.
- On devices that support proprietary fast charging, those systems remain in control.
- On devices without them, the module improves stability within standard charging limits. 
---

## 🌡️ Thermal-Aware Charging

Charging current is adjusted using a 12-tier temperature based ladder:

| Temperature | Tier | Target Current |
|---|---|---|
| Below 36.9°C | ULTRA | 12.65A |
| 36.9°C – 37.9°C | COOL | 8.65A |
| 37.9°C – 38.9°C | COOL LOW | 7.65A |
| 38.9°C – 39.9°C | NORMAL | 6.65A |
| 39.9°C – 40.9°C | NORMAL LOW | 6.15A |
| 40.9°C – 41.9°C | WARM LOW | 4.15A |
| 41.9°C – 42.9°C | WARM LIGHT | 3.65A |
| 42.9°C – 43.9°C | WARM | 3.15A |
| 43.9°C – 44.9°C | WARM HIGH | 2.65A |
| 44.9°C – 45.9°C | HOT | 2.15A |
| 45.9°C – 46.9°C | VERY HOT | 1.65A |
| 46.9°C – 47.9°C | CRITICAL | 1.15A |
| Above 48°C | CUTOFF | Charging disabled |

**COOL LOW through NORMAL LOW form a smooth cool-to-normal transition** covering 37.9°C–40.9°C. Current steps from 7.65A → 6.65A → 6.15A for gradual step-down from peak speed.

**WARM LOW through WARM HIGH form a smooth 4-tier warm zone** covering 40.9°C–44.9°C. Current steps down from 4.15A → 3.65A → 3.15A → 2.65A in 0.5A increments across the range where most phones spend the majority of their charging time.

**VERY HOT at 45.9°C–46.9°C runs at 1.65A** — independent tier with its own temperature boundary and current target, separate from CRITICAL (1.15A).

**CRITICAL at 46.9–47.9°C steps down to 1.15A** — a final reduction before the hard cutoff, slowing heat generation in the last degree. Charging stops at 48°C and re-enables at 46°C, giving approximately 2°C hysteresis that prevents cycling near the boundary.

**All current values include a +150mA headroom.** Current is lost between the charger output and the battery due to cable resistance, connector contact, and charging IC conversion. Setting 150mA above the intended target means the battery actually receives the designed current rather than slightly under it. For example, WARM LOW is set to 4.15A so the battery sees a real 4.0A.

Battery percentage tapering applies on top of thermal tiers:

| Battery % | Current Cap | Actual battery sees |
|---|---|---|
| 85% – 89% | Limited to 3.15A | ~3.0A |
| 90% – 94% | Limited to 2.65A | ~2.5A |
| 95% – 98% | Limited to 2.15A | ~2.0A |
| 99% – 100% | Capped at 1.15A, charging stops after 2 minutes at 100% | ~1.0A |

Tapering reduces stress on the battery as it approaches full charge. The caps apply regardless of temperature — even if the device is cool, charging slows down near the top to protect cell longevity.

Charging re-enables automatically once temperature drops below 46°C — 2°C hysteresis from the 48°C cutoff prevents the device from cycling in and out of cutoff near the boundary.

---

## 🎮 Game Bypass Mode

When a game is detected in the foreground, Hyper Charging+ automatically pauses charging to reduce battery heat during gameplay.

- Activates automatically when a supported game is open
- Shows the game name and bypass time remaining in the notification
- Charging resumes instantly when the game is closed or screen turns off
- Requires battery to be above 20% to activate
- If while playing games battery drops to 20% bypass reactivates automatically only when battery reaches 25% and stays there for 20 seconds
- Maximum bypass session is capped at 4 hours
- After the cap hits, exit the game and re-enter or unplug the charger and reconnect to reset the cap
- If temperature reaches 48°C during gameplay, charging stops automatically and bypass exits
- Charging re-enables when temperature drops below 46°C
- You can add or remove your games to `game_list.sh` inside the module

---

## 🔒 Battery Protection

- When battery hits 99%, current is capped at 1.15A (~1.0A at battery)
- When battery hits 100%, a 2-minute timer starts — charging stops after 2 minutes at genuine 100%
- Battery percentage tapering takes priority over thermal tier current
- Keeps voltage stable without pushing current into a near-full cell — reduces electrochemical stress before the final stop
- Prevents prolonged overcharging and voltage stress
- Charging re-enables automatically when battery drops below 100%

- Battery percentage tapering for battery longevity — 5 steps: 85% → 90% → 95% → 99% → 100% stop

---

## 📊 Awareness Notification

Hyper Charging+ includes a companion system app that shows a persistent notification with live charging information.

- Live charging mode status
- Real-time current in mA
- Battery temperature
- Battery percentage
- Estimated time to full charge during normal charging
- Estimated battery time remaining when unplugged and discharging
- Game name and bypass time remaining during game mode
- Game mode icon when bypass is active
- Battery full indicator when charging stops — notification freezes at the exact moment charging stops, showing the temperature, percentage and time at which your phone reached full charge

The notification updates in real time as values change and starts automatically on every boot.

Notice ⚠️

- The notification will take a moment to appear and be accurate after first boot
- Battery time remaining estimate stabilises after a few seconds of discharging
- This module doesn't overtake your OEM protocol 
- Works independently of your built-in fast charging chips. It serves as an advanced fallback engine that unlocks maximum safe speeds for third-party bricks while applying CC/CV safety curves and game bypass, thermal ladders and more to all non-proprietary chargers.
---

## 📦 Installation

1. Flash the module using Magisk
2. Reboot

The charging control service and notification start automatically after boot.

---

## 🧹 Uninstall

- Disable or remove the module in Magisk
- Reboot

The system returns to its default charging behavior.

---

## 🧪 Status

- Tested with different chargers and cables
- Tested during idle, active use, and gaming sessions
- Tested on multiple devices and Android versions
- Designed to respect hardware and thermal limits
- Ongoing development based on real usage feedback

Future updates may include:
- Refinements to thermal tuning
- Expanded game list
- Optional diagnostics
- Experimental features clearly marked

---

## 👤 Author

Razal (Razal1_1)
Independent developer
Telegram: t.me/Razal1_1

---

## 📜 License

This project is licensed under the GNU General Public License v3 (GPLv3).

You are free to use, modify, and redistribute this project under the terms of the GPLv3.
See the `LICENSE` file for full details.
