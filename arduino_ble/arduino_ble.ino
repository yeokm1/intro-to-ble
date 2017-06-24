// Import libraries (BLEPeripheral depends on SPI)
#include <SPI.h>
#include <BLEPeripheral.h>

#define MAX_NUMBER_OF_BYTES_PER_WRITE 20

// BLE Shield Pin setup for BLEShield v1.1
#define BLE_REQ 9
#define BLE_RDY 8
#define BLE_RST UNUSED //BLEShield v1.1 has no RST pin

//Define GPIO pin constants
#define PIN_RED_LED A0
#define PIN_GREEN_LED A1
#define PIN_BLUE_LED A2
#define PIN_YELLOW_LED A3
#define PIN_BUTTON A5

//Accept only one button input every 0.3s
#define DEBOUNCE_TIME 300 //0.3s

//Instantiate peripheral based on BLEShield v1.1 settings
BLEPeripheral blePeripheral = BLEPeripheral(BLE_REQ, BLE_RDY, BLE_RST);

//Create one service (Custom UUIDs must be specified with the full 128 bits)
BLEService service1 = BLEService("12345678-9012-3456-7890-123456789012");

// create one or more characteristics to be associated to a service.
//This characteristic holds a single char (byte)
BLECharCharacteristic char_led = BLECharCharacteristic("00000000-0000-0000-0000-000000000010", BLERead | BLEWriteWithoutResponse);

//This characteristic holds a string with the initial value "00"
BLECharacteristic char_button = BLECharacteristic("00000000-0000-0000-0000-000000000020", BLERead | BLENotify,  "00");


bool blueLEDState = false;
bool yellowLEDState = false;

//Initial characteristic value for button is 0
int buttonCharValue = 0;

//Initialise the last time the button is pressed
long buttonLastPressedTime = millis();


//Runs only once the when the device is started
void setup() {
  Serial.begin(9600);

  //Initialise LEDS
  pinMode(PIN_RED_LED, OUTPUT);
  pinMode(PIN_GREEN_LED, OUTPUT);
  pinMode(PIN_BLUE_LED, OUTPUT);
  pinMode(PIN_YELLOW_LED, OUTPUT);

  //Initialise button using internal pull-up resistor. Default: 1, Pressed: 0
  pinMode(PIN_BUTTON, INPUT_PULLUP);

  //Device name: usually general type of device.
  //Android does not show the device name, it only shows the local name.
  blePeripheral.setDeviceName("YKM's Arduino");

  //Local name: To distinguish function of device. Up to 20 characters for NRF8001
  blePeripheral.setLocalName("Intro to Arduino BLE");

  //Usually true unless you are building an iBeacon-like device
  blePeripheral.setConnectable(true);

  //Put the service UUID(s) into the advertisement packet
  blePeripheral.setAdvertisedServiceUuid(service1.uuid());

  /* For this library, you have to add the services and characteristics recursively in this order

    1. Service 1
    2.   - Characteristic 1 for Service 1
    3.      - Optional Descriptor for Char 1, Service 1
    4.   - Characteristic 2 for Service 1
    5.      - Optional Descriptor for Char 2, Service 1
    6. Other characteristics for Service 1 ...
    7. Service 2
    8. Characteristic 1 for Service 2
    9. Characteristic 2 for Service 2
    9. Other characteristics for Service 2 ,,,
    10. Other services ...

  */

  blePeripheral.addAttribute(service1);
  blePeripheral.addAttribute(char_led);
  blePeripheral.addAttribute(char_button);

  //Set the function to call when the central as written a new value to this characteristic
  char_led.setEventHandler(BLEWritten, characteristicWritten);

  //Set advertising interval to 1 second to prevent spamming the airwaves and the BLE Sniffer
  blePeripheral.setAdvertisingInterval(1000);

  // begin initialization
  blePeripheral.begin();

  Serial.println("Peripheral Started");

}

//Runs repeatedly like while(true)
void loop() {

  //Will get a reference if the central is connected or else it will be null
  BLECentral central = blePeripheral.central();


  //If there is a active connection to Central
  if (central) {
    refreshConnectionLED(true);

    Serial.print("Connected to central: ");
    Serial.println(central.address());

    //Conduct BLE operations while connected to central in this while loop
    while (central.connected()) {

      long currentTime = millis();

      int buttonState = digitalRead(PIN_BUTTON);

      //This code is to debounce the button input.
      if(buttonState == LOW && ((currentTime - buttonLastPressedTime) > DEBOUNCE_TIME)){
        buttonLastPressedTime = currentTime;

        //Increment and convert number to string
        buttonCharValue++;
        char buff[MAX_NUMBER_OF_BYTES_PER_WRITE];
        sprintf(buff, "%d", buttonCharValue);

        Serial.print("Sending \"");
        Serial.print(buttonCharValue);
        Serial.println("\" to central");

        //Write new string to characteristic for central to detect
        char_button.setValue(buff);
      }

    }

  } else {
    refreshConnectionLED(false);
  }
}

void refreshConnectionLED(bool isConnected){
  if(isConnected){
    digitalWrite(PIN_GREEN_LED, HIGH);
    digitalWrite(PIN_RED_LED, LOW);
  } else {
    digitalWrite(PIN_GREEN_LED, LOW);
    digitalWrite(PIN_RED_LED, HIGH);
  }
}

void toggleBlueLED(){
   blueLEDState = !blueLEDState;
   digitalWrite(PIN_BLUE_LED, blueLEDState);
}

void toggleYellowLED(){
   yellowLEDState = !yellowLEDState;
   digitalWrite(PIN_YELLOW_LED, yellowLEDState);
}

//Callback for characteristic write by central
void characteristicWritten(BLECentral& central, BLECharacteristic& characteristic) {

  //Just to ensure it is the correct characteristic that is written to
  if(&char_led == &characteristic){

    char newCharValue = char_led.value();

    Serial.print("Received \"");
    Serial.print(newCharValue);
    Serial.println("\" from central");

    if(newCharValue == 'b'){
      toggleBlueLED();
    } else if(newCharValue == 'y'){
      toggleYellowLED();
    }
  }
}
