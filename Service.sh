#!/system/bin/sh
MODDIR=${0%/*}

sleep 5

pm grant com.hypercharge.service android.permission.POST_NOTIFICATIONS >/dev/null 2>&1
pm grant com.hypercharge.service android.permission.FOREGROUND_SERVICE >/dev/null 2>&1
pm grant com.hypercharge.service android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS >/dev/null 2>&1
appops set com.hypercharge.service POST_NOTIFICATIONS allow >/dev/null 2>&1
dumpsys deviceidle whitelist +com.hypercharge.service >/dev/null 2>&1
dumpsys deviceidle tempwhitelist com.hypercharge.service >/dev/null 2>&1
cmd appops set com.hypercharge.service RUN_IN_BACKGROUND allow >/dev/null 2>&1
cmd appops set com.hypercharge.service RUN_ANY_IN_BACKGROUND allow >/dev/null 2>&1
am startservice --user 0 -n com.hypercharge.service/.NotificationService >/dev/null 2>&1
am start-foreground-service --user 0 -n com.hypercharge.service/.NotificationService >/dev/null 2>&1
am start --user 0 -n com.hypercharge.service/.MainActivity >/dev/null 2>&1
sleep 3

LOG_FILE="/sdcard/hyper_charge.log"
MAX_LOG_SIZE=200000

if [ -f "$LOG_FILE" ]; then
  LOG_SIZE=$(wc -c < "$LOG_FILE" 2>/dev/null)
  [ -z "$LOG_SIZE" ] && LOG_SIZE=0
  if [ "$LOG_SIZE" -gt "$MAX_LOG_SIZE" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Log auto cleared" > "$LOG_FILE"
  fi
fi

chmod 777 /sys/class/power_supply/*/* 2>/dev/null
chmod 777 /sys/kernel/*/* 2>/dev/null
chmod 777 /sys/module/*/* 2>/dev/null

BATTERY_CAPACITY=$(cat /sys/class/power_supply/battery/charge_full 2>/dev/null)
[ -z "$BATTERY_CAPACITY" ] && BATTERY_CAPACITY=$(cat /sys/class/power_supply/bms/charge_full 2>/dev/null)
[ -z "$BATTERY_CAPACITY" ] && BATTERY_CAPACITY=$(cat /sys/class/power_supply/battery/charge_full_design 2>/dev/null)
[ -z "$BATTERY_CAPACITY" ] && BATTERY_CAPACITY=$(cat /sys/class/power_supply/bms/charge_full_design 2>/dev/null)
[ -z "$BATTERY_CAPACITY" ] && BATTERY_CAPACITY=5000000
BATTERY_CAPACITY_MAH=$((BATTERY_CAPACITY / 1000))
[ "$BATTERY_CAPACITY_MAH" -gt 30000 ] && BATTERY_CAPACITY_MAH=$((BATTERY_CAPACITY_MAH / 1000))
[ "$BATTERY_CAPACITY_MAH" -lt 1000 ] && BATTERY_CAPACITY_MAH=5000
echo "$(date '+%H:%M:%S') - Battery capacity detected: ${BATTERY_CAPACITY_MAH}mAh" >> "$LOG_FILE"

ULTRA_LIMIT=369
COOL_LIMIT=379
COOL_LOW_LIMIT=389
NORMAL_LIMIT=399
NORMAL_LOW_LIMIT=409
WARM_LOW_LIMIT=419
WARM_LIGHT_LIMIT=429
WARM_LIMIT=439
WARM_HIGH_LIMIT=449
HOT_LIMIT=459
VERY_HOT_LIMIT=469
CRITICAL_LIMIT=479
RESTORE_LIMIT=460
VERY_CRITICAL_LIMIT=480

ULTRA_CURRENT=12650000
MAX_CURRENT=8650000
COOL_LOW_CURRENT=7650000
NORMAL_CURRENT=6650000
NORMAL_LOW_CURRENT=6150000
WARM_LOW_CURRENT=4150000
WARM_LIGHT_CURRENT=3650000
WARM_CURRENT=3150000
WARM_HIGH_CURRENT=2650000
HOT_CURRENT=2150000
VERY_HOT_CURRENT=1650000
CRITICAL_CURRENT=1150000

CAP_85_CURRENT=3150000
CAP_90_CURRENT=2650000
CAP_95_CURRENT=2150000
TRICKLE_CURRENT=1150000

BYPASS_MIN_BATTERY=20
BYPASS_MAX_SECONDS=14459
EXIT_GRACE=3
FULL_CHARGE_STOP_DELAY=120
LOOP_DELAY=0.6

LAST_EXIT=0
BYPASS_START=0
BYPASS_ENFORCER_PID=""
CHARGE_LIMIT_BLOCK=""
CHARGE_LIMIT_RESTORE=""
COUNTER=0
LAST_MODE="INIT"
LAST_NOTIF_MODE="INACTIVE"
PREV_NOTIF_MODE=""
USB_OFF_COUNT=0
LAST_CAP=""
LAST_TEMP_C=""
LAST_CUR_MA=""
FULL_SINCE=0
CHARGING_STOPPED=0
TEMP_CUTOFF=0
LAST_TIER=""
BYPASS_GRACE_COUNT=0
BYPASS_REENTRY_SINCE=0
LAST_EXIT_REASON=
TIMER_EXPIRED=0
BYPASS_GRACE_MAX=2
BYPASS_REMAINING=0
LAST_BYPASS_REMAINING=-1
BYPASS_ICL=500000
LOG_CHECK_COUNT=0
BYPASS_DETECTED=0
HAS_PARALLEL_DISABLE=0
HAS_MTK_BYPASS=0
USB_OFF_CONFIRM=0
TIME_LEFT=0
LAST_TIME_LEFT=0
LAST_SENT_TIME_LEFT=0
DISCHARGE_EMA=0
FG_APP=""
LAST_USB_ON=0
APP_RUNNING=0
APP_CHECK_COUNTER=0
FORCE_ICL_NODE="/sys/class/power_supply/main/force_main_icl"
FORCE_ICL_RESTORE="0"
HAS_FORCE_ICL=0
BYPASS_METHOD="suspend"
ORIG_USB_ICL="3000000"
ORIG_MAIN_ICL="3000000"

[ -f "$MODDIR/game_list.sh" ] && . "$MODDIR/game_list.sh"

_cleanup() {
  am stopservice --user 0 -n com.hypercharge.service/.NotificationService >/dev/null 2>&1
  am force-stop com.hypercharge.service >/dev/null 2>&1
}
trap '_cleanup' EXIT TERM INT HUP

write_node() { [ -e "$1" ] && echo "$2" > "$1" 2>/dev/null; }
read_node()  { [ -f "$1" ] && cat "$1" 2>/dev/null; }

read_node_fb() {
  for _N in "$@"; do
    _V=$(read_node "$_N")
    if [ -n "$_V" ]; then
      echo "$_V"
      return
    fi
  done
}

detect_force_icl() {
  if [ -e "$FORCE_ICL_NODE" ]; then
    HAS_FORCE_ICL=1
    FORCE_ICL_RESTORE=$(cat "$FORCE_ICL_NODE" 2>/dev/null)
    [ -z "$FORCE_ICL_RESTORE" ] || [ "$FORCE_ICL_RESTORE" = "0" ] && FORCE_ICL_RESTORE=3000000
    echo "$(date '+%H:%M:%S') - force_main_icl detected, restore=$FORCE_ICL_RESTORE" >> "$LOG_FILE"
  fi
}

detect_bypass_method() {
  _V=$(cat /sys/class/power_supply/usb/current_max 2>/dev/null)
  [ -n "$_V" ] && [ "$_V" != "0" ] && ORIG_USB_ICL="$_V"
  _V=$(cat /sys/class/power_supply/main/current_max 2>/dev/null)
  [ -n "$_V" ] && [ "$_V" != "0" ] && ORIG_MAIN_ICL="$_V"
  echo "$(date '+%H:%M:%S') - Saved ICL: usb=$ORIG_USB_ICL main=$ORIG_MAIN_ICL" >> "$LOG_FILE"

  _USB=$(cat /sys/class/power_supply/usb/online 2>/dev/null)
  [ "$_USB" != "1" ] && _USB=$(cat /sys/class/power_supply/ac/online 2>/dev/null)
  if [ "$_USB" = "1" ]; then
    BYPASS_DETECTED=1

    if [ -f /sys/class/power_supply/battery/parallel_disable ]; then
      echo 1 > /sys/class/power_supply/battery/parallel_disable 2>/dev/null
      sleep 1
      _CUR_TEST=$(cat /sys/class/power_supply/battery/current_now 2>/dev/null)
      _CUR_TEST_ABS=${_CUR_TEST#-}
      echo 0 > /sys/class/power_supply/battery/parallel_disable 2>/dev/null
      if [ -n "$_CUR_TEST_ABS" ] && [ "$_CUR_TEST_ABS" -lt 50000 ]; then
        HAS_PARALLEL_DISABLE=1
        BYPASS_METHOD="suspend"
        echo "$(date '+%H:%M:%S') - Bypass method: parallel_disable (current=${_CUR_TEST})" >> "$LOG_FILE"
        return
      fi
    fi

    if [ -f /proc/mtk_battery_cmd/current_cmd ]; then
      echo 0 1 > /proc/mtk_battery_cmd/current_cmd 2>/dev/null
      sleep 1
      _CUR_TEST=$(cat /sys/class/power_supply/battery/current_now 2>/dev/null)
      _CUR_TEST_ABS=${_CUR_TEST#-}
      echo 0 0 > /proc/mtk_battery_cmd/current_cmd 2>/dev/null
      if [ -n "$_CUR_TEST_ABS" ] && [ "$_CUR_TEST_ABS" -lt 50000 ]; then
        HAS_MTK_BYPASS=1
        BYPASS_METHOD="suspend"
        echo "$(date '+%H:%M:%S') - Bypass method: mtk_bypass (current=${_CUR_TEST})" >> "$LOG_FILE"
        return
      fi
    fi

    echo 1 > /sys/class/power_supply/battery/input_suspend 2>/dev/null
    sleep 1
    _STAT=$(cat /sys/class/power_supply/battery/status 2>/dev/null)
    echo 0 > /sys/class/power_supply/battery/input_suspend 2>/dev/null
    if [ "$_STAT" = "Discharging" ]; then
      _CUR_TEST=$(cat /sys/class/power_supply/battery/current_now 2>/dev/null)
      _CUR_TEST_ABS=${_CUR_TEST#-}
      if [ -n "$_CUR_TEST_ABS" ] && [ "$_CUR_TEST_ABS" -gt 10000 ]; then
        BYPASS_METHOD="throttle"
        echo "$(date '+%H:%M:%S') - Bypass method: throttle (input_suspend cuts power, current=${_CUR_TEST})" >> "$LOG_FILE"
      else
        BYPASS_METHOD="suspend"
        echo "$(date '+%H:%M:%S') - Bypass method: suspend (input_suspend, current=${_CUR_TEST})" >> "$LOG_FILE"
      fi
    elif [ "$_STAT" = "Charging" ]; then
      _CUR_TEST=$(cat /sys/class/power_supply/battery/current_now 2>/dev/null)
      _CUR_TEST_ABS=${_CUR_TEST#-}
      if [ -n "$_CUR_TEST_ABS" ] && [ "$_CUR_TEST_ABS" -gt 50000 ]; then
        BYPASS_METHOD="throttle"
        echo "$(date '+%H:%M:%S') - Bypass method: throttle (input_suspend ignored, current=${_CUR_TEST})" >> "$LOG_FILE"
      else
        BYPASS_METHOD="suspend"
        echo "$(date '+%H:%M:%S') - Bypass method: suspend (input_suspend works, current=${_CUR_TEST})" >> "$LOG_FILE"
      fi
    else
      BYPASS_METHOD="suspend"
      echo "$(date '+%H:%M:%S') - Bypass method: suspend (input_suspend works, status=${_STAT})" >> "$LOG_FILE"
    fi
  else
    echo "$(date '+%H:%M:%S') - Bypass method: suspend (default, charger not connected at boot)" >> "$LOG_FILE"
  fi
}

detect_charge_limit_style() {
  CCL_MAX=$(cat /sys/class/power_supply/battery/charge_control_limit_max 2>/dev/null)
  CCL_NOW=$(cat /sys/class/power_supply/battery/charge_control_limit 2>/dev/null)
  if [ -n "$CCL_MAX" ] && [ "$CCL_MAX" -le 10 ] 2>/dev/null; then
    CHARGE_LIMIT_BLOCK="$CCL_MAX"
    CHARGE_LIMIT_RESTORE="${CCL_NOW:-0}"
  elif [ -n "$CCL_MAX" ] && [ "$CCL_MAX" -gt 10 ] 2>/dev/null; then
    CHARGE_LIMIT_BLOCK="0"
    CHARGE_LIMIT_RESTORE="${CCL_NOW:-$CCL_MAX}"
  else
    CHARGE_LIMIT_BLOCK=""
    CHARGE_LIMIT_RESTORE=""
  fi
}

stop_charging() {
  [ -n "$BYPASS_ENFORCER_PID" ] && kill -9 "$BYPASS_ENFORCER_PID" 2>/dev/null
  BYPASS_ENFORCER_PID=""

  [ -n "$CHARGE_LIMIT_BLOCK" ] && write_node /sys/class/power_supply/battery/charge_control_limit "$CHARGE_LIMIT_BLOCK"

  if [ "$BYPASS_METHOD" = "suspend" ]; then
    [ "$HAS_PARALLEL_DISABLE" = "1" ] && write_node /sys/class/power_supply/battery/parallel_disable 1
    [ "$HAS_MTK_BYPASS" = "1" ] && echo 0 1 > /proc/mtk_battery_cmd/current_cmd 2>/dev/null
    write_node /sys/class/power_supply/battery/input_suspend 1
    write_node /sys/class/power_supply/usb/input_suspend 1
    write_node /sys/class/power_supply/ac/input_suspend 1
    write_node /sys/class/power_supply/main/input_suspend 1
    write_node /sys/class/power_supply/pc_port/input_suspend 1
    write_node /sys/class/power_supply/dc/input_suspend 1
    dumpsys battery unplug >/dev/null 2>&1
  else
    BYPASS_ICL=300000
    write_node /sys/class/power_supply/usb/current_max "$BYPASS_ICL"
    write_node /sys/class/power_supply/ac/current_max "$BYPASS_ICL"
    write_node /sys/class/power_supply/main/current_max "$BYPASS_ICL"
    write_node /sys/class/power_supply/main/constant_charge_current_max "$BYPASS_ICL"
    write_node /sys/class/power_supply/battery/current_max "$BYPASS_ICL"
    write_node /sys/class/power_supply/battery/constant_charge_current_max "$BYPASS_ICL"
    [ "$HAS_FORCE_ICL" = "1" ] && echo "$BYPASS_ICL" > "$FORCE_ICL_NODE" 2>/dev/null
  fi

  _BLK="$CHARGE_LIMIT_BLOCK"
  ( while true; do
      if [ "$BYPASS_METHOD" = "suspend" ]; then
        [ "$HAS_PARALLEL_DISABLE" = "1" ] && echo 1 > /sys/class/power_supply/battery/parallel_disable 2>/dev/null
        [ "$HAS_MTK_BYPASS" = "1" ] && echo 0 1 > /proc/mtk_battery_cmd/current_cmd 2>/dev/null
        echo 1 > /sys/class/power_supply/battery/input_suspend 2>/dev/null
        echo 1 > /sys/class/power_supply/usb/input_suspend 2>/dev/null
        echo 1 > /sys/class/power_supply/ac/input_suspend 2>/dev/null
        echo 1 > /sys/class/power_supply/main/input_suspend 2>/dev/null
        echo 1 > /sys/class/power_supply/pc_port/input_suspend 2>/dev/null
        echo 1 > /sys/class/power_supply/dc/input_suspend 2>/dev/null
      else
        echo "$BYPASS_ICL" > /sys/class/power_supply/usb/current_max 2>/dev/null
        echo "$BYPASS_ICL" > /sys/class/power_supply/ac/current_max 2>/dev/null
        echo "$BYPASS_ICL" > /sys/class/power_supply/main/current_max 2>/dev/null
        [ "$HAS_FORCE_ICL" = "1" ] && echo "$BYPASS_ICL" > "$FORCE_ICL_NODE" 2>/dev/null
      fi
      [ -n "$_BLK" ] && echo "$_BLK" > /sys/class/power_supply/battery/charge_control_limit 2>/dev/null
      sleep 0.3
    done ) &
  BYPASS_ENFORCER_PID=$!
}

start_charging() {
  [ -n "$BYPASS_ENFORCER_PID" ] && kill "$BYPASS_ENFORCER_PID" 2>/dev/null
  BYPASS_ENFORCER_PID=""

  write_node /sys/class/power_supply/battery/mmi_charging_enable 1
  write_node /sys/class/power_supply/battery/charging_enabled 1
  write_node /sys/class/power_supply/battery/battery_charging_enabled 1
  write_node /sys/class/power_supply/battery/charge_enabled 1
  [ "$HAS_PARALLEL_DISABLE" = "1" ] && write_node /sys/class/power_supply/battery/parallel_disable 0
  [ "$HAS_MTK_BYPASS" = "1" ] && echo 0 0 > /proc/mtk_battery_cmd/current_cmd 2>/dev/null
  write_node /sys/class/power_supply/battery/input_suspend 0
  write_node /sys/class/power_supply/usb/input_suspend 0
  write_node /sys/class/power_supply/ac/input_suspend 0
  write_node /sys/class/power_supply/main/input_suspend 0
  write_node /sys/class/power_supply/pc_port/input_suspend 0
  write_node /sys/class/power_supply/dc/input_suspend 0
  write_node /sys/class/power_supply/battery/input_current_limited 0

  [ -n "$CHARGE_LIMIT_RESTORE" ] &&     write_node /sys/class/power_supply/battery/charge_control_limit "$CHARGE_LIMIT_RESTORE"

  write_node /sys/class/power_supply/battery/charge_control_end_threshold 100 2>/dev/null
  write_node /sys/class/power_supply/battery/rerun_aicl 1
  write_node /sys/class/power_supply/bq2597x-standalone/charging_enabled 1 2>/dev/null
  write_node /sys/class/power_supply/bq2597x-master/charging_enabled 1 2>/dev/null
  [ "$HAS_FORCE_ICL" = "1" ] && echo "$FORCE_ICL_RESTORE" > "$FORCE_ICL_NODE" 2>/dev/null
  write_node /sys/class/power_supply/usb/current_max "$ORIG_USB_ICL"
  write_node /sys/class/power_supply/ac/current_max "$ORIG_USB_ICL"
  write_node /sys/class/power_supply/main/current_max "$ORIG_MAIN_ICL"
  write_node /sys/class/power_supply/main/constant_charge_current_max "$ORIG_MAIN_ICL"
  write_node /sys/class/power_supply/battery/current_max "$ORIG_USB_ICL"
  write_node /sys/class/power_supply/battery/constant_charge_current_max "$ORIG_MAIN_ICL"
  dumpsys battery reset >/dev/null 2>&1
}

resume_from_bypass() {
  [ -n "$BYPASS_ENFORCER_PID" ] && kill -9 "$BYPASS_ENFORCER_PID" 2>/dev/null
  BYPASS_ENFORCER_PID=""
  sleep 0.3
  _RESET_TRIES=0
  while [ "$_RESET_TRIES" -lt 3 ]; do
    dumpsys battery reset >/dev/null 2>&1
    [ "$HAS_PARALLEL_DISABLE" = "1" ] && write_node /sys/class/power_supply/battery/parallel_disable 0
    [ "$HAS_MTK_BYPASS" = "1" ] && echo 0 0 > /proc/mtk_battery_cmd/current_cmd 2>/dev/null
    write_node /sys/class/power_supply/battery/input_suspend 0
    write_node /sys/class/power_supply/battery/charging_enabled 1
    write_node /sys/class/power_supply/battery/battery_charging_enabled 1
    write_node /sys/class/power_supply/bq2597x-standalone/charging_enabled 1 2>/dev/null
    write_node /sys/class/power_supply/bq2597x-master/charging_enabled 1 2>/dev/null
    _RESET_TRIES=$((_RESET_TRIES + 1))
    sleep 0.5
    _BSTAT=$(cat /sys/class/power_supply/battery/status 2>/dev/null)
    [ "$_BSTAT" = "Charging" ] && break
  done
  start_charging
  enable_fast_charge
  sleep 2
  enable_fast_charge
  write_node /sys/class/power_supply/battery/input_current_limited 0
  dumpsys battery reset >/dev/null 2>&1
  sleep 1
  dumpsys battery reset >/dev/null 2>&1
}

ensure_app_running() {
  _RUNNING=$(ps -A 2>/dev/null | grep -c "com.hypercharge.service")
  [ "$_RUNNING" -eq 0 ] && _RUNNING=$(ps 2>/dev/null | grep -c "com.hypercharge.service")
  if [ "$_RUNNING" -eq 0 ]; then
    echo "$(date '+%H:%M:%S') - App was dead, attempting restart" >> "$LOG_FILE"
    pm grant com.hypercharge.service android.permission.POST_NOTIFICATIONS >/dev/null 2>&1
    appops set com.hypercharge.service POST_NOTIFICATIONS allow >/dev/null 2>&1
    cmd appops set com.hypercharge.service RUN_IN_BACKGROUND allow >/dev/null 2>&1
    cmd appops set com.hypercharge.service RUN_ANY_IN_BACKGROUND allow >/dev/null 2>&1
    dumpsys deviceidle whitelist +com.hypercharge.service >/dev/null 2>&1
    dumpsys deviceidle tempwhitelist com.hypercharge.service >/dev/null 2>&1
    am startservice --user 0 -n com.hypercharge.service/.NotificationService >/dev/null 2>&1
    am start-foreground-service --user 0 -n com.hypercharge.service/.NotificationService >/dev/null 2>&1
    am start --user 0 -n com.hypercharge.service/.MainActivity >/dev/null 2>&1
    APP_RUNNING=0
    sleep 2
  else
    APP_RUNNING=1
  fi
}

send_notification() {
  MODE="$1"
  TEMP_C="$2"
  BAT="$3"
  CUR_MA="$4"
  APP_NAME="${5:-}"
  REMAINING="${6:-0}"
  TIME_LEFT_PARAM="${7:-0}"
  APP_CHECK_COUNTER=$((APP_CHECK_COUNTER + 1))
  if [ "$APP_CHECK_COUNTER" -ge 30 ] || [ "$APP_RUNNING" -eq 0 ]; then
    APP_CHECK_COUNTER=0
    ensure_app_running
  fi
  am broadcast --user 0 \
    -a com.hypercharge.service.UPDATE_NOTIFICATION \
    -n com.hypercharge.service/.CommandReceiver \
    --es mode "$MODE" --ei temp "$TEMP_C" --ei battery "$BAT" \
    --ei current "${CUR_MA:-0}" --es appname "${APP_NAME:-}" \
    --ei remaining "${REMAINING:-0}" --ei timeleft "${TIME_LEFT_PARAM:-0}" >/dev/null 2>&1
  am broadcast \
    -a com.hypercharge.service.UPDATE_NOTIFICATION \
    -n com.hypercharge.service/.CommandReceiver \
    --es mode "$MODE" --ei temp "$TEMP_C" --ei battery "$BAT" \
    --ei current "${CUR_MA:-0}" --es appname "${APP_NAME:-}" \
    --ei remaining "${REMAINING:-0}" --ei timeleft "${TIME_LEFT_PARAM:-0}" >/dev/null 2>&1
}

is_screen_on() {
  _POWER=$(dumpsys power 2>/dev/null)
  echo "$_POWER" | grep -qE 'mWakefulness=Awake' && {
    dumpsys window 2>/dev/null | grep -q "mShowingDream=false" || true
    ! dumpsys window 2>/dev/null | grep -qE "mDreamingLockscreen=true|isStatusBarKeyguard=true|mKeyguardShowing=true" && return 0
  }
  echo "$_POWER" | grep -qE 'mWakefulnessRaw=Awake' && {
    ! dumpsys window 2>/dev/null | grep -qE "mDreamingLockscreen=true|isStatusBarKeyguard=true|mKeyguardShowing=true" && return 0
  }
  return 1
}

get_foreground_pkg() {
  _DUMP=$(dumpsys window 2>/dev/null)
  _PKG=$(echo "$_DUMP" | grep mCurrentFocus | head -1 | grep -oE '[a-z][a-zA-Z0-9_]*(\.[a-zA-Z0-9_]+)+' | head -1)
  [ -z "$_PKG" ] && _PKG=$(echo "$_DUMP" | grep mFocusedApp | head -1 | grep -oE '[a-z][a-zA-Z0-9_]*(\.[a-zA-Z0-9_]+)+' | head -1)
  echo "$_PKG"
}

get_app_label() {
  _PKG="$1"
  [ -z "$_PKG" ] && echo "" && return
  _LABEL=$(cmd package list packages -f 2>/dev/null | grep "=$_PKG$" | sed 's|.*=||' | head -1)
  [ -z "$_LABEL" ] && _LABEL=$(dumpsys package "$_PKG" 2>/dev/null | grep "versionName\|applicationInfo" | grep -o 'label=0x[0-9a-f]*' | head -1)
  [ -z "$_LABEL" ] && _LABEL=$(aapt dump badging $(pm path "$_PKG" 2>/dev/null | sed "s/package://") 2>/dev/null | grep "application-label:" | sed "s/application-label://;s/'//g" | head -1)
  [ -z "$_LABEL" ] && _LABEL=$(echo "$_PKG" | awk -F. '{print $NF}')
  echo "$_LABEL"
}

is_game_foreground() {
  FG=$(get_foreground_pkg)
  [ -z "$FG" ] && return 1
  for PKG in $GAME_PACKAGES; do
    [ "$FG" = "$PKG" ] && return 0
  done
  return 1
}

should_bypass() {
  CAP=$(read_node /sys/class/power_supply/battery/capacity)
  [ -z "$CAP" ] && CAP=0
  [ "$CAP" -le "$BYPASS_MIN_BATTERY" ] && BYPASS_REENTRY_SINCE=0 && return 1
  is_screen_on || return 1
  is_game_foreground || { TIMER_EXPIRED=0; return 1; }
  [ "$TIMER_EXPIRED" = "1" ] && return 1
  if [ "$LAST_EXIT_REASON" = "LOW_BAT" ]; then
    if [ "$CAP" -lt 25 ]; then
      BYPASS_REENTRY_SINCE=0
      return 1
    fi
    [ "$BYPASS_REENTRY_SINCE" -eq 0 ] && BYPASS_REENTRY_SINCE=$NOW_SEC
    [ $(( NOW_SEC - BYPASS_REENTRY_SINCE )) -lt 20 ] && return 1
    LAST_EXIT_REASON=""
    BYPASS_REENTRY_SINCE=0
  fi
  return 0
}

screen_is_off() {
  is_screen_on && return 1
  return 0
}

apply_current() {
  TARGET="$1"
  for NODE in \
    /sys/class/power_supply/usb/current_max \
    /sys/class/power_supply/usb/hw_current_max \
    /sys/class/power_supply/usb/pd_current_max \
    /sys/class/power_supply/usb/ctm_current_max \
    /sys/class/power_supply/usb/sdp_current_max \
    /sys/class/power_supply/usb/cdp_current_max \
    /sys/class/power_supply/usb/hvdcp_current_max \
    /sys/class/power_supply/ac/current_max \
    /sys/class/power_supply/main/current_max \
    /sys/class/power_supply/main/constant_charge_current_max \
    /sys/class/power_supply/battery/current_max \
    /sys/class/power_supply/battery/constant_charge_current_max \
    /sys/class/power_supply/battery/batt_tune_input_charge_current \
    /sys/class/power_supply/battery/batt_tune_fast_charge_current \
    /sys/class/power_supply/bms/current_max \
    /sys/class/power_supply/bms/constant_charge_current_max \
    /sys/class/power_supply/pc_port/current_max
  do
    write_node "$NODE" "$TARGET"
  done
}

enable_fast_charge() {
  write_node /sys/kernel/fast_charge/force_fast_charge 1
  write_node /sys/kernel/fast_charge/failsafe 1
  write_node /sys/class/power_supply/battery/allow_hvdcp3 1
  write_node /sys/class/power_supply/usb/pd_allowed 1
  write_node /sys/class/power_supply/usb/hvdcp_opti_allowed 1
  write_node /sys/class/power_supply/usb/hvdcp3_allowed 1
  write_node /sys/class/power_supply/battery/hvdcp_opti_allowed 1
  write_node /sys/class/power_supply/battery/fast_charge 1
  write_node /sys/class/power_supply/battery/fastcharger 1
  write_node /sys/class/power_supply/battery/input_current_limited 0
  write_node /sys/class/power_supply/battery/step_charging_enabled 0
  write_node /sys/class/power_supply/battery/fcc_stepper_enable 0
  write_node /sys/class/qcom-battery/restricted_charging 0
  write_node /sys/class/qcom-battery/restricted_current 0
}

exit_game_bypass() {
  send_notification "SWITCHING_NORMAL" "$TEMP_C" "$CAP" "0"
  resume_from_bypass
  echo "$(date '+%H:%M:%S') - GAME bypass exited" >> "$LOG_FILE"
  LAST_MODE="NORMAL"
  LAST_NOTIF_MODE="NORMAL"
  LAST_EXIT=$NOW_SEC
  BYPASS_START=0
  BYPASS_GRACE_COUNT=0
  FULL_SINCE=0
  CHARGING_STOPPED=0
  TEMP_CUTOFF=0
  BYPASS_DETECTED=0
  LAST_CAP=""
  LAST_TEMP_C=""
  LAST_CUR_MA=""
  am stopservice --user 0 -n com.hypercharge.service/.NotificationService >/dev/null 2>&1
  sleep 1
  am start-foreground-service --user 0 -n com.hypercharge.service/.NotificationService >/dev/null 2>&1
  sleep 1
  send_notification "NORMAL" "$TEMP_C" "$CAP" "$CUR_MA"
}

detect_charge_limit_style
detect_force_icl
detect_bypass_method
echo "$(date '+%H:%M:%S') - Charge limit: block=$CHARGE_LIMIT_BLOCK restore=$CHARGE_LIMIT_RESTORE" >> "$LOG_FILE"

while true; do

  LOG_CHECK_COUNT=$(( LOG_CHECK_COUNT + 1 ))
  if [ "$LOG_CHECK_COUNT" -ge 300 ]; then
    LOG_CHECK_COUNT=0
USB_OFF_CONFIRM=0
    LOG_SIZE=$(wc -c < "$LOG_FILE" 2>/dev/null)
    [ -z "$LOG_SIZE" ] && LOG_SIZE=0
    if [ "$LOG_SIZE" -gt "$MAX_LOG_SIZE" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') - Log auto cleared (size: ${LOG_SIZE}b)" > "$LOG_FILE"
    fi
  fi

  TEMP=$(read_node_fb \
    /sys/class/power_supply/battery/temp \
    /sys/class/power_supply/battery/batt_temp \
    /sys/class/power_supply/bms/temp)
  [ -z "$TEMP" ] && TEMP=0
  TEMP_C=$((TEMP / 10))
  TEMP_TENTH=$((TEMP % 10))

  CAP=$(read_node_fb \
    /sys/class/power_supply/battery/capacity \
    /sys/class/power_supply/bms/capacity)
  [ -z "$CAP" ] && CAP=0

  CUR_RAW=$(read_node_fb \
    /sys/class/power_supply/battery/current_now \
    /sys/class/power_supply/bms/current_now)
  [ -z "$CUR_RAW" ] && CUR_RAW=0
  CUR=${CUR_RAW#-}
  if [ "$CUR" -lt 10000 ] && [ "$CUR" -gt 0 ]; then
    CUR=$((CUR * 1000))
  fi

  VOLTAGE=$(read_node_fb \
    /sys/class/power_supply/battery/voltage_now \
    /sys/class/power_supply/bms/voltage_now)
  [ -z "$VOLTAGE" ] && VOLTAGE=0
  VOLTAGE_MV=$((VOLTAGE / 1000))

  USB_ON=0
  for _ONLINE_NODE in \
    /sys/class/power_supply/usb/online \
    /sys/class/power_supply/ac/online \
    /sys/class/power_supply/pc_port/online \
    /sys/class/power_supply/main/online \
    /sys/class/power_supply/wireless/online \
    /sys/class/power_supply/dock/online \
    /sys/class/power_supply/mains/online
  do
    _VAL=$(read_node "$_ONLINE_NODE")
    [ "$_VAL" = "1" ] && USB_ON=1 && break
  done

  if [ "$USB_ON" = "0" ]; then
    _STATUS=$(read_node /sys/class/power_supply/battery/status)
    [ "$_STATUS" = "Charging" ] && USB_ON=1
  fi

  if [ "$USB_ON" = "0" ]; then
    USB_OFF_CONFIRM=$(( USB_OFF_CONFIRM + 1 ))
    [ "$USB_OFF_CONFIRM" -lt 2 ] && USB_ON=1
  else
    USB_OFF_CONFIRM=0
  fi

  if [ "$USB_ON" = "1" ] && [ "$LAST_USB_ON" = "0" ]; then
    echo "$(date '+%H:%M:%S') - Charger connected" >> "$LOG_FILE"
    LAST_CAP=""
    LAST_TEMP_C=""
    LAST_CUR_MA=""
    TIMER_EXPIRED=0
    PREV_NOTIF_MODE=""
    if [ "$LAST_MODE" = "DISCONNECTED" ] || [ "$LAST_MODE" = "INIT" ]; then
      LAST_NOTIF_MODE="INACTIVE"
    fi
    if [ "$BYPASS_DETECTED" = "0" ]; then
      sleep 2
      detect_bypass_method
      BYPASS_DETECTED=1
    fi
  fi
  LAST_USB_ON="$USB_ON"

  NOW_SEC=$(date +%s 2>/dev/null)
  [ -z "$NOW_SEC" ] && NOW_SEC=0

  COUNTER=$((COUNTER + 1))
[ $((COUNTER % 60)) -eq 0 ] && PREV_NOTIF_MODE=""
  if [ $((COUNTER % 20)) -eq 0 ]; then
    echo "$(date '+%H:%M:%S') | Temp: ${TEMP_C}.${TEMP_TENTH}°C | Batt: ${CAP}% | Current: $((CUR/1000))mA | Voltage: ${VOLTAGE_MV}mV | Mode: $LAST_MODE | Tier: $LAST_TIER" >> "$LOG_FILE"
  fi

  CUR_MA=$((CUR/1000))

  TIME_REMAINING=0
  if [ "$CUR_MA" -gt 100 ] && [ "$CAP" -lt 100 ] && [ "$USB_ON" = "1" ] && [ "$CHARGING_STOPPED" -eq 0 ] && [ "$TEMP_CUTOFF" -eq 0 ]; then
    REMAINING_MAH=$(( (100 - CAP) * BATTERY_CAPACITY_MAH / 100 ))
    TIME_REMAINING=$(( REMAINING_MAH * 60 / CUR_MA ))
    [ "$TIME_REMAINING" -gt 480 ] && TIME_REMAINING=0
  fi

  TIME_LEFT=0
  if [ "$USB_ON" = "0" ] && [ "$CAP" -gt 0 ]; then
    _DISCHARGE_MA=$(( CUR / -1000 ))
    [ "$_DISCHARGE_MA" -lt 0 ] && _DISCHARGE_MA=$(( _DISCHARGE_MA * -1 ))
    if [ "$_DISCHARGE_MA" -gt 50 ]; then
      if [ "$DISCHARGE_EMA" -eq 0 ]; then
        DISCHARGE_EMA="$_DISCHARGE_MA"
      else
        _EMA_DROP=$(( DISCHARGE_EMA * 60 / 100 ))
        if [ "$_DISCHARGE_MA" -lt "$_EMA_DROP" ] && [ "$DISCHARGE_EMA" -gt 600 ]; then
          DISCHARGE_EMA="$_DISCHARGE_MA"
        else
          DISCHARGE_EMA=$(( (3 * _DISCHARGE_MA + 7 * DISCHARGE_EMA) / 10 ))
        fi
      fi
      if [ "$DISCHARGE_EMA" -gt 0 ]; then
        CURRENT_MAH=$(( CAP * BATTERY_CAPACITY_MAH / 100 ))
        TIME_LEFT=$(( CURRENT_MAH * 60 / DISCHARGE_EMA ))
        [ "$TIME_LEFT" -gt 960 ] && TIME_LEFT=0
      fi
    fi
  else
    DISCHARGE_EMA=0
  fi

  _NOTIF_VALUES_CHANGED=0
  _TIME_LEFT_DIFF=$(( TIME_LEFT - LAST_SENT_TIME_LEFT ))
  [ "$_TIME_LEFT_DIFF" -lt 0 ] && _TIME_LEFT_DIFF=$(( _TIME_LEFT_DIFF * -1 ))
  _TIME_LEFT_BASE=$(( LAST_SENT_TIME_LEFT > 0 ? LAST_SENT_TIME_LEFT : 1 ))
  _TIME_LEFT_PCT=$(( _TIME_LEFT_DIFF * 100 / _TIME_LEFT_BASE ))
  if [ "$CAP" != "$LAST_CAP" ] || [ "$TEMP_C" != "$LAST_TEMP_C" ] || [ "$CUR_MA" != "$LAST_CUR_MA" ] || [ "$_TIME_LEFT_PCT" -ge 3 ]; then
    _NOTIF_VALUES_CHANGED=1
  fi
  LAST_TIME_LEFT="$TIME_LEFT"

  if [ "$LAST_MODE" = "GAME" ]; then
    if [ "$USB_ON" = "0" ]; then
      BYPASS_GRACE_COUNT=0
      [ -n "$BYPASS_ENFORCER_PID" ] && kill -9 "$BYPASS_ENFORCER_PID" 2>/dev/null
      BYPASS_ENFORCER_PID=""
      pkill -9 -f "input_suspend" 2>/dev/null
      if [ "$BYPASS_METHOD" = "throttle" ]; then
        write_node /sys/class/power_supply/usb/current_max "$ORIG_USB_ICL"
        write_node /sys/class/power_supply/main/current_max "$ORIG_MAIN_ICL"
        write_node /sys/class/power_supply/battery/current_max "$ORIG_USB_ICL"
        [ "$HAS_FORCE_ICL" = "1" ] && echo "$FORCE_ICL_RESTORE" > "$FORCE_ICL_NODE" 2>/dev/null
      fi
      write_node /sys/class/power_supply/battery/input_suspend 0
      write_node /sys/class/power_supply/usb/input_suspend 0
      write_node /sys/class/power_supply/ac/input_suspend 0
      write_node /sys/class/power_supply/main/input_suspend 0
      [ "$HAS_PARALLEL_DISABLE" = "1" ] && write_node /sys/class/power_supply/battery/parallel_disable 0
      [ "$HAS_MTK_BYPASS" = "1" ] && echo 0 0 > /proc/mtk_battery_cmd/current_cmd 2>/dev/null
      dumpsys battery reset >/dev/null 2>&1
      LAST_MODE="DISCONNECTED"
      LAST_NOTIF_MODE="INACTIVE"
      PREV_NOTIF_MODE=""
      BYPASS_START=0
      LAST_EXIT=$NOW_SEC
      TIMER_EXPIRED=0
      if [ "$BYPASS_METHOD" = "throttle" ]; then
        am stopservice --user 0 -n com.hypercharge.service/.NotificationService >/dev/null 2>&1
        sleep 1
        am start-foreground-service --user 0 -n com.hypercharge.service/.NotificationService >/dev/null 2>&1
        sleep 1
      fi
      send_notification "INACTIVE" "$TEMP_C" "$CAP" "0" "" "$TIME_LEFT"
      sleep 0.5
      send_notification "INACTIVE" "$TEMP_C" "$CAP" "0" "" "$TIME_LEFT"
      sleep "$LOOP_DELAY"
      continue
    elif [ "$TEMP" -ge "$VERY_CRITICAL_LIMIT" ]; then
      [ -n "$BYPASS_ENFORCER_PID" ] && kill -9 "$BYPASS_ENFORCER_PID" 2>/dev/null
      BYPASS_ENFORCER_PID=""
      pkill -9 -f "input_suspend" 2>/dev/null
      dumpsys battery reset >/dev/null 2>&1
      TEMP_CUTOFF=1
      LAST_MODE="NORMAL"
      BYPASS_START=0
      BYPASS_GRACE_COUNT=0
      FULL_SINCE=0
      CHARGING_STOPPED=0
      BYPASS_DETECTED=0
      LAST_CAP=""
      LAST_TEMP_C=""
      LAST_CUR_MA=""
      send_notification "INACTIVE" "$TEMP_C" "$CAP" "0" "" "$TIME_LEFT"
      LAST_NOTIF_MODE="INACTIVE"
      PREV_NOTIF_MODE="INACTIVE"
      echo "$(date '+%H:%M:%S') - VERY CRITICAL TEMP in GAME mode: ${TEMP_C}.${TEMP_TENTH}°C — bypass killed, charging cut" >> "$LOG_FILE"
      sleep "$LOOP_DELAY"
      continue
    elif [ $((NOW_SEC - BYPASS_START)) -gt $BYPASS_MAX_SECONDS ]; then
      BYPASS_GRACE_COUNT=0
      TIMER_EXPIRED=1
      exit_game_bypass
      sleep "$LOOP_DELAY"
      continue
    elif screen_is_off; then
      BYPASS_GRACE_COUNT=0
      exit_game_bypass
      sleep "$LOOP_DELAY"
      continue
    elif ! should_bypass; then
      BYPASS_GRACE_COUNT=$((BYPASS_GRACE_COUNT + 1))
 if [ "$BYPASS_GRACE_COUNT" -ge "$BYPASS_GRACE_MAX" ]; then
        BYPASS_GRACE_COUNT=0
        CAP_CHECK=$(read_node /sys/class/power_supply/battery/capacity)
        [ "$CAP_CHECK" -le "$BYPASS_MIN_BATTERY" ] && LAST_EXIT_REASON="LOW_BAT"
        exit_game_bypass
        sleep "$LOOP_DELAY"
        continue
      else
        stop_charging
      fi
    else
      BYPASS_GRACE_COUNT=0
      BYPASS_ELAPSED=$((NOW_SEC - BYPASS_START))
      BYPASS_REMAINING=$(( (BYPASS_MAX_SECONDS - BYPASS_ELAPSED) / 60 ))
      FG_APP=$(get_foreground_pkg)
      FG_LABEL=$(get_app_label "$FG_APP")
      if [ -z "$BYPASS_ENFORCER_PID" ] || ! kill -0 "$BYPASS_ENFORCER_PID" 2>/dev/null; then
        echo "$(date '+%H:%M:%S') - Enforcer died, restarting bypass" >> "$LOG_FILE"
        stop_charging
      fi
      if [ "$BYPASS_REMAINING" != "$LAST_BYPASS_REMAINING" ] || [ "$_NOTIF_VALUES_CHANGED" = "1" ]; then
        send_notification "GAME" "$TEMP_C" "$CAP" "$CUR_MA" "$FG_LABEL" "$BYPASS_REMAINING"
        LAST_CAP="$CAP"
        LAST_TEMP_C="$TEMP_C"
        LAST_CUR_MA="$CUR_MA"
        LAST_BYPASS_REMAINING="$BYPASS_REMAINING"
        PREV_NOTIF_MODE="GAME"
      fi
    fi
    sleep "$LOOP_DELAY"
    continue
  fi

  if [ "$TEMP_CUTOFF" -eq 1 ]; then
    if [ "$TEMP" -lt "$RESTORE_LIMIT" ]; then
      start_charging
      TEMP_CUTOFF=0
      echo "$(date '+%H:%M:%S') - Charging re-enabled, temp dropped to ${TEMP_C}.${TEMP_TENTH}°C (below 46°C)" >> "$LOG_FILE"
      send_notification "NORMAL" "$TEMP_C" "$CAP" "$CUR_MA"
      LAST_NOTIF_MODE="NORMAL"
      LAST_MODE="NORMAL"
      LAST_CAP=""
      LAST_TEMP_C=""
      LAST_CUR_MA=""
    fi
    sleep "$LOOP_DELAY"
    continue
  fi

  if [ "$CHARGING_STOPPED" -eq 1 ]; then
    if [ "$CAP" -lt 100 ]; then
      start_charging
      CHARGING_STOPPED=0
      TEMP_CUTOFF=0
      FULL_SINCE=0
      echo "$(date '+%H:%M:%S') - Charging re-enabled at ${CAP}%" >> "$LOG_FILE"
      send_notification "NORMAL" "$TEMP_C" "$CAP" "$CUR_MA"
      LAST_NOTIF_MODE="NORMAL"
      LAST_MODE="NORMAL"
      LAST_CAP=""
      LAST_TEMP_C=""
      LAST_CUR_MA=""
    fi
    sleep "$LOOP_DELAY"
    continue
  fi

  if [ "$USB_ON" != "1" ]; then
    USB_OFF_COUNT=$((USB_OFF_COUNT + 1))
    FULL_SINCE=0
    TEMP_CUTOFF=0
    if [ "$USB_OFF_COUNT" -eq 1 ]; then
      LAST_NOTIF_MODE="INACTIVE"
    fi
    if [ "$USB_OFF_COUNT" -ge 3 ] && [ "$LAST_MODE" != "GAME" ]; then
      if [ "$LAST_NOTIF_MODE" != "INACTIVE" ] || [ "$_NOTIF_VALUES_CHANGED" = "1" ]; then
        send_notification "INACTIVE" "$TEMP_C" "$CAP" "0" "" "$TIME_LEFT"
        LAST_NOTIF_MODE="INACTIVE"
        LAST_CAP="$CAP"
        LAST_TEMP_C="$TEMP_C"
        LAST_CUR_MA="$CUR_MA"
        PREV_NOTIF_MODE="INACTIVE"
        LAST_SENT_TIME_LEFT="$TIME_LEFT"
      fi
      LAST_MODE="DISCONNECTED"
      dumpsys battery reset >/dev/null 2>&1
      sleep 2
      continue
    fi
    sleep "$LOOP_DELAY"
    continue
  else
    USB_OFF_COUNT=0
  fi

  if [ "$LAST_MODE" != "GAME" ] && [ "$CAP" -ge 100 ]; then
    if [ "$FULL_SINCE" -eq 0 ]; then
      FULL_SINCE=$NOW_SEC
      echo "$(date '+%H:%M:%S') - Battery at 100%, starting stop timer" >> "$LOG_FILE"
    fi
    if [ $((NOW_SEC - FULL_SINCE)) -ge $FULL_CHARGE_STOP_DELAY ]; then
      stop_charging
      CHARGING_STOPPED=1
      send_notification "FULL" "$TEMP_C" "$CAP" "0"
      LAST_NOTIF_MODE="FULL"
      echo "$(date '+%H:%M:%S') - Charging stopped at 100% after 2 minutes" >> "$LOG_FILE"
      sleep "$LOOP_DELAY"
      continue
    fi
  else
    FULL_SINCE=0
  fi

  SHOULD_ENTER=0
  if [ "$USB_ON" = "1" ] && [ $((NOW_SEC - LAST_EXIT)) -gt $EXIT_GRACE ]; then
    if should_bypass; then
      SHOULD_ENTER=1
    fi
  fi

  if [ "$SHOULD_ENTER" = "1" ]; then
    if [ "$LAST_MODE" != "GAME" ]; then
      FG_APP=$(get_foreground_pkg)
      FG_LABEL=$(get_app_label "$FG_APP")
      send_notification "SWITCHING_GAME" "$TEMP_C" "$CAP" "0"
      sleep 4
      stop_charging
      echo "$(date '+%H:%M:%S') - GAME bypass active: $FG_LABEL ($FG_APP) (Batt: ${CAP}%)" >> "$LOG_FILE"
      send_notification "GAME" "$TEMP_C" "$CAP" "0" "$FG_LABEL" "$((BYPASS_MAX_SECONDS / 60))"
      LAST_MODE="GAME"
      LAST_NOTIF_MODE="GAME"
      BYPASS_START=$NOW_SEC
      FULL_SINCE=0
      CHARGING_STOPPED=0
      TEMP_CUTOFF=0
      sleep "$LOOP_DELAY"
      continue
    fi
  else
    if [ "$TEMP" -ge "$VERY_CRITICAL_LIMIT" ]; then
      stop_charging
      TEMP_CUTOFF=1
      send_notification "INACTIVE" "$TEMP_C" "$CAP" "0" "" "$TIME_LEFT"
      LAST_NOTIF_MODE="INACTIVE"
      echo "$(date '+%H:%M:%S') - VERY CRITICAL TEMP: ${TEMP_C}.${TEMP_TENTH}°C" >> "$LOG_FILE"
      LAST_MODE="NORMAL"
    else
      if [ "$LAST_MODE" != "NORMAL" ]; then
        start_charging
        enable_fast_charge
      fi

      if [ "$TEMP" -ge "$CRITICAL_LIMIT" ]; then
        TARGET=$CRITICAL_CURRENT
        TIER="CRITICAL"
      elif [ "$TEMP" -lt "$ULTRA_LIMIT" ]; then
        TARGET=$ULTRA_CURRENT
        TIER="ULTRA"
      elif [ "$TEMP" -lt "$COOL_LIMIT" ]; then
        TARGET=$MAX_CURRENT
        TIER="COOL"
      elif [ "$TEMP" -lt "$COOL_LOW_LIMIT" ]; then
        TARGET=$COOL_LOW_CURRENT
        TIER="COOL_LOW"
      elif [ "$TEMP" -lt "$NORMAL_LIMIT" ]; then
        TARGET=$NORMAL_CURRENT
        TIER="NORMAL"
      elif [ "$TEMP" -lt "$NORMAL_LOW_LIMIT" ]; then
        TARGET=$NORMAL_LOW_CURRENT
        TIER="NORMAL_LOW"
      elif [ "$TEMP" -lt "$WARM_LOW_LIMIT" ]; then
        TARGET=$WARM_LOW_CURRENT
        TIER="WARM_LOW"
      elif [ "$TEMP" -lt "$WARM_LIGHT_LIMIT" ]; then
        TARGET=$WARM_LIGHT_CURRENT
        TIER="WARM_LIGHT"
      elif [ "$TEMP" -lt "$WARM_LIMIT" ]; then
        TARGET=$WARM_CURRENT
        TIER="WARM"
      elif [ "$TEMP" -lt "$WARM_HIGH_LIMIT" ]; then
        TARGET=$WARM_HIGH_CURRENT
        TIER="WARM_HIGH"
      elif [ "$TEMP" -lt "$HOT_LIMIT" ]; then
        TARGET=$HOT_CURRENT
        TIER="HOT"
      elif [ "$TEMP" -lt "$VERY_HOT_LIMIT" ]; then
        TARGET=$VERY_HOT_CURRENT
        TIER="VERY_HOT"
      else
        TARGET=$CRITICAL_CURRENT
        TIER="CRITICAL"
      fi

      if [ "$CAP" -ge 99 ]; then
        [ "$TARGET" -gt "$TRICKLE_CURRENT" ] && TARGET=$TRICKLE_CURRENT
      elif [ "$CAP" -ge 95 ]; then
        [ "$TARGET" -gt "$CAP_95_CURRENT" ] && TARGET=$CAP_95_CURRENT
      elif [ "$CAP" -ge 90 ]; then
        [ "$TARGET" -gt "$CAP_90_CURRENT" ] && TARGET=$CAP_90_CURRENT
      elif [ "$CAP" -ge 85 ]; then
        [ "$TARGET" -gt "$CAP_85_CURRENT" ] && TARGET=$CAP_85_CURRENT
      fi

      if [ "$TIER" != "$LAST_TIER" ]; then
        echo "$(date '+%H:%M:%S') - Thermal tier: $LAST_TIER -> $TIER (${TEMP_C}.${TEMP_TENTH}°C)" >> "$LOG_FILE"
        LAST_TIER="$TIER"
        enable_fast_charge
      fi

      apply_current "$TARGET"
      write_node /sys/class/power_supply/battery/input_current_limited 0


      LAST_NOTIF_MODE="NORMAL"
      LAST_MODE="NORMAL"
    fi
  fi

  if [ "$USB_ON" = "1" ]; then
    if [ "$LAST_NOTIF_MODE" != "$PREV_NOTIF_MODE" ] || [ "$_NOTIF_VALUES_CHANGED" = "1" ]; then
      if [ "$LAST_MODE" = "GAME" ]; then
        send_notification "$LAST_NOTIF_MODE" "$TEMP_C" "$CAP" "$CUR_MA" "$FG_LABEL" "$BYPASS_REMAINING" "0"
      else
        send_notification "$LAST_NOTIF_MODE" "$TEMP_C" "$CAP" "$CUR_MA" "" "$TIME_REMAINING" "0"
      fi
      LAST_CAP="$CAP"
      LAST_TEMP_C="$TEMP_C"
      LAST_CUR_MA="$CUR_MA"
      PREV_NOTIF_MODE="$LAST_NOTIF_MODE"
    fi
  elif [ "$USB_ON" = "0" ]; then
    if [ "$LAST_NOTIF_MODE" != "$PREV_NOTIF_MODE" ] || [ "$_NOTIF_VALUES_CHANGED" = "1" ]; then
      send_notification "$LAST_NOTIF_MODE" "$TEMP_C" "$CAP" "0" "" "$TIME_LEFT"
      LAST_CAP="$CAP"
      LAST_TEMP_C="$TEMP_C"
      LAST_CUR_MA="$CUR_MA"
      PREV_NOTIF_MODE="$LAST_NOTIF_MODE"
    fi
  fi

  sleep $LOOP_DELAY
done
