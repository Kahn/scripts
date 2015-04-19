#!/usr/bin/env bash

# Startup script for raspberrypi for ADS-B monitoring

set -u
set -e
set -x

FR24_KEY=$1
EMAIL=$2

screen -S dump1090 -d -m /home/pi/dump1090/dump1090 --net
sleep 5
screen -S fr24 -d -m /home/pi/fr24feed_arm-rpi_242 --fr24key=$FR24_KEY
sleep 5
STATUS="Pi started; dump1090 PID: `pidof dump1090` FR24 PID: `pidof fr24feed_arm-rpi_242`"
echo $STATUS | mail $EMAIL
echo $STATUS | logger
