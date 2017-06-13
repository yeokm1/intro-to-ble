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
    var capturedUUIDs : Array<UUID>!

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


    @IBAction func startScanPressed(_ sender: UIButton) {

        //Clear results of previous scan
        cellTitles.removeAll()
        cellLabels.removeAll()
        capturedUUIDs.removeAll()

        self.bleScannedList.reloadData()

        self.statusLabel.text = "Scanning for BLE peripherals..."

        bleHandler.bleScan(start: true)
    }

    @IBAction func stopScanPressed(_ sender: UIButton) {

        self.statusLabel.text = "Scan stopped"

        bleHandler.bleScan(start: false)
    }

    @IBAction func disconnectPressed(_ sender: UIButton) {
        bleHandler.disconnectCurrentlyConnectedDevice()
    }

    @IBAction func toggleBlue(_ sender: UIButton) {
        bleHandler.sendToggleBlueCommand()
    }

    @IBAction func toggleYellow(_ sender: UIButton) {
        bleHandler.sendToggleYellowCommand()
    }

    func setStatusTextFromNonUIThread(text : String){

        DispatchQueue.main.async {
           self.statusLabel.text = text
        }

    }


    //UITableViewDataSource


    //The table will display what is set here
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cellID = "bleListCell"

        var cell : UITableViewCell? = tableView.dequeueReusableCell(withIdentifier: cellID)


        if (cell == nil){
            cell = UITableViewCell(style: UITableViewCellStyle.subtitle, reuseIdentifier: cellID)
        }

        //Device/Local name in the title
        cell!.textLabel?.text = cellTitles[indexPath.row]

        //UUID in the subtitle
        cell!.detailTextLabel?.text = cellLabels[indexPath.row]

        return cell!

    }




    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cellTitles.count
    }

    //UITableViewDelegate

    //This will get called if a row is clicked
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let uuidToConnect : UUID = capturedUUIDs[indexPath.row]
        let _ = bleHandler.connectToDevice(uuid: uuidToConnect)

    }

    //BLEHandlerDelegate
    func newDeviceScanned(deviceName : String, localName: String, uuid : UUID, rssi: Int, advertisementData: [NSObject : AnyObject]!) {

        //We just detected a new device

        cellTitles.append(deviceName + " (" + localName + ")")
        cellLabels.append(uuid.uuidString + " (" + String(rssi) + ")")
        capturedUUIDs.append(uuid)

        //Tell the list to update to display the newly found device
        DispatchQueue.main.async {
            self.bleScannedList.reloadData()
        }

    }

    func connectionState(deviceName : String, state : Bool){

        var statusString : String!

        if(state){
            statusString = "Connected to: " + deviceName
        } else {
            statusString = "Disconnected from: " + deviceName
        }

        setStatusTextFromNonUIThread(text: statusString)
    }


    func servicesDiscovered(deviceName : String){
        setStatusTextFromNonUIThread(text: "Services discovered for: " + deviceName)
    }

    func characteristicsDiscoveredFor(deviceName : String){
        setStatusTextFromNonUIThread(text: "Chars discovered for: " + deviceName)
    }



    func receivedStringValue(deviceName: String, dataStr: String) {
        setStatusTextFromNonUIThread(text: "Received \"" + dataStr + "\" from " + deviceName)
    }

}
