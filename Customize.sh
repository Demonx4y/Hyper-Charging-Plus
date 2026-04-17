SKIPUNZIP=0
REPLACE=""

ui_print " "
ui_print "╔═════════════════════════════════╗"
ui_print "║      ⚡ Hyper Charging+ ⚡      ║"
ui_print "║           Version 2.0           ║"
ui_print "╚═════════════════════════════════╝"
ui_print " "
ui_print "  Author  : Razal (Razal1_1)"
ui_print "  Version : v2.0"
ui_print " "

ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ui_print "  Initializing charging engine..."
ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
sleep 0.3

ui_print " "
ui_print "  ⚡ Charging Optimizations"
sleep 0.2
ui_print "  • Temperature based current tuning"
sleep 0.2
ui_print "  • 12-tier thermal protection system"
sleep 0.2
ui_print "  • Ultra current mode below 36.9°C (12.65A)"
sleep 0.2
ui_print "  • Battery % tapering at 85%, 90%, 95%, 99%"
sleep 0.2
ui_print "  • Cool zone: 36.9–40.9°C — 8.65A → 7.65A → 6.65A → 6.15A (gradual step-down)"
sleep 0.2
ui_print "  • Warm zone: 40.9–44.9°C — 4.15A → 3.65A → 3.15A → 2.65A (0.5A steps)"
sleep 0.2
ui_print "  • Each thermal tier runs its own dedicated current target"
sleep 0.2
ui_print "  • Emergency cutoff at 48°C"
sleep 0.2
ui_print "  • Restores at 46°C — 2°C hysteresis from 48°C cutoff"
sleep 0.2
ui_print "  • 1.15A cap at 99%, stop after 2 minutes at 100%"
sleep 0.2
ui_print "  • Continuous current reassertion every 0.6s — maintains target speed against system overrides"
sleep 0.2
ui_print "  • Fast charge re-negotiation on every tier transition — immediate response to temperature changes"
sleep 0.3

ui_print " "
ui_print "  🎮 Game Bypass Mode"
sleep 0.2
ui_print "  • Auto-detect foreground games"
sleep 0.2
ui_print "  • Game name shown in notification"
sleep 0.2
ui_print "  • Bypass countdown timer"
sleep 0.2
ui_print "  • Smart exit on game close or screen off"
sleep 0.2
ui_print "  • 20%+ battery safety floor"
sleep 0.2
ui_print "  • 4 hour max bypass session"
sleep 0.2
ui_print "  • Persistent enforcer — auto-restores if killed"
sleep 0.2
ui_print "  • Optimal bypass method selected on every game session"
sleep 0.2
ui_print "  • Charging stops safely at 48°C during gameplay"
sleep 0.3

ui_print " "
ui_print "  📊 Awareness Notification"
sleep 0.2
ui_print "  • Live charging status notification"
sleep 0.2
ui_print "  • Real-time current display (mA)"
sleep 0.2
ui_print "  • Estimated time to full charge"
sleep 0.2
ui_print "  • Estimated battery time remaining"
sleep 0.2
ui_print "  • Live temperature monitoring"
sleep 0.2
ui_print "  • Live battery percentage"
sleep 0.2
ui_print "  • Game name and bypass timer"
sleep 0.2
ui_print "  • Battery full detection — notification captures exact time charging stopped"
sleep 0.2
ui_print "  • Notification clears correctly on unplug"
sleep 0.3

ui_print " "
ui_print "  🔧 Compatibility"
sleep 0.2
ui_print "  • Universal charger detection"
sleep 0.2
ui_print "  • Multi-node fallback system"
sleep 0.2
ui_print "  • Compatible with a wide range of devices and chargers"
sleep 0.2
ui_print "  • Automatic bypass method selection at boot"
sleep 0.3

ui_print " "
ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ui_print "  Setting up permissions..."
ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
sleep 0.3

APK_PATH="$MODPATH/system/app/HyperChargingService/HyperChargeService.apk"
pm install -r -t --dont-kill "$APK_PATH" >/dev/null 2>&1
pm install -r --user 0 -t --dont-kill "$APK_PATH" >/dev/null 2>&1
sleep 1

pm grant com.hypercharge.service android.permission.POST_NOTIFICATIONS 2>/dev/null
pm grant com.hypercharge.service android.permission.FOREGROUND_SERVICE 2>/dev/null
sleep 0.2
ui_print "  ✓ Notification permission granted"

dumpsys deviceidle whitelist +com.hypercharge.service 2>/dev/null
sleep 0.2
ui_print "  ✓ Battery optimization exempted"

pm grant com.hypercharge.service android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS 2>/dev/null
sleep 0.2
ui_print "  ✓ Background service protected"

am start-foreground-service --user 0 -n com.hypercharge.service/.ChargeNotificationService 2>/dev/null
sleep 0.2
ui_print "  ✓ Notification service started"

chmod 777 /sys/class/power_supply/*/* 2>/dev/null
chmod 777 /sys/kernel/*/* 2>/dev/null
sleep 0.2
ui_print "  ✓ Charging nodes unlocked"

chmod +x $MODPATH/service.sh 2>/dev/null
sleep 0.2
ui_print "  ✓ Service script permissions set"

ui_print " "
ui_print "  ⚠ Android 13+ Notice:"
ui_print "  If notification doesn't appear after reboot"
ui_print "  Go to Settings > Apps > HyperCharging"
ui_print "  Service > Notifications > Allow"

ui_print " "
ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ui_print "  Finalizing"
sleep 0.2
ui_print "  Finalizing ."
sleep 0.2
ui_print "  Finalizing .."
sleep 0.2
ui_print "  Finalizing ..."
sleep 0.4

ui_print " "
ui_print "╔═════════════════════════════════╗"
ui_print "║  ✓ Hyper Charging+ v2.0 Ready!  ║"
ui_print "╚═════════════════════════════════╝"
ui_print " "
ui_print "  ⚡ Reboot to activate all features"
ui_print "  📊 Notification appears after boot"
ui_print "  🎮 Add  or Remove games via game_list.sh"
ui_print " "
