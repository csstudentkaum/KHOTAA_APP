import 'package:cloud_firestore/cloud_firestore.dart';

/// Device model class
/// Represents a Bluetooth insole device connected to a patient.
/// Maps to a subcollection 'devices' under each patient document,
/// or to a top-level 'devices' collection with a patientId reference.
///
/// Relationships (from UML):
/// - Patient has 1..* Devices
/// - Device collects 0..* SensorReadings
class DeviceModel {
  final String deviceId;
  final String patientId; // Reference to the owning Patient
  final bool bluetoothStatus;
  final String? deviceName;
  final DateTime? lastConnected;
  final DateTime? createdAt;

  DeviceModel({
    required this.deviceId,
    required this.patientId,
    this.bluetoothStatus = false,
    this.deviceName,
    this.lastConnected,
    this.createdAt,
  });

  /// Create a DeviceModel from Firestore document snapshot
  factory DeviceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DeviceModel(
      deviceId: doc.id,
      patientId: data['patientId'] ?? '',
      bluetoothStatus: data['bluetoothStatus'] ?? false,
      deviceName: data['deviceName'],
      lastConnected: data['lastConnected'] != null
          ? (data['lastConnected'] as Timestamp).toDate()
          : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Create a DeviceModel from a Map
  factory DeviceModel.fromMap(Map<String, dynamic> data, String id) {
    return DeviceModel(
      deviceId: id,
      patientId: data['patientId'] ?? '',
      bluetoothStatus: data['bluetoothStatus'] ?? false,
      deviceName: data['deviceName'],
      lastConnected: data['lastConnected'] != null
          ? (data['lastConnected'] as Timestamp).toDate()
          : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Convert DeviceModel to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'bluetoothStatus': bluetoothStatus,
      'deviceName': deviceName,
      'lastConnected':
          lastConnected != null ? Timestamp.fromDate(lastConnected!) : null,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  /// Connect the device (returns a new instance with updated status)
  DeviceModel connect() {
    return copyWith(bluetoothStatus: true, lastConnected: DateTime.now());
  }

  /// Disconnect the device (returns a new instance with updated status)
  DeviceModel disconnect() {
    return copyWith(bluetoothStatus: false);
  }

  /// Get the current status as a readable string
  String getStatus() {
    return bluetoothStatus ? 'Connected' : 'Disconnected';
  }

  /// Create a copy with updated fields
  DeviceModel copyWith({
    String? deviceId,
    String? patientId,
    bool? bluetoothStatus,
    String? deviceName,
    DateTime? lastConnected,
    DateTime? createdAt,
  }) {
    return DeviceModel(
      deviceId: deviceId ?? this.deviceId,
      patientId: patientId ?? this.patientId,
      bluetoothStatus: bluetoothStatus ?? this.bluetoothStatus,
      deviceName: deviceName ?? this.deviceName,
      lastConnected: lastConnected ?? this.lastConnected,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'DeviceModel(deviceId: $deviceId, patientId: $patientId, status: ${getStatus()})';
  }
}
