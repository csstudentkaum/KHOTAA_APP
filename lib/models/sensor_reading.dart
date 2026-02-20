import 'package:cloud_firestore/cloud_firestore.dart';

class SensorReading {
  final String sensorReadingID;
  final DateTime timestamp;
  final String footSide;
  final String sensorRegion;
  final double pressureValue;
  final double temperatureValue;

  // Relationships
  final String patientId; // FK → Patient
  final String deviceId; // FK → Device (Device COLLECTS SensorReading)

  SensorReading({
    required this.sensorReadingID,
    required this.timestamp,
    required this.footSide,
    required this.sensorRegion,
    required this.pressureValue,
    required this.temperatureValue,
    required this.patientId,
    required this.deviceId,
  });

  factory SensorReading.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SensorReading(
      sensorReadingID: doc.id,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      footSide: data['footSide'] ?? '',
      sensorRegion: data['sensorRegion'] ?? '',
      pressureValue: (data['pressureValue'] ?? 0.0).toDouble(),
      temperatureValue: (data['temperatureValue'] ?? 0.0).toDouble(),
      patientId: data['patientId'] ?? '',
      deviceId: data['deviceId'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'timestamp': Timestamp.fromDate(timestamp),
      'footSide': footSide,
      'sensorRegion': sensorRegion,
      'pressureValue': pressureValue,
      'temperatureValue': temperatureValue,
      'patientId': patientId, // FK → Patient
      'deviceId': deviceId, // FK → Device
    };
  }

  // Abnormal value detection
  bool get isAbnormalPressure => pressureValue > 200.0;
  bool get isAbnormalTemperature =>
      temperatureValue > 37.5 || temperatureValue < 35.0;
  bool get hasAbnormalValues => isAbnormalPressure || isAbnormalTemperature;

  // Relationship: SensorReading TRIGGERS Alert
  String? get triggerAlertMessage {
    if (isAbnormalPressure && isAbnormalTemperature) {
      return 'Abnormal pressure ($pressureValue) and temperature ($temperatureValue°C) detected in $footSide foot - $sensorRegion region';
    } else if (isAbnormalPressure) {
      return 'Abnormal pressure ($pressureValue) detected in $footSide foot - $sensorRegion region';
    } else if (isAbnormalTemperature) {
      return 'Abnormal temperature ($temperatureValue°C) detected in $footSide foot - $sensorRegion region';
    }
    return null;
  }
}
