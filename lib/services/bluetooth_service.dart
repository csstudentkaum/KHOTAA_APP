import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// =============================================================================
/// BLUETOOTH SERVICE FOR SMART INSOLE CONNECTION
/// =============================================================================
/// This service handles all Bluetooth Low Energy (BLE) operations for connecting
/// to the smart insole device. It includes:
/// - Bluetooth state monitoring (on/off)
/// - Device scanning and filtering
/// - Connection management
/// - Auto-reconnection logic
/// - Permission handling
/// =============================================================================

/// Represents a discovered BLE insole device
class InsoleDevice {
  final String id;            // Unique device identifier (MAC address or UUID)
  final String name;          // Device display name
  final BluetoothDevice? bleDevice; // Reference to the actual BLE device
  final int rssi;             // Signal strength

  InsoleDevice({
    required this.id,
    required this.name,
    this.bleDevice,
    this.rssi = 0,
  });
}

/// Connection states for the insole device
enum InsoleConnectionState {
  disconnected,    // Not connected to any device
  scanning,        // Actively scanning for devices
  connecting,      // Connection in progress
  connected,       // Successfully connected
  failed,          // Connection failed
  bluetoothOff,    // Bluetooth is disabled
  permissionDenied // Bluetooth permissions not granted
}

/// =============================================================================
/// BLUETOOTH SERVICE CLASS
/// =============================================================================
/// Singleton service that manages all Bluetooth operations.
/// Uses ChangeNotifier for reactive UI updates.
/// =============================================================================
class BluetoothService extends ChangeNotifier {
  // Singleton pattern for global access
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  // =========================================================================
  // PRIVATE STATE VARIABLES
  // =========================================================================
  
  /// Current connection state
  InsoleConnectionState _connectionState = InsoleConnectionState.disconnected;
  
  /// List of discovered insole devices during scanning
  final List<InsoleDevice> _discoveredDevices = [];
  
  /// Currently connected device (null if not connected)
  InsoleDevice? _connectedDevice;
  
  /// User-friendly status message for display
  String _statusMessage = 'Ready to connect';
  
  /// Error message for display (empty if no error)
  String _errorMessage = '';
  
  /// Subscription for Bluetooth state changes
  StreamSubscription<BluetoothAdapterState>? _bluetoothStateSubscription;
  
  /// Subscription for device scan results
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  
  /// Subscription for device connection state
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  
  /// Timer for scan timeout
  Timer? _scanTimeoutTimer;
  
  /// Timer for connection timeout
  Timer? _connectionTimeoutTimer;
  
  /// Key for storing last connected device ID
  static const String _lastConnectedDeviceKey = 'last_connected_insole_id';
  
  /// Key for storing last connected device name
  static const String _lastConnectedDeviceNameKey = 'last_connected_insole_name';
  
  /// Filter pattern for insole devices (devices must contain this in name)
  /// In production, this would match your specific insole device name
  static const List<String> _deviceNameFilters = ['Insole', 'INSOLE', 'Khotaa', 'KHOTAA'];
  
  /// Scan timeout duration (how long to search for devices)
  static const Duration _scanTimeout = Duration(seconds: 15);
  
  /// Connection timeout duration
  static const Duration _connectionTimeout = Duration(seconds: 10);

  // =========================================================================
  // PUBLIC GETTERS
  // =========================================================================
  
  InsoleConnectionState get connectionState => _connectionState;
  List<InsoleDevice> get discoveredDevices => List.unmodifiable(_discoveredDevices);
  InsoleDevice? get connectedDevice => _connectedDevice;
  String get statusMessage => _statusMessage;
  String get errorMessage => _errorMessage;
  bool get isScanning => _connectionState == InsoleConnectionState.scanning;
  bool get isConnected => _connectionState == InsoleConnectionState.connected;
  bool get isConnecting => _connectionState == InsoleConnectionState.connecting;
  bool get hasError => _connectionState == InsoleConnectionState.failed || _errorMessage.isNotEmpty;

  // =========================================================================
  // INITIALIZATION
  // =========================================================================
  
  /// Initialize the Bluetooth service
  /// Should be called when the app starts or when the connect screen is opened
  Future<void> initialize() async {
    // Start listening to Bluetooth adapter state changes
    _bluetoothStateSubscription?.cancel();
    _bluetoothStateSubscription = FlutterBluePlus.adapterState.listen(
      _onBluetoothStateChanged,
    );
    
    // Check current Bluetooth state
    await _checkBluetoothState();
    
    // Try to auto-reconnect to last device
    await _tryAutoReconnect();
  }

  /// Dispose of all subscriptions and timers
  void dispose() {
    _bluetoothStateSubscription?.cancel();
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _scanTimeoutTimer?.cancel();
    _connectionTimeoutTimer?.cancel();
    super.dispose();
  }

  // =========================================================================
  // BLUETOOTH STATE HANDLING
  // =========================================================================
  
  /// Handle Bluetooth adapter state changes
  /// Called when user enables/disables Bluetooth
  void _onBluetoothStateChanged(BluetoothAdapterState state) {
    if (state == BluetoothAdapterState.off) {
      // Bluetooth was turned off
      _updateState(
        InsoleConnectionState.bluetoothOff,
        message: 'Bluetooth is turned off',
      );
      _stopScanning();
      _disconnectDevice();
    } else if (state == BluetoothAdapterState.on) {
      // Bluetooth was turned on - ready to scan
      if (_connectionState == InsoleConnectionState.bluetoothOff) {
        _updateState(
          InsoleConnectionState.disconnected,
          message: 'Ready to connect',
        );
      }
    }
    notifyListeners();
  }

  /// Check current Bluetooth state
  Future<bool> _checkBluetoothState() async {
    try {
      final state = await FlutterBluePlus.adapterState.first;
      if (state == BluetoothAdapterState.off) {
        _updateState(
          InsoleConnectionState.bluetoothOff,
          message: 'Please turn on Bluetooth',
        );
        return false;
      }
      return true;
    } catch (e) {
      _updateState(
        InsoleConnectionState.failed,
        error: 'Could not check Bluetooth status',
      );
      return false;
    }
  }

  /// Check if Bluetooth is currently enabled
  Future<bool> isBluetoothEnabled() async {
    try {
      final state = await FlutterBluePlus.adapterState.first;
      return state == BluetoothAdapterState.on;
    } catch (e) {
      return false;
    }
  }

  // =========================================================================
  // PERMISSION HANDLING
  // =========================================================================
  
  /// Request all necessary Bluetooth permissions
  /// Returns true if all permissions are granted
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      // Android requires multiple permissions for BLE
      // BLUETOOTH_SCAN: Required to discover nearby devices
      // BLUETOOTH_CONNECT: Required to connect to devices
      // LOCATION: Required on older Android versions for BLE scanning
      
      final bluetoothScan = await Permission.bluetoothScan.request();
      final bluetoothConnect = await Permission.bluetoothConnect.request();
      final location = await Permission.location.request();
      
      final allGranted = bluetoothScan.isGranted && 
                         bluetoothConnect.isGranted && 
                         location.isGranted;
      
      if (!allGranted) {
        _updateState(
          InsoleConnectionState.permissionDenied,
          error: 'Please allow Bluetooth permissions in settings',
        );
        return false;
      }
      return true;
    } else if (Platform.isIOS) {
      // iOS only needs Bluetooth permission
      final bluetooth = await Permission.bluetooth.request();
      
      if (!bluetooth.isGranted) {
        _updateState(
          InsoleConnectionState.permissionDenied,
          error: 'Please allow Bluetooth in settings',
        );
        return false;
      }
      return true;
    }
    return true;
  }

  /// Check if permissions are currently granted
  Future<bool> hasPermissions() async {
    if (Platform.isAndroid) {
      return await Permission.bluetoothScan.isGranted &&
             await Permission.bluetoothConnect.isGranted &&
             await Permission.location.isGranted;
    } else if (Platform.isIOS) {
      return await Permission.bluetooth.isGranted;
    }
    return true;
  }

  // =========================================================================
  // DEVICE SCANNING
  // =========================================================================
  
  /// Start scanning for nearby insole devices
  /// This is the main entry point for the user to start the connection process
  Future<void> startScanning() async {
    // Step 1: Check permissions
    final hasPerms = await requestPermissions();
    if (!hasPerms) return;
    
    // Step 2: Check Bluetooth state
    final isBluetoothOn = await _checkBluetoothState();
    if (!isBluetoothOn) return;
    
    // Step 3: Stop any existing scan
    await _stopScanning();
    
    // Step 4: Clear previous results and update state
    _discoveredDevices.clear();
    _errorMessage = '';
    _updateState(
      InsoleConnectionState.scanning,
      message: 'Searching for your insole...',
    );
    
    // Step 5: Start the BLE scan
    try {
      // Listen to scan results
      _scanSubscription = FlutterBluePlus.scanResults.listen(
        _onScanResults,
        onError: (error) {
          _updateState(
            InsoleConnectionState.failed,
            error: 'Could not search for devices',
          );
        },
      );
      
      // Start scanning with timeout
      await FlutterBluePlus.startScan(
        timeout: _scanTimeout,
        androidUsesFineLocation: true,
      );
      
      // Set up timeout handler
      _scanTimeoutTimer?.cancel();
      _scanTimeoutTimer = Timer(_scanTimeout, _onScanTimeout);
      
    } catch (e) {
      _updateState(
        InsoleConnectionState.failed,
        error: 'Could not start searching. Please try again.',
      );
    }
  }

  /// Process scan results and filter for insole devices
  void _onScanResults(List<ScanResult> results) {
    for (final result in results) {
      final deviceName = result.device.platformName;
      final deviceId = result.device.remoteId.str;
      
      // Filter: Only include devices that match our insole name patterns
      // In a production app, you would filter by your specific device name or UUID
      final isInsoleDevice = _deviceNameFilters.any(
        (filter) => deviceName.toLowerCase().contains(filter.toLowerCase()),
      );
      
      // For demo purposes, also include devices with valid names
      // Remove this condition in production
      final hasValidName = deviceName.isNotEmpty;
      
      if (isInsoleDevice || hasValidName) {
        // Check if device is already in the list
        final existingIndex = _discoveredDevices.indexWhere(
          (d) => d.id == deviceId,
        );
        
        final device = InsoleDevice(
          id: deviceId,
          name: deviceName.isNotEmpty ? deviceName : 'Unknown Device',
          bleDevice: result.device,
          rssi: result.rssi,
        );
        
        if (existingIndex >= 0) {
          // Update existing device (signal strength may have changed)
          _discoveredDevices[existingIndex] = device;
        } else {
          // Add new device
          _discoveredDevices.add(device);
        }
      }
    }
    
    // Sort by signal strength (strongest first)
    _discoveredDevices.sort((a, b) => b.rssi.compareTo(a.rssi));
    
    // Update status message
    if (_discoveredDevices.isNotEmpty) {
      _statusMessage = 'Found ${_discoveredDevices.length} device(s)';
    }
    
    notifyListeners();
  }

  /// Handle scan timeout
  void _onScanTimeout() {
    _stopScanning();
    
    if (_discoveredDevices.isEmpty) {
      _updateState(
        InsoleConnectionState.failed,
        error: 'No insole found nearby. Make sure your insole is turned on.',
      );
    } else {
      _updateState(
        InsoleConnectionState.disconnected,
        message: 'Found ${_discoveredDevices.length} device(s). Tap to connect.',
      );
    }
  }

  /// Stop the current scan
  Future<void> _stopScanning() async {
    _scanTimeoutTimer?.cancel();
    _scanSubscription?.cancel();
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      // Ignore errors when stopping scan
    }
  }

  /// Stop scanning (public method)
  Future<void> stopScanning() async {
    await _stopScanning();
    if (_connectionState == InsoleConnectionState.scanning) {
      _updateState(
        InsoleConnectionState.disconnected,
        message: _discoveredDevices.isEmpty 
            ? 'Ready to connect'
            : 'Found ${_discoveredDevices.length} device(s)',
      );
    }
  }

  // =========================================================================
  // DEVICE CONNECTION
  // =========================================================================
  
  /// Connect to a specific insole device
  /// Called when user taps on a device in the list
  Future<void> connectToDevice(InsoleDevice device) async {
    // Ensure we have the BLE device reference
    if (device.bleDevice == null) {
      _updateState(
        InsoleConnectionState.failed,
        error: 'Cannot connect to this device',
      );
      return;
    }
    
    // Stop scanning first
    await _stopScanning();
    
    // Update state to connecting
    _updateState(
      InsoleConnectionState.connecting,
      message: 'Connecting to ${device.name}...',
    );
    
    try {
      // Set up connection state listener
      _connectionSubscription?.cancel();
      _connectionSubscription = device.bleDevice!.connectionState.listen(
        (state) => _onConnectionStateChanged(state, device),
      );
      
      // Set connection timeout
      _connectionTimeoutTimer?.cancel();
      _connectionTimeoutTimer = Timer(_connectionTimeout, () {
        _onConnectionTimeout(device);
      });
      
      // Attempt to connect
      // autoConnect: false for immediate connection attempt
      // timeout: handled manually for better UX
      await device.bleDevice!.connect(
        autoConnect: false,
        timeout: _connectionTimeout,
      );
      
    } catch (e) {
      _connectionTimeoutTimer?.cancel();
      _updateState(
        InsoleConnectionState.failed,
        error: 'Could not connect to ${device.name}. Please try again.',
      );
    }
  }

  /// Handle connection state changes
  void _onConnectionStateChanged(
    BluetoothConnectionState state, 
    InsoleDevice device,
  ) {
    switch (state) {
      case BluetoothConnectionState.connected:
        _connectionTimeoutTimer?.cancel();
        _connectedDevice = device;
        _updateState(
          InsoleConnectionState.connected,
          message: 'Connected to ${device.name}',
        );
        // Save as last connected device for auto-reconnect
        _saveLastConnectedDevice(device);
        break;
        
      case BluetoothConnectionState.disconnected:
        if (_connectionState == InsoleConnectionState.connecting) {
          // Connection failed
          _updateState(
            InsoleConnectionState.failed,
            error: 'Connection lost. Please try again.',
          );
        } else if (_connectionState == InsoleConnectionState.connected) {
          // Device disconnected unexpectedly
          _connectedDevice = null;
          _updateState(
            InsoleConnectionState.disconnected,
            message: 'Insole disconnected',
          );
        }
        break;
        
      default:
        break;
    }
  }

  /// Handle connection timeout
  void _onConnectionTimeout(InsoleDevice device) {
    _connectionSubscription?.cancel();
    _updateState(
      InsoleConnectionState.failed,
      error: 'Connection timed out. Make sure ${device.name} is nearby.',
    );
    
    // Try to disconnect cleanly
    try {
      device.bleDevice?.disconnect();
    } catch (e) {
      // Ignore disconnect errors
    }
  }

  /// Disconnect from the current device
  Future<void> disconnectDevice() async {
    await _disconnectDevice();
    _updateState(
      InsoleConnectionState.disconnected,
      message: 'Ready to connect',
    );
  }

  /// Internal disconnect method
  Future<void> _disconnectDevice() async {
    _connectionSubscription?.cancel();
    _connectionTimeoutTimer?.cancel();
    
    if (_connectedDevice?.bleDevice != null) {
      try {
        await _connectedDevice!.bleDevice!.disconnect();
      } catch (e) {
        // Ignore disconnect errors
      }
    }
    _connectedDevice = null;
  }

  // =========================================================================
  // AUTO-RECONNECT LOGIC
  // =========================================================================
  
  /// Save the last connected device for auto-reconnect
  Future<void> _saveLastConnectedDevice(InsoleDevice device) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastConnectedDeviceKey, device.id);
      await prefs.setString(_lastConnectedDeviceNameKey, device.name);
    } catch (e) {
      // Ignore storage errors
    }
  }

  /// Get the last connected device info
  Future<InsoleDevice?> _getLastConnectedDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_lastConnectedDeviceKey);
      final name = prefs.getString(_lastConnectedDeviceNameKey);
      
      if (id != null && name != null) {
        return InsoleDevice(id: id, name: name);
      }
    } catch (e) {
      // Ignore storage errors
    }
    return null;
  }

  /// Try to auto-reconnect to the last connected device
  Future<void> _tryAutoReconnect() async {
    final lastDevice = await _getLastConnectedDevice();
    if (lastDevice == null) return;
    
    // Check if device is already connected
    final connectedDevices = FlutterBluePlus.connectedDevices;
    for (final device in connectedDevices) {
      if (device.remoteId.str == lastDevice.id) {
        // Already connected!
        _connectedDevice = InsoleDevice(
          id: device.remoteId.str,
          name: lastDevice.name,
          bleDevice: device,
        );
        _updateState(
          InsoleConnectionState.connected,
          message: 'Connected to ${lastDevice.name}',
        );
        
        // Listen for disconnects
        _connectionSubscription = device.connectionState.listen(
          (state) => _onConnectionStateChanged(state, _connectedDevice!),
        );
        return;
      }
    }
    
    // Inform user about previous device
    _statusMessage = 'Tap to reconnect to ${lastDevice.name}';
    notifyListeners();
  }

  /// Clear the saved device (for manual "forget device" feature)
  Future<void> forgetLastDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastConnectedDeviceKey);
      await prefs.remove(_lastConnectedDeviceNameKey);
    } catch (e) {
      // Ignore storage errors
    }
  }

  // =========================================================================
  // STATE MANAGEMENT HELPERS
  // =========================================================================
  
  /// Update the connection state and messages
  void _updateState(
    InsoleConnectionState newState, {
    String? message,
    String? error,
  }) {
    _connectionState = newState;
    if (message != null) _statusMessage = message;
    if (error != null) {
      _errorMessage = error;
    } else if (newState != InsoleConnectionState.failed) {
      _errorMessage = '';
    }
    notifyListeners();
  }

  /// Reset to initial state (useful for retry)
  void reset() {
    _stopScanning();
    _discoveredDevices.clear();
    _errorMessage = '';
    _updateState(
      InsoleConnectionState.disconnected,
      message: 'Ready to connect',
    );
  }
}
