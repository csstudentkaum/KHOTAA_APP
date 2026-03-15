import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/bluetooth_service.dart';

/// =============================================================================
/// BLUETOOTH PROVIDER
/// =============================================================================
/// This file provides utilities for integrating the BluetoothService with
/// Provider state management. It includes:
/// - Provider setup helpers
/// - Extension methods for easy access
/// - Widget wrappers for common patterns
/// =============================================================================

/// Create a ChangeNotifierProvider for BluetoothService
/// Use this in your app's provider tree
ChangeNotifierProvider<BluetoothService> createBluetoothProvider() {
  return ChangeNotifierProvider<BluetoothService>(
    create: (_) => BluetoothService(),
  );
}

/// Extension methods for easy access to BluetoothService
extension BluetoothProviderExtension on BuildContext {
  /// Get BluetoothService with listening (rebuilds widget on changes)
  BluetoothService get watchBluetooth => watch<BluetoothService>();
  
  /// Get BluetoothService without listening (for one-time reads or actions)
  BluetoothService get readBluetooth => read<BluetoothService>();
}

/// =============================================================================
/// BLUETOOTH DIALOG HELPERS
/// =============================================================================
/// User-friendly dialogs for common Bluetooth scenarios

/// Show a dialog when Bluetooth is turned off
/// Guides the user to enable Bluetooth in a non-technical way
Future<void> showBluetoothOffDialog(BuildContext context) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.bluetooth_disabled, color: Color(0xFF3D6A99), size: 28),
          SizedBox(width: 12),
          Text(
            'Bluetooth is Off',
            style: TextStyle(
              color: Color(0xFF2F4A5F),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'To connect your insole, please turn on Bluetooth:',
            style: TextStyle(fontSize: 15, color: Colors.black87),
          ),
          SizedBox(height: 16),
          _InstructionStep(number: '1', text: 'Open your phone Settings'),
          _InstructionStep(number: '2', text: 'Find Bluetooth'),
          _InstructionStep(number: '3', text: 'Turn it ON'),
          SizedBox(height: 8),
          Text(
            'Then come back here and try again.',
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'OK, I\'ll do that',
            style: TextStyle(
              color: Color(0xFF3D6A99),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Show a dialog when permissions are denied
Future<void> showPermissionDeniedDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.security, color: Color(0xFF3D6A99), size: 28),
          SizedBox(width: 12),
          Text(
            'Permission Needed',
            style: TextStyle(
              color: Color(0xFF2F4A5F),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'To find and connect to your insole, we need permission to use Bluetooth.',
            style: TextStyle(fontSize: 15, color: Colors.black87),
          ),
          SizedBox(height: 16),
          Text(
            'How to enable:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          SizedBox(height: 8),
          _InstructionStep(number: '1', text: 'Tap "Open Settings" below'),
          _InstructionStep(number: '2', text: 'Find "Permissions"'),
          _InstructionStep(number: '3', text: 'Enable Bluetooth & Location'),
          _InstructionStep(number: '4', text: 'Come back and try again'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            Navigator.of(context).pop();
            // Open app settings so user can grant permission
            await openAppSettings();
          },
          icon: const Icon(Icons.settings, size: 18),
          label: const Text('Open Settings'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3D6A99),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Show a connection failed dialog with retry option
Future<bool> showConnectionFailedDialog(
  BuildContext context, 
  String errorMessage,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.error_outline, color: Colors.orange, size: 28),
          SizedBox(width: 12),
          Text(
            'Connection Issue',
            style: TextStyle(
              color: Color(0xFF2F4A5F),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            errorMessage,
            style: const TextStyle(fontSize: 15, color: Colors.black87),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tips:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          const _InstructionStep(number: '•', text: 'Make sure your insole is turned on'),
          const _InstructionStep(number: '•', text: 'Stay close to your insole'),
          const _InstructionStep(number: '•', text: 'Try turning Bluetooth off and on'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3D6A99),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Try Again',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Instruction step widget for dialogs
class _InstructionStep extends StatelessWidget {
  final String number;
  final String text;

  const _InstructionStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF64ADB3).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Color(0xFF3D6A99),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

/// =============================================================================
/// SCANNING INDICATOR WIDGET
/// =============================================================================
/// Animated indicator shown while scanning for devices

class ScanningIndicator extends StatefulWidget {
  const ScanningIndicator({super.key});

  @override
  State<ScanningIndicator> createState() => _ScanningIndicatorState();
}

class _ScanningIndicatorState extends State<ScanningIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: const Icon(
        Icons.bluetooth_searching,
        color: Color(0xFF64ADB3),
        size: 24,
      ),
    );
  }
}
