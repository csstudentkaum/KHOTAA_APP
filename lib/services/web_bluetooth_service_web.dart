// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'dart:async';
import 'package:flutter/foundation.dart';

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

class WebBluetoothService {
  static bool get isSupported {
    try {
      final nav = js.context['navigator'];
      return nav != null && nav['bluetooth'] != null;
    } catch (_) {
      return false;
    }
  }

  static bool get isIOSDevice {
    try {
      final ua = js.context['navigator']['userAgent']?.toString() ?? '';
      return ua.contains('iPhone') || ua.contains('iPad') || ua.contains('iPod');
    } catch (_) {
      return false;
    }
  }

  static Future<WebBluetoothDevice?> requestDevice() async {
    if (!isSupported) return null;

    final completer = Completer<WebBluetoothDevice?>();

    try {
      final bluetooth = js.context['navigator']['bluetooth'];
      final options = js.JsObject.jsify({
        'acceptAllDevices': true,
        'optionalServices': ['battery_service', 'heart_rate'],
      });

      final promise = bluetooth.callMethod('requestDevice', [options]);

      js.JsObject.fromBrowserObject(promise).callMethod('then', [
        js.allowInterop((device) {
          try {
            final jsDevice = js.JsObject.fromBrowserObject(device);
            final id = jsDevice['id']?.toString() ?? 'unknown';
            final name = jsDevice['name']?.toString() ?? 'Unknown Device';
            completer.complete(WebBluetoothDevice(id: id, name: name, jsDevice: jsDevice));
          } catch (_) {
            completer.complete(null);
          }
        }),
        js.allowInterop((error) {
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

  static Future<bool> connectGatt(WebBluetoothDevice device) async {
    final completer = Completer<bool>();
    try {
      final jsDevice = device.jsDevice as js.JsObject;
      final gatt = jsDevice['gatt'];
      if (gatt == null) {
        completer.complete(false);
        return completer.future;
      }
      final promise = js.JsObject.fromBrowserObject(gatt).callMethod('connect', []);
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
