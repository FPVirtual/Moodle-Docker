#!/bin/bash

# Lanzamos script expect para evitar la interacción en el proceso upgrade de moodle
cat > /tmp/actualiza <<'EOF'
#!/usr/bin/expect -f
set timeout -1
spawn php /var/www/html/admin/cli/upgrade.php
expect "(para no)"
send -- "s"
send -- "\r"
expect eof
EOF
chmod 744 /tmp/actualiza
/tmp/actualiza

# Añadido para moodle4
echo >&2 "Deactivate course enddate by default"
moosh -n config-set courseenddateenabled 0 moodlecourse

echo >&2 "Deactivate dates for assign"
moosh -n config-set enabletimelimit 1 assign
moosh -n config-set duedate_enabled '' assign
moosh -n config-set cutoffdate_enabled '' assign
moosh -n config-set gradingduedate_enabled '' assign

echo >&2 "Topic format by default"
moosh -n config-set format topics moodlecourse

echo >&2 "Activating time limit at assign activities"
moosh -n config-set enabletimelimit 1 assign

echo >&2 "Max file size 192MB"
moosh -n config-set maxbytes 201326592

echo >&2 "Max upload size"
moosh -n config-set maxbytes 201326592

echo >&2 "Activating Mobile configuration for push notifications"
moosh -n config-set airnotifierurl "https://bma.messages.moodle.net"
moosh -n config-set airnotifiermobileappname "es.aragon.fpdistancia"
moosh -n config-set airnotifierappname "esaragonfpdistancia"
moosh -n config-set airnotifieraccesskey "1e6698fd71bad502044c09a4f547f65c"

echo >&2 "Deactivating analytics"
moosh -n config-set enableanalytics 0

echo >&2 "moodle.sh done"
