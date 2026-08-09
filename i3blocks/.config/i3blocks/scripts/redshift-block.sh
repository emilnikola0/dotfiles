#!/usr/bin/env bash
#
# i3blocks script for redshift.
# Shows "REDSHIFT: <temp>" and toggles redshift on/off on click.
#
# i3blocks config entry:
#
# [redshift]
# command=~/.config/i3blocks/scripts/redshift-block.sh
# interval=5
# LABEL=REDSHIFT

STATE_FILE="/tmp/redshift-block-state"
PID_FILE="/tmp/redshift-block-pid"
LOCATION="49.59:17.25"   # lat:lon — avoids slow/hanging geoclue2 lookup

# Click handling: button 1 = left click, toggles redshift on/off
if [[ "$BLOCK_BUTTON" == "1" ]]; then
    if [[ -f "$STATE_FILE" ]]; then
        # currently on -> turn off
        if [[ -f "$PID_FILE" ]]; then
            kill "$(cat "$PID_FILE")" 2>/dev/null
            rm -f "$PID_FILE"
        fi
        redshift -x >/dev/null 2>&1  # reset screen to no adjustment
        rm -f "$STATE_FILE"
    else
        # currently off -> turn on
        nohup redshift -l "$LOCATION" -t 6500:3000 -r >/dev/null 2>&1 &
        echo "$!" > "$PID_FILE"
        disown
        touch "$STATE_FILE"
    fi
fi

# Status output (label is handled by i3blocks LABEL= in the config)
if [[ -f "$STATE_FILE" ]]; then
    echo "ON"
else
    echo "OFF"
fi
