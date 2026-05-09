// Web Bluetooth implementation using browser's Web Bluetooth API
// Works on Chrome/Edge with HTTPS or localhost only.
// Called only when kIsWeb is true.

// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'dart:async';
import 'package:flutter/foundation.dart';

/// Result of a Web Bluetooth scan/request
class WebBluetoothDevice {
  final String id;
  final String name;
  final dynamic _jsDevice;

  WebBluetoothDevice({
    required this.id,
    required this.name,
    required dynamic jsDevice,
  }) : _jsDevice = jsDevice;

  dynamic get jsDevice => _jsDevice;
}

/// Wraps the browser navigator.bluetooth API
class WebBluetoothService {
  static bool get isSupported {
    try {
      final nav = js.context['navigator'];
      return nav != null && nav['bluetooth'] != null;
    } catch (_) {
      return false;
    }
  }

  /// Returns true when running on iOS (iPhone/iPad/iPod).
  /// On iOS, Apple forces all browsers to use WebKit, which blocks the
  /// Web Bluetooth API entirely — even in Chrome or Edge.
  /// The user must install the native KHOTAA app to use Bluetooth.
  static bool get isIOSDevice {
    try {
      final ua = js.context['navigator']['userAgent']?.toString() ?? '';
      return ua.contains('iPhone') ||
          ua.contains('iPad') ||
          ua.contains('iPod');
    } catch (_) {
      return false;
    }
  }

  /// Opens the browser's device picker dialog.
  /// Returns the selected device or null if user cancels / not supported.
  static Future<WebBluetoothDevice?> requestDevice() async {
    if (!isSupported) return null;

    final completer = Completer<WebBluetoothDevice?>();

    try {
      final bluetooth = js.context['navigator']['bluetooth'];

      // Accept all devices that advertise any service or just list all
      final options = js.JsObject.jsify({
        'acceptAllDevices': true,
        'optionalServices': ['battery_service', 'heart_rate'],
      });

      final promise = bluetooth.callMethod('requestDevice', [options]);

      // Convert JS Promise → Dart Future
      js.JsObject.fromBrowserObject(promise)
          .callMethod('then', [
        js.allowInterop((device) {
          try {
            final jsDevice = js.JsObject.fromBrowserObject(device);
            final id = jsDevice['id']?.toString() ?? 'unknown';
            final name = jsDevice['name']?.toString() ?? 'Unknown Device';
            completer.complete(WebBluetoothDevice(
              id: id,
              name: name,
              jsDevice: jsDevice,
            ));
          } catch (e) {
            completer.complete(null);
          }
        }),
        js.allowInterop((error) {
          // User cancelled or error
          debugPrint('Web Bluetooth request cancelled/failed: $error');
          completer.complete(null);
        }),
      ]);
    } catch (e) {
      debugPrint('Web Bluetooth error: $e');
      completer.complete(null);
    }

    return completer.future;
  }

  /// Connect to a Web Bluetooth device's GATT server
  static Future<bool> connectGatt(WebBluetoothDevice device) async {
    final completer = Completer<bool>();
    try {
      final jsDevice = device.jsDevice as js.JsObject;
      final gatt = jsDevice['gatt'];
      if (gatt == null) {
        completer.complete(false);
        return completer.future;
      }
      final promise = js.JsObject.fromBrowserObject(gatt)
          .callMethod('connect', []);
      js.JsObject.fromBrowserObject(promise).callMethod('then', [
        js.allowInterop((_) => completer.complete(true)),
        js.allowInterop((_) => completer.complete(false)),
      ]);
    } catch (e) {
      debugPrint('GATT connect error: $e');
      completer.complete(false);
    }
    return completer.future;
  }
}
