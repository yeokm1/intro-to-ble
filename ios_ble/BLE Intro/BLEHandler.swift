//
//  BLEHandler.swift
//  BLE Intro
//
//  Created by Yeo Kheng Meng on 3/4/15.
//  Copyright (c) 2015 Yeo Kheng Meng. All rights reserved.
//

import Foundation
import CoreBluetooth


//We have to extend NSObject as well as there is some issues with only implementing the CBCentralManagerDelegate 
//(Guessing it is Swift issue with implementing some Objective-C delegates)
class BLEHandler : NSObject, CBCentralManagerDelegate, CBPeripheralDelegate{
    
    let TAG = "BLEHandler"
    
    let UUID_SERVICE : CBUUID     = CBUUID(string: "12345678-9012-3456-7890-123456789012")
    let UUID_CHAR_LED : CBUUID    = CBUUID(string: "00000000-0000-0000-0000-000000000010")
    let UUID_CHAR_BUTTON : CBUUID = CBUUID(string: "00000000-0000-0000-0000-000000000020")
    
    //CBCentralManager: To manage BLE operations
    var centralManager : CBCentralManager!
    var delegate : BLEHandlerDelegate!
    
    
    //We will receive advertisement packets continuously depending on scan options, so we use this Dictionary to keep track of what has been found so far.
    var foundDevices : [UUID : CBPeripheral]!
    
    var currentConnectedDevice : CBPeripheral?
    var current_char_led : CBCharacteristic?
    var current_char_button : CBCharacteristic?
    

    
    init(delegate : BLEHandlerDelegate){
        super.init()
        self.delegate = delegate
        
        //Nil queue means the main queue. You might not want to use the main queue if you are doing heavy work on receiving callbacks
        centralManager = CBCentralManager(delegate: self, queue: nil)
        foundDevices = [UUID : CBPeripheral]()
    }
    
    
    func disconnectCurrentlyConnectedDevice(){
        if(currentConnectedDevice != nil){
            centralManager.cancelPeripheralConnection(currentConnectedDevice!)
        }
    }

    
    func bleScan(start: Bool){
        if(start){
            //Step 1: Start scanning
            
            foundDevices.removeAll()
            centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey : true])
            
            //centralManager.scanForPeripherals(withServices: nil, options: nil)
        } else {
            centralManager.stopScan()
        }
    }
    
    
    
    //CBCentralDelegate
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi: NSNumber) {
        
        //Step 2 : Received advertisement packet
        
        let deviceName : String? = peripheral.name;

        if(deviceName != nil){
            let localName : String? = advertisementData[CBAdvertisementDataLocalNameKey] as? String
            
            if(localName != nil
                //Check if I have seen advertisement packets from this device before
                && foundDevices[peripheral.identifier] == nil){
     
                
                NSLog("%@: discovered %@, localname %@, rssi:%d", TAG, peripheral.description, localName!, rssi.intValue)
                
                foundDevices.updateValue(peripheral, forKey: peripheral.identifier)
                
                delegate.newDeviceScanned(deviceName: deviceName!, localName : localName!, uuid: peripheral.identifier, rssi: rssi.intValue, advertisementData: advertisementData as [NSObject : AnyObject]!)
            }
        }

    }
    
    //Public facing connect method
    
    func connectToDevice(uuid : UUID!) -> Bool{
        
        //Step 2.5: Connect to device
        
        let device : CBPeripheral? = foundDevices[uuid]
        
        if(device == nil){
            return false
        } else {
            //Good practice to stop scan before start connecting
            bleScan(start: false)
            centralManager.connect(device!, options: nil)
            return true
        }
        
        
    }
    
    
    //CBCentralDelegate
    
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        NSLog("%@: connected to %@", TAG, peripheral.name!)
        
        //Step 3: Connect success
        
        currentConnectedDevice = peripheral
        
        //Discover all services
        peripheral.delegate = self
        peripheral.discoverServices(nil)
        
        delegate.connectionState(deviceName: peripheral.name!, state: true)
        
        
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        NSLog("%@: failed to connect to %@", TAG, peripheral.name!)
        
        delegate.connectionState(deviceName: peripheral.name!, state: false)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        NSLog("%@: disconnected from %@", TAG, peripheral.name!)
        currentConnectedDevice = nil
        current_char_led = nil
        current_char_button = nil
        
        delegate.connectionState(deviceName: peripheral.name!, state: false)
    }
    
    
    
    //Reference http://www.raywenderlich.com/52080/introduction-core-bluetooth-building-heart-rate-monitor
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // Determine the state of the Central
        
        if (central.state.rawValue == CBCentralManagerState.poweredOff.rawValue) {
            NSLog("%@ CoreBluetooth BLE hardware is powered off", TAG);
        }
        else if (central.state.rawValue == CBCentralManagerState.poweredOn.rawValue) {
            NSLog("%@ CoreBluetooth BLE hardware is powered on and ready", TAG);
        }
        else if (central.state.rawValue == CBCentralManagerState.unauthorized.rawValue) {
            NSLog("%@ CoreBluetooth BLE state is unauthorized", TAG);
        }
        else if (central.state.rawValue == CBCentralManagerState.unknown.rawValue) {
            NSLog("%@ CoreBluetooth BLE state is unknown", TAG);
        }
        else if (central.state.rawValue == CBCentralManagerState.unsupported.rawValue) {
            NSLog("%@ CoreBluetooth BLE hardware is unsupported on this platform", TAG);
        }
    }
    
    
    //CBPeripheralDelegate
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        NSLog("%@: Services Discovered for %@", TAG, peripheral.name!)
        
        //Step 4: Services discovered
        
        let services : [CBService]? = peripheral.services
        
        
        if(services != nil){
            for cbService in services! {
                if(cbService.uuid == UUID_SERVICE){
                    
                    peripheral.discoverCharacteristics(nil, for: cbService)
                    break
                }
            }
        }
        
        
        delegate.servicesDiscovered(deviceName: peripheral.name!)
        
  
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        NSLog("%@: Characteristics discovered for %@, of service %@", TAG, peripheral.name!, service.uuid.uuidString)
        
        //Step 5: Characteristics discovered. We can usually stop here as we don't normally need to discover descriptors.
      
        let characteristics : [CBCharacteristic]? = service.characteristics
        
        if(characteristics != nil){
            for cbCharacteristic in characteristics! {
                
                if(cbCharacteristic.uuid == UUID_CHAR_LED){
                    current_char_led = cbCharacteristic
                } else if (cbCharacteristic.uuid == UUID_CHAR_BUTTON){
                    current_char_button = cbCharacteristic
                    
                    
                    //Apply to be notified so we can listen to changes in button characteristic
                    peripheral.setNotifyValue(true, for: current_char_button!)
                    
                }
                
                
                
            }
        }
        


        delegate.characteristicsDiscoveredFor(deviceName: peripheral.name!)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {

        
        if(characteristic.uuid == UUID_CHAR_BUTTON){
            let charValue : Data? = characteristic.value
            
            if(charValue != nil){

                var dataStr: String? = String(data: charValue!, encoding: .ascii)
                
                if(dataStr == nil){
                    dataStr = "blank"
                }
                
                NSLog("%@: Characteristic changed for %@ with value %@", TAG, peripheral.name!, dataStr!)
                
                delegate.receivedStringValue(deviceName: peripheral.name!, dataStr: dataStr!)
            }
            

        }
 
    }
    
    
    //Public facing toggle LED methods
    
    func sendToggleBlueCommand(){
        writeThisToLEDCharacteristic(stringToWrite: "b")
    }
    
    func sendToggleYellowCommand(){
        writeThisToLEDCharacteristic(stringToWrite: "y")
    }
    
    
    func writeThisToLEDCharacteristic(stringToWrite : NSString){
        if(currentConnectedDevice != nil && current_char_led != nil){
            
            let data : NSData = stringToWrite.data(using: String.Encoding.ascii.rawValue)! as NSData
            
            NSLog("%@: writeThisToLedChar %@ to peripheral", TAG, stringToWrite)
            
            currentConnectedDevice?.writeValue(data as Data, for: current_char_led!, type: CBCharacteristicWriteType.withoutResponse)
            
        }
    }
    
    
    
}
