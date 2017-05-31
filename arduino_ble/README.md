Intro to BLE (Arduino Peripheral)
=============

This Arduino is programmed to act as a Bluetooth Low Energy peripheral as part of my talk on the introduction to BLE.

![Screen](misc/front.jpg)

## Arduino Setup

1. Download and install the latest [Arduino IDE](https://www.arduino.cc/en/main/software) which is version 1.8.2 at the time of writing.
2. Open the `arduino_ble` file with the Arduino IDE and
3. Sketch -> Include Library -> Manage Libraries. Search and install BLEPeripheral by Sandeep Mistry.
4. Select Arduino/Genuino Uno as the board type. Make sure to choose the correct serial port associated Arduino.
5. Just hit upload button to program the board.

## Parts used
1. Arduino Uno R3
2. RedBearLab BLE (Single-Mode) Shield v.1.1 (NRF8001 chipset)
3. Red LED
4. Green LED
5. Blue LED
6. Yellow LED
7. 4x 220ohm resistors
8. Push Button

![Screen](misc/schematic.png)

BLE Shield is not shown in the schematic.

## Software/Libraries used
1. Arduino IDE 1.8.2
2. [Arduino BLE Peripheral by sandeepmistry.](https://github.com/sandeepmistry/arduino-BLEPeripheral)
