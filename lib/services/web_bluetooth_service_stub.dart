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
  static bool get isSupported => false;

  static bool get isIOSDevice => false;

  static Future<WebBluetoothDevice?> requestDevice() async => null;

  static Future<bool> connectGatt(WebBluetoothDevice device) async => false;
}
