#!/bin/sh
sleep 5
hciconfig hci0 up
cd /root/intro-to-ble/raspi_ble
/usr/bin/node ble.js &
