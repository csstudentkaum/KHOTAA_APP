import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/app_theme.dart';
import '../../services/bluetooth_service.dart';
import '../../state/bluetooth_provider.dart';


const _kDarkBlue = Color(0xFF3D6A99);
const _kTeal = Color(0xFF64ADB3);

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
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  /// Index of the currently selected device in the list
  int selectedDevice = 0;

  /// Reference to the BluetoothService instance
  late BluetoothService _bluetoothService;

  /// Flag to track if we've initialized
  bool _initialized = false;

  /// Pulse animation (same as AI Doctor screen)
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _bluetoothService = context.read<BluetoothService>();
      _initializeBluetooth();
      _initialized = true;
    }
  }

  Future<void> _initializeBluetooth() async {
    await _bluetoothService.initialize();
    // Do NOT show Bluetooth-off dialog on screen open.
    // It will be shown only when the user taps the connect button.
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _bluetoothService.recheckPermissions();
      _bluetoothService.initialize();
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _onDeviceTap(int index) async {
    final service = context.read<BluetoothService>();
    if (service.connectionState == InsoleConnectionState.bluetoothOff) {
      showBluetoothOffDialog(context);
      return;
    }
    if (service.discoveredDevices.isNotEmpty &&
        index < service.discoveredDevices.length) {
      setState(() => selectedDevice = index);
      await service.connectToDevice(service.discoveredDevices[index]);
    } else {
      await service.startScanning();
    }
  }

  Future<void> _onConnectButtonPressed() async {
    final service = context.read<BluetoothService>();
    if (service.connectionState == InsoleConnectionState.bluetoothOff) {
      showBluetoothOffDialog(context);
      return;
    }
    if (service.isConnected) {
      // TODO: Navigate to monitoring dashboard
      return;
    }
    if (service.connectionState == InsoleConnectionState.failed) {
      final shouldRetry = await showConnectionFailedDialog(context, service.errorMessage);
      if (shouldRetry) {
        service.reset();
        await service.startScanning();
      }
      return;
    }
    if (service.isScanning || service.isConnecting) return;
    if (service.discoveredDevices.isNotEmpty) {
      await service.connectToDevice(service.discoveredDevices[selectedDevice]);
    } else {
      await service.startScanning();
      if (service.connectionState == InsoleConnectionState.permissionDenied) {
        if (mounted) showPermissionDeniedDialog(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bluetoothService = context.watch<BluetoothService>();
    final devices = bluetoothService.discoveredDevices;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(MediaQuery.of(context).size),
          Transform.translate(
            offset: const Offset(0, -75),
            child: Column(
              children: [
                _buildBluetoothAvatar(bluetoothService),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    bluetoothService.isConnected ? 'Connected and ready' : 'Ready to connect',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -50),
              child: bluetoothService.isConnected && bluetoothService.connectedDevice != null
                  ? _buildConnectedDeviceCard(bluetoothService)
                  : devices.isNotEmpty
                  ? _buildDevicesList(bluetoothService, devices)
                  : _buildEmptyState(bluetoothService),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: bluetoothService.isScanning || bluetoothService.isConnecting
                      ? null
                      : _onConnectButtonPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kTeal,
                    disabledBackgroundColor: _kTeal.withOpacity(0.35),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white70,
                    elevation: 4,
                    shadowColor: _kTeal.withOpacity(0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: 0.3),
                  ),
                  child: _buildButtonContent(bluetoothService),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildHeader(Size size) {
    return ClipPath(
      clipper: _CurvedClipper(),
      child: Container(
        height: size.height * 0.28,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_kTeal, Color(0xFF4D9DA3)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
            child: Column(
              children: [
                const SizedBox(height: 10),
                const Center(
                  child: Text(
                    'Connect Insole',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBluetoothAvatar(BluetoothService service) {
    final anim = _pulseAnimation;

    return AnimatedBuilder(
      animation: anim ?? const AlwaysStoppedAnimation(1.0),
      builder: (context, child) {
        final s = anim?.value ?? 1.0;
        return Transform.scale(
          scale: s,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFA3FBFF), Color(0xFF629699)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFA3FBFF).withOpacity(0.3 * s),
                  blurRadius: 24 * s,
                  spreadRadius: 4 * s,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_kDarkBlue, Color(0xFF2F4A5F)],
                  ),
                ),
                child: Icon(
                  service.isConnected
                      ? Icons.bluetooth_connected_rounded
                      : Icons.bluetooth_rounded,
                  size: 65,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildConnectedDeviceCard(BluetoothService service) {
    final device = service.connectedDevice!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kTeal, width: 1.5),
          boxShadow: [BoxShadow(color: _kTeal.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: _kTeal.withOpacity(0.12), shape: BoxShape.circle),
            child: const Icon(Icons.bluetooth_connected_rounded, color: _kTeal, size: 24),
          ),
          title: Text(
            device.name.isNotEmpty ? device.name : 'Unknown Device',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF222222)),
          ),
          subtitle: Text(device.id, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          trailing: TextButton.icon(
            onPressed: () => service.disconnectDevice(),
            icon: const Icon(Icons.bluetooth_disabled_rounded, size: 18),
            label: const Text('Disconnect'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red[400],
              textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDevicesList(BluetoothService service, List<InsoleDevice> devices) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: ListView.builder(
        itemCount: devices.length,
        padding: EdgeInsets.zero,
        itemBuilder: (context, i) {
          final device = devices[i];
          final isSelected = selectedDevice == i;
          final isConnected = service.isConnected && service.connectedDevice?.id == device.id;
          final String btnText = isConnected
              ? 'Connected'
              : (service.isConnecting && isSelected ? 'Connecting...' : 'Connect');

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: GestureDetector(
              onTap: () => _onDeviceTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: isConnected || isSelected ? _kTeal : const Color(0xFF4D9DA3).withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isSelected || isConnected
                      ? [BoxShadow(color: _kTeal.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 4))]
                      : [],
                ),
                child: ListTile(
                  title: Text(device.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Text(device.id, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isConnected ? _kTeal : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kTeal, width: 1.5),
                    ),
                    child: Text(btnText, style: TextStyle(color: isConnected ? Colors.white : _kTeal, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BluetoothService service) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (service.connectionState == InsoleConnectionState.failed) ...[
              Icon(Icons.error_outline, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              Text(service.errorMessage, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.orange.shade700)),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () { service.reset(); service.startScanning(); },
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: TextButton.styleFrom(foregroundColor: _kTeal),
              ),
            ] else if (service.isScanning) ...[
              const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(_kTeal))),
              const SizedBox(height: 20),
              Text('Searching for your insole…', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.grey[500])),
            ] else ...[
              Text('Tap the button below to\nfind your insole', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.grey[400], height: 1.5)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildButtonContent(BluetoothService service) {
    if (service.isScanning || service.isConnecting) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
          const SizedBox(width: 12),
          Text(service.isScanning ? 'SEARCHING...' : 'CONNECTING...',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.1)),
        ],
      );
    }
    if (service.isConnected) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text("LET'S START!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.1)),
        ],
      );
    }
    if (service.connectionState == InsoleConnectionState.failed) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.refresh, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text('TRY AGAIN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.1)),
        ],
      );
    }
    return const Text("LET'S START!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.1));
  }
}

class _CurvedClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..lineTo(0, size.height - 50)
      ..quadraticBezierTo(size.width * 0.5, size.height + 25, size.width, size.height - 50)
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
