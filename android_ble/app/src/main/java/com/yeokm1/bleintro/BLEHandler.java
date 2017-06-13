package com.yeokm1.bleintro;

import android.annotation.TargetApi;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCallback;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattDescriptor;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothManager;
import android.bluetooth.BluetoothProfile;
import android.bluetooth.le.BluetoothLeScanner;
import android.bluetooth.le.ScanCallback;
import android.bluetooth.le.ScanFilter;
import android.bluetooth.le.ScanRecord;
import android.bluetooth.le.ScanResult;
import android.bluetooth.le.ScanSettings;
import android.content.Context;
import android.os.Build;
import android.os.Handler;
import android.util.Log;

import java.nio.charset.Charset;
import java.util.HashMap;
import java.util.List;
import java.util.UUID;

/**
 * Created by yeokm1 on 29/3/2015.
 */
public class BLEHandler {
    private static final String TAG = "BLEHandler";

    private static final UUID UUID_SERVICE =     UUID.fromString("12345678-9012-3456-7890-123456789012");
    private static final UUID UUID_CHAR_LED =    UUID.fromString("00000000-0000-0000-0000-000000000010");
    private static final UUID UUID_CHAR_BUTTON = UUID.fromString("00000000-0000-0000-0000-000000000020");

    //This UUID is a Client Characteristic Configuration descriptor UUID for a Characteristic which has the notify property on the peripheral
    //I should not be hard coding this but I cannot find a constant defined anywhere.
    private static UUID UUID_CLIENT_CHARACTERISTIC_CONFIG_DESCRIPTOR = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb");

    private Context context;

    private BluetoothAdapter mBluetoothAdapter;

    //Android 4.3 - 4.4 uses this
    private OldLeScanCallback oldLeScanCallback;

    //Android 5.0 and above uses this
    private BluetoothLeScanner bleScanner;
    private NewLeScanCallback newLeScanCallback;

    //We will receive advertisement packets continuously, so we use this HashMap to keep track of what has been found so far.
    private HashMap<String, BluetoothDevice> foundDevices = new HashMap<String, BluetoothDevice>();

    private BluetoothGatt gattOfCurrentDevice;

    private BLEHandlerCallback bleHandlerCallback;
    public BLEHandler(Context context, BLEHandlerCallback bleHandlerCallback){

        this.context = context;
        this.bleHandlerCallback = bleHandlerCallback;

        BluetoothManager bluetoothManager =  (BluetoothManager) context.getSystemService(Context.BLUETOOTH_SERVICE);
        mBluetoothAdapter = bluetoothManager.getAdapter();
    }

    public void bleScan(boolean start){
        if(start){
            //Step 1: Start scanning
            foundDevices.clear();

            if(Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP){
                bleScanner = mBluetoothAdapter.getBluetoothLeScanner();
                newLeScanCallback = new NewLeScanCallback();


                //The default is ScanSettings.SCAN_MODE_LOW_POWER which seems too slow for me
                //I put the report delay to 0 as I want instant feedback.
                ScanSettings settings = new ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_BALANCED).setReportDelay(0).build();

                //This is usually null as I don't wish to filter but you may want to
                List<ScanFilter> filter = null;

                // You can also do "bleScanner.startScan(newLeScanCallback);"
                bleScanner.startScan(filter, settings, newLeScanCallback);
            } else {

                oldLeScanCallback = new OldLeScanCallback();

               /*
                * Samsung phones have a bug when it comes to filtering for UUIDs.
                * Nothing will be returned if you use this function for them
                UUID[] serviceUUIDs = new UUID[1];
                mBluetoothAdapter.startLeScan(serviceUUIDs, oldLeScanCallback);
               */

                mBluetoothAdapter.startLeScan(oldLeScanCallback);
            }
        } else {
            if(Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                if(bleScanner != null){
                    bleScanner.stopScan(newLeScanCallback);
                    bleScanner = null;
                    newLeScanCallback = null;
                }
            } else {
                if(oldLeScanCallback != null) {
                    mBluetoothAdapter.stopLeScan(oldLeScanCallback);
                    oldLeScanCallback = null;
                }
            }
        }
    }

    private void newDeviceScanned(final BluetoothDevice device, int rssi, byte[] scanRecord){
        //Step 2 : Received advertisement packet

        String macAddress = device.getAddress();
        String localName = device.getName();

        if(localName == null){
            return;
        }

        String logMessage = String.format("Scanning: %s (%s), rssi: %d", localName, macAddress, rssi);
        //Log.i(TAG, logMessage);

        if(!foundDevices.containsKey(macAddress)){
            Log.i(TAG, logMessage);

            foundDevices.put(macAddress, device);

            bleHandlerCallback.newDeviceScanned(localName, macAddress, rssi, scanRecord);
        }
    }

    //This is used from Android 4.3 to 4.4
    private class OldLeScanCallback implements BluetoothAdapter.LeScanCallback{
        @Override
        public void onLeScan(BluetoothDevice device, int rssi,  byte[] scanRecord) {
            newDeviceScanned(device, rssi, scanRecord);
        }
    }

    //This is used from Android 5.0
    @TargetApi(Build.VERSION_CODES.LOLLIPOP)
    private class NewLeScanCallback extends ScanCallback {
        @Override
        public void onScanResult(int callbackType, ScanResult result) {

            BluetoothDevice device = result.getDevice();
            int rssi = result.getRssi();
            ScanRecord scanRecord = result.getScanRecord();
            byte[] record = scanRecord.getBytes();

            newDeviceScanned(device, rssi, record);

        }
    }

    public void connectToDevice(String macAddress){

        //Step 2.5: Connect to device

        final BluetoothDevice deviceToConnect = foundDevices.get(macAddress);

        /* Samsung phones require this to be called from the UI thread.
         *
         * Second param refers to autoconnect(keep connecting in background)
         * Initial connection after scan must be set to FALSE
         *
         * For subsequent connections, it is still preferred to set to false
         * to prevent unintended background connection.
         */

        if(Build.MANUFACTURER.equalsIgnoreCase("samsung")){
            new Handler().post(new Runnable() {
                @Override
                public void run() {
                    //Call connect API in UI thread for Samsung phones only
                    //This will also work non-Samsung phones
                    deviceToConnect.connectGatt(context, false, mGattCallback);
                }
            });
        } else {
            deviceToConnect.connectGatt(context, false, mGattCallback);
        }
    }

    public void disconnectCurrentlyConnectedDevice(){
       if(gattOfCurrentDevice != null){
           gattOfCurrentDevice.close();
           gattOfCurrentDevice.disconnect();
           gattOfCurrentDevice = null;
       }
    }

    private void logDeviceMessage(String frontMessage, BluetoothDevice device){
        String localName = device.getName();
        String macAddress = device.getAddress();

        String logMessage = String.format("%s: %s (%s)", frontMessage, localName, macAddress);
        Log.i(TAG, logMessage);
    }

    private BluetoothGattService getCustomService(){
        if(gattOfCurrentDevice == null){
            return null;
        }

        BluetoothGattService service = gattOfCurrentDevice.getService(UUID_SERVICE);
        return service;
    }

    //To receive callbacks from a bluetooth device
    private BluetoothGattCallback mGattCallback =  new BluetoothGattCallback() {
        @Override
        public void onConnectionStateChange(BluetoothGatt gatt, int status, int newState) {

            BluetoothDevice device = gatt.getDevice();
            String localName = device.getName();
            String macAddress = device.getAddress();

            if (newState == BluetoothProfile.STATE_CONNECTED) {
                //Step 3: Connect success

                logDeviceMessage("Connected to", gatt.getDevice());
                bleHandlerCallback.connectionState(localName, macAddress, true);

                gattOfCurrentDevice = gatt;
                gatt.discoverServices();
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                logDeviceMessage("Disconnected from", gatt.getDevice());

                if(gattOfCurrentDevice != null && gatt.getDevice().getAddress().equals(gatt.getDevice().getAddress())){
                    gattOfCurrentDevice = null;
                }

                bleHandlerCallback.connectionState(localName, macAddress, false);
            }
        }

        @Override
        public void onServicesDiscovered(BluetoothGatt gatt, int status) {
            BluetoothDevice device = gatt.getDevice();
            String localName = device.getName();
            String macAddress = device.getAddress();

            if (status == BluetoothGatt.GATT_SUCCESS) {
                //Step 4 and 5: Services discovered.
                //Characteristics and descriptors are automatically discovered with services in Android so we can stop here.

                logDeviceMessage("Services discovered for",  gatt.getDevice());

                //Find the relevant service by UUID
                BluetoothGattService customService = getCustomService();
                BluetoothGattCharacteristic buttonChar = customService.getCharacteristic(UUID_CHAR_BUTTON);

                //Apply to be notified so we can listen to changes in button characteristic
                gatt.setCharacteristicNotification(buttonChar, true);

                //Extra step for Android, write enable to CCCD
                BluetoothGattDescriptor descriptor = buttonChar.getDescriptor(UUID_CLIENT_CHARACTERISTIC_CONFIG_DESCRIPTOR);
                descriptor.setValue(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE);
                gatt.writeDescriptor(descriptor);


                bleHandlerCallback.servicesDiscoveredState(localName, macAddress, true);
            } else {
                logDeviceMessage("Services status " + status + " for",  gatt.getDevice());
                bleHandlerCallback.servicesDiscoveredState(localName, macAddress, false);
            }
        }

        @Override
        public void onCharacteristicChanged (BluetoothGatt gatt, BluetoothGattCharacteristic characteristic){
            if(characteristic.getUuid().equals(UUID_CHAR_BUTTON)) {
                BluetoothDevice device = gatt.getDevice();
                String localName = device.getName();
                String macAddress = device.getAddress();

                byte[] newValue = characteristic.getValue();
                String valueStr = new String(newValue, Charset.forName("US-ASCII"));

                bleHandlerCallback.receivedStringValue(localName, macAddress, valueStr);
            }
        }
    };

    //Public facing toggle LED methods

    public void sendToggleBlueCommand(){
        writeThisToLedCharacteristic("b");
    }

    public void sendToggleYellowCommand(){
        writeThisToLedCharacteristic("y");
    }

    public void writeThisToLedCharacteristic(String stringToWrite){
        BluetoothGattService service = getCustomService();

        if(service == null){
            return;
        }

        byte[] dataToWrite = stringToWrite.getBytes(Charset.forName("US-ASCII"));

        BluetoothGattCharacteristic ledChar = service.getCharacteristic(UUID_CHAR_LED);
        ledChar.setValue(dataToWrite);

        //Android BLE stack does not allow multiple characteristic writes in quick succession
        //You have to wait for the previous characteristic to finish first

        gattOfCurrentDevice.writeCharacteristic(ledChar);
    }
}
