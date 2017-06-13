package com.yeokm1.bleintro;

import android.Manifest;
import android.app.Activity;
import android.bluetooth.BluetoothAdapter;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Bundle;
import android.view.View;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.ListView;
import android.widget.TextView;
import android.widget.Toast;

import java.util.ArrayList;

public class MainActivity extends Activity implements BLEHandlerCallback{
    public static final String TAG = "MainActivity";

    private static final int REQUEST_CODE_ASK_PERMISSIONS = 123;

    private TextView statusView;
    private ListView bleScannedList;

    private ArrayAdapter devicesListAdapter;
    private ArrayList<String> devicesMacAddr;

    private BLEHandler bleHandler;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        bleHandler = new BLEHandler(getApplicationContext(), this);

        BluetoothAdapter mBluetoothAdapter = BluetoothAdapter.getDefaultAdapter();
        if (mBluetoothAdapter == null) {
            Toast.makeText(this, "Your device does not have Bluetooth", Toast.LENGTH_SHORT).show();
            finish();
            return;
        }

        //Check if at least Android 4.3
        if(Build.VERSION.SDK_INT < Build.VERSION_CODES.JELLY_BEAN_MR2){
            Toast.makeText(this, "You need Android 4.3 and above to use BLE.", Toast.LENGTH_SHORT).show();
            finish();
            return;
        }

        //It's rare for devices that ship with Android 4.3 and above to not have BLE hardware
        // but we still follow Google's recommendation and check anyway
        if (!getPackageManager().hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE)) {
            Toast.makeText(this, "BLE hardware not found", Toast.LENGTH_SHORT).show();
            finish();
            return;
        }

        //New in Android 6.0 Marshmallow, we now have runtime permissions.
        //BLE Scan requires location permissions and we have to ask the user to approve on runtime
        if(Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            int hasLocationsPermission = checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION);

            if (hasLocationsPermission != PackageManager.PERMISSION_GRANTED) {
                requestPermissions(new String[] {Manifest.permission.ACCESS_COARSE_LOCATION}, REQUEST_CODE_ASK_PERMISSIONS);
            }
        }

        statusView = (TextView)findViewById(R.id.textview_status);

        devicesMacAddr = new ArrayList<String>();
        devicesListAdapter = new ArrayAdapter(this, android.R.layout.simple_list_item_1, new ArrayList<String>());
        bleScannedList = (ListView) findViewById(R.id.listview_scanned);
        bleScannedList.setAdapter(devicesListAdapter);
        bleScannedList.setOnItemClickListener(new AdapterView.OnItemClickListener() {
            @Override
            public void onItemClick(AdapterView<?> parent, View view, int position, long id) {
                //Stop scan before attempting to connect
                bleHandler.bleScan(false);

                String macAddressOfDeviceToConnect = devicesMacAddr.get(position);
                bleHandler.connectToDevice(macAddressOfDeviceToConnect);
            }
        });
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        switch (requestCode) {
            case REQUEST_CODE_ASK_PERMISSIONS:
                if (grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    Toast.makeText(MainActivity.this, "Location Permission granted, you can now scan for Bluetooth devices", Toast.LENGTH_LONG).show();
                } else {
                    // Permission Denied
                    Toast.makeText(MainActivity.this, "Location Permission denied, so Bluetooth will not work. Closing app...", Toast.LENGTH_LONG).show();
                    finish();
                }
                break;
            default:
                super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        }
    }

    public void startScanButtonPressed(View view){
        if (!BluetoothAdapter.getDefaultAdapter().isEnabled()) {
            Intent enableBtIntent = new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE);
            startActivity(enableBtIntent);
            return;
        }

        showStatusToScreen("Scanning for BLE peripherals...");
        devicesMacAddr.clear();
        devicesListAdapter.clear();
        devicesListAdapter.notifyDataSetChanged();
        bleHandler.bleScan(true);
    }

    public void stopScanButtonPressed(View view){
        showStatusToScreen("Scan stopped");
        bleHandler.bleScan(false);
    }

    public void disconnectButtonPressed(View view){
        bleHandler.disconnectCurrentlyConnectedDevice();
    }

    public void toggleBlueButtonPressed(View view){
        bleHandler.sendToggleBlueCommand();
    }

    public void toggleYellowButtonPressed(View view){
        bleHandler.sendToggleYellowCommand();
    }

    public void showDeviceStatusToScreen(String frontMessage, String localName, String macAddress){
        String message = String.format("%s: %s (%s)", frontMessage, macAddress, localName);
        showStatusToScreen(message);
    }

    public void showStatusToScreen(final String message){
        //Run in UI thread as sometimes this method may be called from other threads
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                statusView.setText(message);
            }
        });
    }

    //BLEHandler callbacks

    @Override
    public void newDeviceScanned(final String localName, final String macAddress, final int rssi, byte[] scanRecord) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                String displayMessage = String.format("%s (%s), rssi: %d", macAddress, localName, rssi);

                devicesMacAddr.add(macAddress);
                devicesListAdapter.add(displayMessage);
                devicesListAdapter.notifyDataSetChanged();
            }
        });
    }

    @Override
    public void connectionState(String localName, String macAddress, boolean state){
        if(state){
            showDeviceStatusToScreen("Connected to", localName, macAddress);
        } else {
            showDeviceStatusToScreen("Disconnected from", localName, macAddress);
        }
    }

    @Override
    public void servicesDiscoveredState(String localName, String macAddress, boolean state){
        if(state){
            showDeviceStatusToScreen("Services discovered for", localName, macAddress);
        } else {
            showDeviceStatusToScreen("Service Discovery failed for", localName, macAddress);
        }
    }

    @Override
    public void receivedStringValue(String localName, String macAddress, final String strValue){
        showDeviceStatusToScreen("Received \"" + strValue + "\" from ", localName, macAddress);
    }
}
