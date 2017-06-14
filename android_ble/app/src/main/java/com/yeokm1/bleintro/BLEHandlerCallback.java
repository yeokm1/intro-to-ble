package com.yeokm1.bleintro;

/**
 * Created by yeokm1 on 29/3/2015.
 */
public interface BLEHandlerCallback {
    //Step 2 : Received advertisement packet
    void newDeviceScanned(String localName, String macAddress, int rssi, byte[] scanRecord);

    //Step 3: Connect success
    void connectionState(String localName, String macAddress, boolean state);

    //Step 4 and 5: Services discovered
    void servicesDiscoveredState(String localName, String macAddress, boolean state);

    void receivedStringValue(String localName, String macAddress, String strValue);
}
