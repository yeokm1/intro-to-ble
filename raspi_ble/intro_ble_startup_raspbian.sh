#!/bin/sh
sleep 5
hciconfig hci0 up
cd /home/pi/intro-to-ble/raspi_ble
/usr/local/bin/node ble.js &
