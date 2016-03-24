//Import libraries
var bleno = require('bleno');
var Gpio = require('onoff').Gpio;


//Define GPIO pin constants
var PIN_RED_LED = 22;
var PIN_GREEN_LED = 27;
var PIN_BLUE_LED = 17;
var PIN_YELLOW_LED = 24;
var PIN_BUTTON = 23;

//Set LED pin functions
var ledRed = new Gpio(PIN_RED_LED, 'high'); //Output with initial value high
var ledGreen = new Gpio(PIN_GREEN_LED, 'low'); //Output with initial value low
var ledBlue = new Gpio(PIN_BLUE_LED, 'low');
var ledYellow = new Gpio(PIN_YELLOW_LED, 'low');

//Set button to be interrupt ready
var button = new Gpio(PIN_BUTTON, 'in', 'falling');

//Attach interrupt (callback) function on button press
button.watch(buttonPressed);

//Accept only one button input every 0.3s
var DEBOUNCE_TIME = 300 //0.3s

//Initialise the last time the button is pressed
var lastPressedTime = Date.now();

//Initial characteristic value for button is 0
var buttonCharValue = 0;


//To hold the callback once central registers to be notified
var charButtonNotification;


//Callback on button pressed
function buttonPressed(err, value){

	var currentTime = Date.now()

    //This code is to debounce the button input.
    if((currentTime - lastPressedTime) >= DEBOUNCE_TIME){
        lastPressedTime = currentTime;

        buttonCharValue += 1;
        console.log("Sending \"" + buttonCharValue + "\" to central");


        //Only attempt to send notification if callback is set
        if(charButtonNotification){

            var numString = buttonCharValue.toString()
            
            //Convert number to buffer as that is what the API requires
            var buf = new Buffer(numString, 'ascii')
            charButtonNotification(buf);
        }
    }

}



var currentBlueLEDStatus = false;
var currentYellowLEDStatus = false;


function toggleBlueLED(){
    currentBlueLEDStatus = !currentBlueLEDStatus;

    if(currentBlueLEDStatus){
        ledBlue.write(1);
    } else {
        ledBlue.write(0);
    }
}



function toggleYellowLED(){
    currentYellowLEDStatus = !currentYellowLEDStatus;

    if(currentYellowLEDStatus){
        ledYellow.write(1);
    } else {
        ledYellow.write(0);
    }
}



function refreshConnectionLED(isConnected){
    if(isConnected){
        ledGreen.write(1);
        ledRed.write(0);
    } else {
        ledGreen.write(0);
        ledRed.write(1);
    }
}




//The Bleno library uses the hostname for the device name which in this case is "alarmpi"
var localName = 'Intro to Raspi BLE';

//Define all the UUID constants
//Custom UUIDs must be specified with the full 128 bits
var UUID_service1     = '12345678-9012-3456-7890-123456789012';
var UUID_char_led     = '00000000-0000-0000-0000-000000000010';
var UUID_char_button  = '00000000-0000-0000-0000-000000000020';

//Put service UUID into array
var serviceUuids = [UUID_service1];

var Characteristic = bleno.Characteristic;

//Create the characteristics
var char_led  = new Characteristic({
uuid: UUID_char_led,
properties: ['read', 'writeWithoutResponse'],
secure: [ ],
value: null,
descriptors: [],
onReadRequest: null,
onWriteRequest: onCharLedWritten, //Attach callback function to receive new value sent from central
onSubscribe: null,
onUnsubscribe: null,
onNotify: null
});

var char_button = new Characteristic({
uuid: UUID_char_button,
properties: ['read', 'notify'],
secure: [ ],
value: null,
descriptors: [],
onReadRequest: null,
onWriteRequest: null,
onSubscribe: function(maxValueSize, updateValueCallback) {
        
        //The maxValueSize obtained may be >20 but to be safe, we ignore this and send in chunks of 20.
        console.log("central onSubscribe, maxValueSize " + maxValueSize);

        //Once central subscribes to be notified on this characteristic,
        //we store this function so this peripheral can send data back.
        charButtonNotification = updateValueCallback;
    },
onUnsubscribe: null,
onNotify: null
});


//Create one service
var service1 = new bleno.PrimaryService({
uuid: UUID_service1,
//Associate the characteristics with the service
characteristics: [char_led, char_button]
});


bleno.on('stateChange', function(state) {
    console.log('on -> stateChange: ' + state);

    if (state === 'poweredOn') {
        //We only start advertising if bleno senses the Bluetooth is ready
        //Advertise with GAP data
        bleno.startAdvertising(localName, serviceUuids);
    }

});


bleno.on('advertisingStart', function(error) {
    console.log('on -> advertisingStart: ' + (error ? 'error ' + error : 'success'));
                
    if (!error) {
        //If advertising starts with no problem, we tell bleno to "lock in" those services
        bleno.setServices([service1]);
    }
});


bleno.on('accept', function(clientAddress){
    console.log('Connected: ' + clientAddress);

    //Turn green LED on
    refreshConnectionLED(true);
});

bleno.on('disconnect', function(clientAddress){
        
    console.log('Disconnected ' + clientAddress);
    
    //This notification function is no longer valid so set to null
    charButtonNotification = null;

    
    //Turn red LED on
    refreshConnectionLED(false);
});


function onCharLedWritten(data, offset, withoutResponse, callback) {

    var dataString = data.toString('ascii');
    console.log("Received \"" + dataString + "\" from central");

    if(dataString == 'b'){
        toggleBlueLED();
    } else if (dataString == 'y') {
        toggleYellowLED();
    }

    //If there is a response needed, we have to notify the central that we have successfully received the data
    //This branch of code will never be executed as withoutResponse will always be true but I just include it as reference.
    if(!withoutResponse){
        callback(Characteristic.RESULT_SUCCESS);
    }
}
