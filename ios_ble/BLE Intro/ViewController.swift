//
//  ViewController.swift
//  BLE Intro
//
//  Created by Yeo Kheng Meng on 1/4/15.
//  Copyright (c) 2015 Yeo Kheng Meng. All rights reserved.
//

import UIKit


class ViewController: UIViewController, BLEHandlerDelegate, UITableViewDelegate, UITableViewDataSource{
    
    var bleHandler : BLEHandler!
    
    @IBOutlet weak var statusLabel: UILabel!
    
    var cellTitles : Array<String>!
    var cellLabels : Array<String>!
    var capturedUUIDs : Array<NSUUID>!

    @IBOutlet weak var bleScannedList: UITableView!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        //Initialise the backing arrays for the UI components
        cellTitles = Array()
        cellLabels = Array()
        capturedUUIDs = Array()
        
        
        //Set table to retrieve data from this view controller (UI)
        bleScannedList.delegate = self
        bleScannedList.dataSource = self
    
        
        //Start BLEHandler and ask it to pass callbacks to UI (here)
        bleHandler = BLEHandler(delegate: self)
    

    }


    @IBAction func startScanPressed(sender: UIButton) {
        
        //Clear results of previous scan
        cellTitles.removeAll()
        cellLabels.removeAll()
        capturedUUIDs.removeAll()
        
        self.bleScannedList.reloadData()

        self.statusLabel.text = "Scanning for BLE peripherals..."
        
        bleHandler.bleScan(true)
    }
    @IBAction func stopScanPressed(sender: UIButton) {
        
        self.statusLabel.text = "Scan stopped"
        
        bleHandler.bleScan(false)
    }
    
    @IBAction func disconnectPressed(sender: UIButton) {
        bleHandler.disconnectCurrentlyConnectedDevice()
    }

    @IBAction func toggleBlue(sender: UIButton) {
        bleHandler.sendToggleBlueCommand()
    }
    
    @IBAction func toggleYellow(sender: UIButton) {
        bleHandler.sendToggleYellowCommand()
    }
    
    func setStatusTextFromNonUIThread(text : String){
        
        //Run in UI thread as sometimes this method may be called from other threads
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            self.statusLabel.text = text
        })
    }
    
 
    //UITableViewDataSource
    
    
    //The table will display what is set here
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
  
        let cellID = "bleListCell"
        
        var cell : UITableViewCell? = tableView.dequeueReusableCellWithIdentifier(cellID) as? UITableViewCell
        
        if (cell == nil){
            cell = UITableViewCell(style: UITableViewCellStyle.Subtitle, reuseIdentifier: cellID)
        }
        
        //Device/Local name in the title
        cell!.textLabel?.text = cellTitles[indexPath.row]
        
        //UUID in the subtitle
        cell!.detailTextLabel?.text = cellLabels[indexPath.row]
        
        return cell!
        
    }
    

 
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cellTitles.count
    }

    //UITableViewDelegate
    
    //This will get called if a row is clicked
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        var uuidToConnect : NSUUID = capturedUUIDs[indexPath.row]
        bleHandler.connectToDevice(uuidToConnect)
        
    }
    
    //BLEHandlerDelegate
    func newDeviceScanned(deviceName : String, localName: String, uuid : NSUUID, rssi: Int, advertisementData: [NSObject : AnyObject]!) {
       
        //We just detected a new device
        
        cellTitles.append(deviceName + " (" + localName + ")")
        cellLabels.append(uuid.UUIDString + " (" + String(rssi) + ")")
        capturedUUIDs.append(uuid)
        
            
        //Tell the list to update to display the newly found device
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            self.bleScannedList.reloadData()
        })
        
    }
    
    func connectionState(deviceName : String, state : Bool){
        
        var statusString : String!
        
        if(state){
            statusString = "Connected to: " + deviceName
        } else {
            statusString = "Disconnected from: " + deviceName
        }
        
        setStatusTextFromNonUIThread(statusString)
    }
    

    func servicesDiscovered(deviceName : String){
        setStatusTextFromNonUIThread("Services discovered for: " + deviceName)
    }
    
    func characteristicsDiscoveredFor(deviceName : String){
        setStatusTextFromNonUIThread("Chars discovered for: " + deviceName)
    }
    
    

    func receivedStringValue(deviceName: String, dataStr: String) {
        setStatusTextFromNonUIThread("Received \"" + dataStr + "\" from " + deviceName)
    }
    
}

