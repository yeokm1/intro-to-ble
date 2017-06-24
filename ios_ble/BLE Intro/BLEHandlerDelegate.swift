//
//  BLEHandlerDelegate.swift
//  BLE Intro
//
//  Created by Yeo Kheng Meng on 3/4/15.
//  Copyright (c) 2015 Yeo Kheng Meng. All rights reserved.
//

import Foundation
import CoreBluetooth


protocol BLEHandlerDelegate {

    //Step 2 : Received advertisement packet
    func newDeviceScanned(deviceName : String, localName : String, uuid: UUID, rssi : Int, advertisementData : [NSObject : AnyObject]!)

    //Step 3: Connect success
    func connectionState(deviceName : String, state : Bool)

    //Step 4: Services discovered
    func servicesDiscovered(deviceName : String)

    //Step 5: Discovery completed
    func characteristicsDiscoveredFor(deviceName : String)

    func receivedStringValue(deviceName: String, dataStr : String)

}
