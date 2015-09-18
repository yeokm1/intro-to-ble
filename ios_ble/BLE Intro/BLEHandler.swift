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
    
    
    //We will receive advertisement packets continuously, so we use this Dictionary to keep track of what has been found so far.
    var foundDevices : NSMutableDictionary!
    
    var currentConnectedDevice : CBPeripheral?
    var current_char_led : CBCharacteristic?
    var current_char_button : CBCharacteristic?
    

    
    init(delegate : BLEHandlerDelegate){
        super.init()
        self.delegate = delegate
        centralManager = CBCentralManager(delegate: self, queue: nil)
        foundDevices = NSMutableDictionary()
    }
    
    
    func disconnectCurrentlyConnectedDevice(){
        if(currentConnectedDevice != nil){
            centralManager.cancelPeripheralConnection(currentConnectedDevice!)
        }
    }

    
    func bleScan(start: Bool){
        if(start){
            //Step 1: Start scanning
            
            foundDevices.removeAllObjects()
            centralManager.scanForPeripheralsWithServices(nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey : true])
        } else {
            centralManager.stopScan()
        }
    }
    
    
    
    //CBCentralDelegate
    
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        
        //Step 2 : Received advertisement packet
        
        let deviceName = peripheral.name;

        //The name can occasionally be nil for some strange reason. Probable iOS bug
        if(deviceName != nil){
            let localName : String? = advertisementData[CBAdvertisementDataLocalNameKey] as? String
            
            if(localName != nil
                && foundDevices.objectForKey(peripheral.identifier) == nil){
                
                NSLog("%@: discovered %@, localname %@, rssi:%d", TAG, peripheral.description, localName!, RSSI.integerValue)
                
                
                foundDevices.setObject(peripheral, forKey: peripheral.identifier)
                delegate.newDeviceScanned(deviceName!, localName : localName!, uuid: peripheral.identifier, rssi: RSSI.integerValue, advertisementData: advertisementData)
            }
        }

    }
    
    //Public facing connect method
    
    
    func connectToDevice(uuid : NSUUID!) -> Bool{
        
        //Step 2.5: Connect to device
        
        let device : CBPeripheral? = foundDevices.objectForKey(uuid) as? CBPeripheral
        
        if(device == nil){
            return false
        } else {
            //Good practice to stop scan before start connecting
            bleScan(false)
            centralManager.connectPeripheral(device!, options: nil)
            return true
        }
        
        
    }
    
    
    //CBCentralDelegate
    
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        NSLog("%@: connected to %@", TAG, peripheral.name!)
        
        //Step 3: Connect success
        
        currentConnectedDevice = peripheral
        
        //Discover all services
        peripheral.delegate = self
        peripheral.discoverServices(nil)
        
        delegate.connectionState(peripheral.name!, state: true)
        
        
    }
    
    func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        NSLog("%@: failed to connect to %@", TAG, peripheral.name!)
        
        delegate.connectionState(peripheral.name!, state: false)
    }
    
    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        NSLog("%@: disconnected from %@", TAG, peripheral.name!)
        currentConnectedDevice = nil
        current_char_led = nil
        current_char_button = nil
        
        delegate.connectionState(peripheral.name!, state: false)
    }
    
    
    
    //Reference http://www.raywenderlich.com/52080/introduction-core-bluetooth-building-heart-rate-monitor
    func centralManagerDidUpdateState(central: CBCentralManager) {
        // Determine the state of the Central
        
        if (central.state == CBCentralManagerState.PoweredOff) {
            NSLog("%@ CoreBluetooth BLE hardware is powered off", TAG);
        }
        else if (central.state == CBCentralManagerState.PoweredOn) {
            NSLog("%@ CoreBluetooth BLE hardware is powered on and ready", TAG);
        }
        else if (central.state == CBCentralManagerState.Unauthorized) {
            NSLog("%@ CoreBluetooth BLE state is unauthorized", TAG);
        }
        else if (central.state == CBCentralManagerState.Unknown) {
            NSLog("%@ CoreBluetooth BLE state is unknown", TAG);
        }
        else if (central.state == CBCentralManagerState.Unsupported) {
            NSLog("%@ CoreBluetooth BLE hardware is unsupported on this platform", TAG);
        }
    }
    
    
    //CBPeripheralDelegate
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        NSLog("%@: Services Discovered for %@", TAG, peripheral.name!)
        
        //Step 4: Services discovered
        
        let services : [CBService]? = peripheral.services
        
        
        if(services != nil){
            for cbService in services! {
                if(cbService.UUID == UUID_SERVICE){
                    
                    peripheral.discoverCharacteristics(nil, forService: cbService)
                    break
                }
            }
        }
        
        
        delegate.servicesDiscovered(peripheral.name!)
        
  
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        NSLog("%@: Characteristics discovered for %@, of service %@", TAG, peripheral.name!, service.UUID.UUIDString)
        
        //Step 5: Characteristics discovered. We can usually stop here as we don't normally need to discover descriptors.
      
        let characteristics : [CBCharacteristic]? = service.characteristics
        
        if(characteristics != nil){
            for cbCharacteristic in characteristics! {
                
                if(cbCharacteristic.UUID == UUID_CHAR_LED){
                    current_char_led = cbCharacteristic
                } else if (cbCharacteristic.UUID == UUID_CHAR_BUTTON){
                    current_char_button = cbCharacteristic
                    
                    
                    //Apply to be notified so we can listen to changes in button characteristic
                    peripheral.setNotifyValue(true, forCharacteristic: current_char_button!)
                    
                }
                
                
                
            }
        }
        


        delegate.characteristicsDiscoveredFor(peripheral.name!)
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {

        
        if(characteristic.UUID == UUID_CHAR_BUTTON){
            let charValue : NSData? = characteristic.value
            
            if(charValue != nil){
                var dataStr : String? = NSString(data: charValue!, encoding: NSASCIIStringEncoding) as? String
                
                if(dataStr == nil){
                    dataStr = "blank"
                }
                
                NSLog("%@: Characteristic changed for %@ with value %@", TAG, peripheral.name!, dataStr!)
                
                delegate.receivedStringValue(peripheral.name!, dataStr: dataStr!)
            }
            

        }
 
    }
    
    
    //Public facing toggle LED methods
    
    func sendToggleBlueCommand(){
        writeThisToLEDCharacteristic("b")
    }
    
    func sendToggleYellowCommand(){
        writeThisToLEDCharacteristic("y")
    }
    
    
    func writeThisToLEDCharacteristic(stringToWrite : NSString){
        if(currentConnectedDevice != nil && current_char_led != nil){
            
            let data : NSData = stringToWrite.dataUsingEncoding(NSASCIIStringEncoding)!
            
            
            currentConnectedDevice?.writeValue(data, forCharacteristic: current_char_led!, type: CBCharacteristicWriteType.WithoutResponse)
            
        }
    }
    
    
    
}