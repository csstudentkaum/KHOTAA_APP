
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/bluetooth_service.dart';
import '../../state/bluetooth_provider.dart';

/// =============================================================================
/// CONNECT INSOLE SCREEN
/// =============================================================================
/// This screen allows patients to connect their smart insole device via Bluetooth.
/// The UI design is preserved exactly as specified - only the connection logic
/// has been enhanced with real BLE functionality.
///
/// BLUETOOTH FLOW:
/// 1. Screen loads -> Initialize BluetoothService
/// 2. User taps "Connect" or device card -> Start BLE scan
/// 3. Discovered devices appear in the list (filtered for insole devices)
/// 4. User taps a device -> Connection attempt begins
/// 5. Success: "Connected" state shown, user can proceed
/// 6. Failure: Error message with retry option
/// =============================================================================

class ConnectInsoleScreen extends StatefulWidget {
  const ConnectInsoleScreen({super.key});

  @override
  State<ConnectInsoleScreen> createState() => _ConnectInsoleScreenState();
}

class _ConnectInsoleScreenState extends State<ConnectInsoleScreen> 
    with WidgetsBindingObserver {
  
  /// Index of the currently selected device in the list
  int selectedDevice = 0;
  
  /// Reference to the BluetoothService instance
  late BluetoothService _bluetoothService;
  
  /// Flag to track if we've initialized
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // Add observer to handle app lifecycle (for reconnection when app resumes)
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize BluetoothService only once
    if (!_initialized) {
      _bluetoothService = context.read<BluetoothService>();
      _initializeBluetooth();
      _initialized = true;
    }
  }

  /// Initialize Bluetooth and start listening for state changes
  Future<void> _initializeBluetooth() async {
    await _bluetoothService.initialize();
    
    // If Bluetooth is off, show dialog after a short delay (for UX)
    if (_bluetoothService.connectionState == InsoleConnectionState.bluetoothOff) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showBluetoothOffDialog(context);
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app resume - check Bluetooth state and reconnect if needed
    if (state == AppLifecycleState.resumed) {
      _bluetoothService.initialize();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Handle device tap - either connect or start scanning
  Future<void> _onDeviceTap(int index) async {
    final service = context.read<BluetoothService>();
    
    // Check Bluetooth state first
    if (service.connectionState == InsoleConnectionState.bluetoothOff) {
      showBluetoothOffDialog(context);
      return;
    }
    
    // If we have discovered devices, connect to the selected one
    if (service.discoveredDevices.isNotEmpty && 
        index < service.discoveredDevices.length) {
      final device = service.discoveredDevices[index];
      setState(() => selectedDevice = index);
      await service.connectToDevice(device);
    } else {
      // Start scanning if no devices found yet
      await service.startScanning();
    }
  }

  /// Handle the main "Connect Insole" / "Let's Start" button tap
  Future<void> _onConnectButtonPressed() async {
    final service = context.read<BluetoothService>();
    
    // Check Bluetooth state first
    if (service.connectionState == InsoleConnectionState.bluetoothOff) {
      showBluetoothOffDialog(context);
      return;
    }
    
    // Check permissions
    if (service.connectionState == InsoleConnectionState.permissionDenied) {
      showPermissionDeniedDialog(context);
      return;
    }
    
    // If already connected, proceed to next screen
    if (service.isConnected) {
      final device = service.connectedDevice;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF64ADB3)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Connected to ${device?.name ?? "Insole"}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF3D6A99),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          elevation: 8,
        ),
      );
      // TODO: Navigate to the next screen (e.g., monitoring dashboard)
      return;
    }
    
    // If connection failed, show retry dialog
    if (service.connectionState == InsoleConnectionState.failed) {
      final shouldRetry = await showConnectionFailedDialog(
        context, 
        service.errorMessage,
      );
      if (shouldRetry) {
        service.reset();
        await service.startScanning();
      }
      return;
    }
    
    // If scanning or connecting, let it continue
    if (service.isScanning || service.isConnecting) {
      return;
    }
    
    // If we have devices, connect to the selected one
    if (service.discoveredDevices.isNotEmpty) {
      final device = service.discoveredDevices[selectedDevice];
      await service.connectToDevice(device);
    } else {
      // Start scanning for devices
      await service.startScanning();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch BluetoothService for reactive updates
    final bluetoothService = context.watch<BluetoothService>();
    
    // Get discovered devices or use placeholder list when empty/scanning
    final devices = bluetoothService.discoveredDevices;
    final bool hasDevices = devices.isNotEmpty;
    
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            // Find the PatientShell ancestor and switch to home tab
            final shellState = context.findAncestorStateOfType<State>();
            if (shellState != null && shellState.mounted) {
              // Use the back button behavior from PopScope
              Navigator.maybePop(context);
            }
          },
        ),
      ),
      body: Column(
        children: [
          // =================================================================
          // HEADER SECTION (preserved exactly)
          // =================================================================
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF64ADB3), Color(0xFF3D6A99)],
              ),
            ),
            padding: const EdgeInsets.only(top: 60, bottom: 24),
            child: Column(
              children: [
                // Bluetooth icon with scanning indicator
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Color(0xFF85B1D2), width: 7),
                    color: Color(0xFF2F4A5F),
                  ),
                  child: bluetoothService.isScanning
                      ? const ScanningIndicator() // Animated scanning icon
                      : Icon(
                          bluetoothService.isConnected 
                              ? Icons.bluetooth_connected 
                              : Icons.bluetooth,
                          size: 70,
                          color: Colors.white,
                        ),
                ),
                const SizedBox(height: 18),
                // Title changes based on state
                Text(
                  bluetoothService.isConnected 
                      ? 'INSOLE CONNECTED'
                      : 'CONNECT INSOLE',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                // Status message
                if (bluetoothService.statusMessage.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      bluetoothService.statusMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // =================================================================
          // DEVICES LIST SECTION (structure preserved, data dynamic)
          // =================================================================
          Expanded(
            child: hasDevices
                ? _buildDevicesList(bluetoothService, devices)
                : _buildEmptyState(bluetoothService),
          ),
          
          // =================================================================
          // START BUTTON (preserved exactly)
          // =================================================================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3D6A99), Color(0xFF2F4A5F)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.zero,
                      elevation: 0,
                    ),
                    onPressed: bluetoothService.isScanning || 
                               bluetoothService.isConnecting
                        ? null  // Disable button while busy
                        : _onConnectButtonPressed,
                    child: Center(
                      child: _buildButtonContent(bluetoothService),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Build the devices list when devices are discovered
  Widget _buildDevicesList(
    BluetoothService service, 
    List<InsoleDevice> devices,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: ListView.builder(
        itemCount: devices.length,
        padding: EdgeInsets.zero,
        itemBuilder: (context, i) {
          final device = devices[i];
          final isSelected = selectedDevice == i;
          final isConnectedDevice = service.isConnected && 
                                    service.connectedDevice?.id == device.id;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: GestureDetector(
              onTap: () => _onDeviceTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: isConnectedDevice 
                      ? Color(0xFF64ADB3) 
                      : isSelected 
                          ? Color(0xFF64ADB3) 
                          : Color(0xFF85B1D2),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isSelected || isConnectedDevice
                      ? [
                          BoxShadow(
                            color: Color(0xFF3D6A99).withOpacity(0.15),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: ListTile(
                  title: Text(
                    device.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    device.id,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16, 
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isConnectedDevice 
                          ? Color(0xFF3D6A99) 
                          : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isConnectedDevice 
                            ? Color(0xFF3D6A99) 
                            : Color(0xFF64ADB3),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      _getDeviceButtonText(service, device),
                      style: TextStyle(
                        color: isConnectedDevice 
                            ? Colors.white 
                            : Color(0xFF3D6A99),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Get the button text for each device card
  String _getDeviceButtonText(BluetoothService service, InsoleDevice device) {
    if (service.isConnected && service.connectedDevice?.id == device.id) {
      return 'Connected';
    }
    if (service.isConnecting && 
        service.discoveredDevices.isNotEmpty &&
        selectedDevice < service.discoveredDevices.length &&
        service.discoveredDevices[selectedDevice].id == device.id) {
      return 'Connecting...';
    }
    return 'Connect';
  }

  /// Build empty state when no devices discovered yet
  Widget _buildEmptyState(BluetoothService service) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              service.isScanning 
                  ? Icons.bluetooth_searching
                  : service.connectionState == InsoleConnectionState.failed
                      ? Icons.error_outline
                      : Icons.bluetooth,
              size: 64,
              color: service.connectionState == InsoleConnectionState.failed
                  ? Colors.orange
                  : Color(0xFF85B1D2),
            ),
            const SizedBox(height: 16),
            Text(
              service.isScanning
                  ? 'Searching for your insole...'
                  : service.connectionState == InsoleConnectionState.failed
                      ? service.errorMessage
                      : 'Tap the button below to\nfind your insole',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: service.connectionState == InsoleConnectionState.failed
                    ? Colors.orange.shade700
                    : Colors.grey[600],
              ),
            ),
            if (service.isScanning) ...[
              const SizedBox(height: 24),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF64ADB3)),
              ),
            ],
            if (service.connectionState == InsoleConnectionState.failed) ...[
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: () {
                  service.reset();
                  service.startScanning();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: TextButton.styleFrom(
                  foregroundColor: Color(0xFF3D6A99),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build the main button content based on current state
  Widget _buildButtonContent(BluetoothService service) {
    if (service.isScanning) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          SizedBox(width: 12),
          Text(
            'SEARCHING...',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 1.1,
            ),
          ),
        ],
      );
    }
    
    if (service.isConnecting) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          SizedBox(width: 12),
          Text(
            'CONNECTING...',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 1.1,
            ),
          ),
        ],
      );
    }
    
    if (service.isConnected) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text(
            "LET'S START!",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 1.1,
            ),
          ),
        ],
      );
    }
    
    if (service.connectionState == InsoleConnectionState.failed) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.refresh, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text(
            'TRY AGAIN',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 1.1,
            ),
          ),
        ],
      );
    }
    
    // Default state - ready to scan
    return const Text(
      "LET'S START!",
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 16,
        letterSpacing: 1.1,
      ),
    );
  }
}







