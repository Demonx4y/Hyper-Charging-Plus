#!/system/bin/sh
am force-stop com.hypercharge.service 2>/dev/null
am kill com.hypercharge.service 2>/dev/null

for PID in $(ps -A 2>/dev/null | grep "com.hypercharge" | awk '{print $1}'); do
  kill -9 "$PID" 2>/dev/null
done

pm clear com.hypercharge.service 2>/dev/null

dumpsys deviceidle whitelist -com.hypercharge.service 2>/dev/null

pm revoke com.hypercharge.service android.permission.POST_NOTIFICATIONS 2>/dev/null
pm revoke com.hypercharge.service android.permission.FOREGROUND_SERVICE 2>/dev/null
pm revoke com.hypercharge.service android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS 2>/dev/null

cmd appops set com.hypercharge.service POST_NOTIFICATIONS default 2>/dev/null
cmd appops set com.hypercharge.service RUN_IN_BACKGROUND default 2>/dev/null
cmd appops set com.hypercharge.service RUN_ANY_IN_BACKGROUND default 2>/dev/null

pm uninstall --user 0 com.hypercharge.service 2>/dev/null
pm uninstall com.hypercharge.service 2>/dev/null
pm uninstall -k --user 0 com.hypercharge.service 2>/dev/null

rm -rf /data/app/com.hypercharge.service* 2>/dev/null
rm -rf /data/app/*/com.hypercharge.service* 2>/dev/null
rm -rf /data/data/com.hypercharge.service 2>/dev/null
rm -rf /data/user/0/com.hypercharge.service 2>/dev/null
rm -rf /data/user_de/0/com.hypercharge.service 2>/dev/null

cmd notification delete_channel com.hypercharge.service 2>/dev/null

for PID in $(ps -A 2>/dev/null | grep "service.sh" | awk '{print $1}'); do
  kill -9 "$PID" 2>/dev/null
done

sleep 3

rm -f /sdcard/hyper_charge.log 2>/dev/null
rm -f /sdcard/hyper_charge.log 2>/dev/null
sync
rm -f /sdcard/hyper_charge.log 2>/dev/null
rm -f /sdcard/Android/data/com.hypercharge.service 2>/dev/null

cmd package reconcile 2>/dev/null
pm reconcile-secondary-dex-files com.hypercharge.service 2>/dev/null

echo '#!/system/bin/sh
until [ -d /sdcard/Android ]; do sleep 1; done
rm -f /sdcard/hyper_charge.log 2>/dev/null
rm -f /data/local/tmp/hc_cleanup.sh 2>/dev/null' > /data/local/tmp/hc_cleanup.sh
chmod +x /data/local/tmp/hc_cleanup.sh
nohup sh /data/local/tmp/hc_cleanup.sh >/dev/null 2>&1 &
