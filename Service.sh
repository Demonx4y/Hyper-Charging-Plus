#!/system/bin/sh
MODDIR=${0%/*}

sleep 12

chmod 777 /sys/class/power_supply/*/* 2>/dev/null
chmod 777 /sys/kernel/*/* 2>/dev/null
chmod 777 /sys/module/*/* 2>/dev/null

COOL_LIMIT=400
WARM_LIMIT=420
HOT_LIMIT=440
CRITICAL_LIMIT=460

MAX_CURRENT=8500000
WARM_CURRENT=3000000
HOT_CURRENT=2000000
CRITICAL_CURRENT=1500000
MIN_CURRENT=2500000

LOOP_DELAY=0.6

write_node() {
  [ -f "$1" ] && echo "$2" > "$1" 2>/dev/null
}

read_node() {
  [ -f "$1" ] && cat "$1" 2>/dev/null
}

while true; do

  STATUS=$(read_node /sys/class/power_supply/battery/status)
  [ "$STATUS" != "Charging" ] && sleep 2 && continue

  TEMP=$(read_node /sys/class/power_supply/battery/temp)
  [ -z "$TEMP" ] && TEMP=0

  echo 1 > /sys/kernel/fast_charge/force_fast_charge 2>/dev/null
  echo 1 > /sys/kernel/fast_charge/failsafe 2>/dev/null

  write_node /sys/class/power_supply/battery/allow_hvdcp3 1
  write_node /sys/class/power_supply/usb/pd_allowed 1
  write_node /sys/class/power_supply/battery/input_current_limited 0
  write_node /sys/class/qcom-battery/restricted_charging 0
  write_node /sys/class/qcom-battery/restricted_current 0

  if [ "$TEMP" -lt "$COOL_LIMIT" ]; then
    TARGET=$MAX_CURRENT
  elif [ "$TEMP" -lt "$WARM_LIMIT" ]; then
    TARGET=$WARM_CURRENT
  elif [ "$TEMP" -lt "$HOT_LIMIT" ]; then
    TARGET=$HOT_CURRENT
  else
    TARGET=$CRITICAL_CURRENT
  fi

  for NODE in \
    /sys/class/power_supply/usb/current_max \
    /sys/class/power_supply/usb/hw_current_max \
    /sys/class/power_supply/usb/pd_current_max \
    /sys/class/power_supply/usb/ctm_current_max \
    /sys/class/power_supply/main/current_max \
    /sys/class/power_supply/main/constant_charge_current_max \
    /sys/class/power_supply/battery/current_max \
    /sys/class/power_supply/battery/constant_charge_current_max \
    /sys/class/power_supply/pc_port/current_max
  do
    write_node "$NODE" "$TARGET"
  done

  CUR=$(read_node /sys/class/power_supply/battery/current_now | tr -d '-')

  if [ -n "$CUR" ] && \
     [ "$CUR" -lt "$MIN_CURRENT" ] && \
     [ "$TEMP" -lt "$HOT_LIMIT" ]; then
    write_node /sys/class/power_supply/usb/current_max "$MIN_CURRENT"
  fi

  sleep $LOOP_DELAY
done
