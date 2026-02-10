
# ⚡ Hyper Charging+

Hyper Charging+ is a fast-charging Magisk module that improves how your device manages and sustains charging power using its existing hardware.

It focuses on adapting charging current in real time based on battery temperature and charging conditions, with the goal of maintaining stable and consistent fast charging when conditions allow.

This module does not unlock hardware limits or replace charging protocols. It works alongside the device’s normal charging system.

---

## 🔋 What Hyper Charging+ Does

• Requests higher charging current when the battery is cool  
• Gradually scales charging current down as temperature increases  
• Helps reduce sudden throttling and unstable current drops  
• Maintains smoother charging behavior during long sessions  

The logic is continuous and adaptive rather than one-time tweaks.

---

## 🧠 How It Works

Android charging systems frequently re-apply limits during runtime. Single writes to charging nodes are often overridden quickly.

Hyper Charging+ uses a lightweight loop that:
• Monitors battery temperature  
• Adjusts requested current dynamically  
• Writes to multiple standard power supply nodes  

This allows the module to cooperate with the system instead of fighting it, keeping charging behavior more consistent over time.

---

## ⚡ Charging Protocol Behavior

Hyper Charging+ does not replace or bypass charging protocols.

• Proprietary fast-charging systems continue to operate normally  
• The module does not spoof protocols or force unsupported modes  
• Standard charging paths are optimized where possible  

On devices that support proprietary fast charging, those systems remain in control.  
On devices without them, the module improves stability within standard charging limits.

---

## 🌡️ Thermal-Aware Charging

Charging current is adjusted using a temperature-based ladder:

• Cool temperatures allow higher current requests  
• Moderate heat reduces current gradually  
• Higher temperatures trigger stronger current reduction  

This helps maintain charging speed without pushing unsafe thermal behavior.

---

## 📊 What to Expect

Depending on your device, charger, and conditions, you may notice:

• More stable charging current  
• Fewer unnecessary drops under moderate heat  
• Smoother tapering as battery level increases  
• Better real-world charging consistency  

Charging speed will still reduce naturally near high battery percentages. This behavior is normal and preserved.

---

## 📦 Installation

1. Flash the module using Magisk
2. Reboot

The charging control service starts automatically after boot.

---

## 🧹 Uninstall

• Disable or remove the module in Magisk  
• Reboot  

The system returns to its default charging behavior.

---

## 🧪 Status

• Tested with different chargers and cables  
• Tested during idle and active use  
• Designed to respect hardware and thermal limits  
• Ongoing development based on real usage feedback  

Future updates may include:
• Refinements to thermal tuning  
• Optional diagnostics  
• Experimental features clearly marked

---

## 👤 Author

Razal (Razal1_1)  
Independent developer  

Email: razalrazal759@gmail.com
---

## 📜 License

This project is licensed under the GNU General Public License v3 (GPLv3).

You are free to use, modify, and redistribute this project under the terms of the GPLv3.
See the `LICENSE` file for full details.
