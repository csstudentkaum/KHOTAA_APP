import 'package:cloud_firestore/cloud_firestore.dart';

class Alert {
  final String alertID;
  final DateTime raisedAt;
  final String message;
  final bool viewed;

  // Relationships
  final String patientId; // FK → Patient
  final String
  sensorReadingId; // FK → SensorReading (SensorReading TRIGGERS Alert)

  Alert({
    required this.alertID,
    required this.raisedAt,
    required this.message,
    required this.viewed,
    required this.patientId,
    required this.sensorReadingId,
  });

  factory Alert.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Alert(
      alertID: doc.id,
      raisedAt: (data['raisedAt'] as Timestamp).toDate(),
      message: data['message'] ?? '',
      viewed: data['viewed'] ?? false,
      patientId: data['patientId'] ?? '',
      sensorReadingId: data['sensorReadingId'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'raisedAt': Timestamp.fromDate(raisedAt),
      'message': message,
      'viewed': viewed,
      'patientId': patientId, // FK → Patient
      'sensorReadingId': sensorReadingId, // FK → SensorReading
    };
  }

  // Factory: create Alert directly from a SensorReading
  factory Alert.fromSensorReading({
    required String alertID,
    required String patientId,
    required String sensorReadingId,
    required String message,
  }) {
    return Alert(
      alertID: alertID,
      raisedAt: DateTime.now(),
      message: message,
      viewed: false,
      patientId: patientId,
      sensorReadingId: sensorReadingId,
    );
  }
}
