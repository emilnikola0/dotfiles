#!/bin/bash
if xrandr | grep -q "^HDMI-1 connected"; then
    xrandr --output eDP-1 --primary --mode 2880x1800 --pos 0x0 \
           --output HDMI-1 --auto --left-of eDP-1
else
    xrandr --output eDP-1 --primary --mode 2880x1800 --pos 0x0 \
           --output HDMI-1 --off \
           --output DP-1 --off \
           --output DP-2 --off
fi
