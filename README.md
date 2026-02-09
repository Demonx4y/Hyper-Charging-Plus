# ⚡ Hyper Charging+

**Hyper Charging+** is a next-generation **fast-charging Magisk module** designed to
optimize how existing charging hardware negotiates and sustains power — **safely and transparently**.

This is **not** a fake booster.  
This is **not** a hardware unlock.  
This is a carefully engineered **charging behavior optimizer** built around real device limits.

---

## 🔋 What Hyper Charging+ Does

• Pushes **maximum possible charging power when conditions are safe**  
• Dynamically adapts charging current based on **real battery temperature**  
• Reduces unnecessary throttling and sudden current drops  
• Maintains **stable, consistent charging** across long sessions  

No timers.  
No placebo tweaks.  
No gimmicks.

---

## 🧠 Why This Approach

Android’s charging HAL and PMIC continuously re-apply limits during runtime.
A single one-time write is often **overridden within seconds**.

Hyper Charging+ intentionally uses:
• **Adaptive thermal logic**  
• **Continuous dominance loops**  
• **Multi-node current negotiation**  

This allows the module to **work with the hardware**, not fight it — maintaining consistency
without hard-locking unsafe values.

---

## ⚠️ Important Transparency Notice

Hyper Charging+ does **NOT**:

✗ Increase hardware charging capability  
✗ Turn low-watt devices into ultra-fast chargers  
✗ Spoof battery temperature or bypass safety systems  
✗ Break PMIC, BMS, or thermal protection loops  

What it **DOES**:

✓ Optimizes how your device uses its **existing charging hardware**  
✓ Requests the **maximum current your hardware already supports**  
✓ Scales down intelligently as heat or charge level rises  

Final results depend on:
**device • charger • cable • temperature • battery health**

> Note: Charging speed naturally reduces at higher charge levels (≈80–100%).  
> This behavior is normal, expected, and intentionally preserved.

Hyper Charging+ does not replace proprietary fast-charging systems — it complements them
by reducing unnecessary throttling and improving charging stability when conditions allow.

---

## ⚡ About Fast-Charging Protocols

Hyper Charging+ does **not interfere with proprietary fast-charging protocols** such as:
VOOC, SuperVOOC, Warp, Turbo, FlashCharge, etc.

• No protocol spoofing  
• No PD/QC manipulation  
• No vendor HAL overrides  

On supported devices, proprietary fast charging continues **unchanged**.  
On unsupported devices, the module optimizes **standard charging paths only**.

---

## 📊 Expected Results

You may observe:
• Higher sustained charging current  
• Fewer drops under moderate heat  
• Smoother tapering near high charge levels  
• Better real-world charging consistency  

Improvements are **realistic, measurable, and safe** — not exaggerated.

---

## 🧪 Status

• Tested across multiple chargers (high-watt, mid-watt, low-watt)  
• Tested under idle and load (gaming + charging)  
• Verified to respect adapter and hardware limits  
• Actively evolving based on real user feedback  

Future updates may include:
• Advanced tuning refinements  
• Optional statistics / UI  
• Experimental branches (clearly labeled)

---

## 👤 Author

**Razal (Razla1_1)**  
Independent developer

---

## 📜 License

See `LICENSE` file.

---

## NOTICE

This software is distributed with attribution and license terms.

If you received this module **without** the accompanying `README.md`
and `LICENSE` file, it has been redistributed **without authorization**.
