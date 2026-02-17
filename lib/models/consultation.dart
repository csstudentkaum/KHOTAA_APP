import 'package:cloud_firestore/cloud_firestore.dart';

/// Consultation model
/// Relationships:
///   - Doctor (1) conducts (0..*) Consultation
///   - Patient (1) undergoes (0..*) Consultation
///   - Consultation (1) generates (1) TreatmentPlan
class Consultation {
  final String consultationID;
  final DateTime startTime;
  final DateTime endTime;
  final int duration; // derived attribute (in minutes)
  final DateTime consultationDate;
  final String patientID; // FK to Patient
  final String doctorID; // FK to Doctor
  final String? treatmentPlanID; // FK to TreatmentPlan (generates relationship)

  Consultation({
    required this.consultationID,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.consultationDate,
    required this.patientID,
    required this.doctorID,
    this.treatmentPlanID,
  });

  // ── Firestore serialization ──

  /// Create a Consultation from a Firestore document map.
  factory Consultation.fromMap(Map<String, dynamic> map, {String? id}) {
    return Consultation(
      consultationID: id ?? map['consultationID'] as String,
      startTime: (map['startTime'] as Timestamp).toDate(),
      endTime: (map['endTime'] as Timestamp).toDate(),
      duration: map['duration'] as int? ?? 0,
      consultationDate: (map['consultationDate'] as Timestamp).toDate(),
      patientID: map['patientID'] as String? ?? '',
      doctorID: map['doctorID'] as String? ?? '',
      treatmentPlanID: map['treatmentPlanID'] as String?,
    );
  }

  /// Convert the Consultation to a Map for Firestore storage.
  Map<String, dynamic> toMap() {
    return {
      'consultationID': consultationID,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'duration': duration,
      'consultationDate': Timestamp.fromDate(consultationDate),
      'patientID': patientID,
      'doctorID': doctorID,
      'treatmentPlanID': treatmentPlanID,
    };
  }

  /// Convenience factory from a Firestore DocumentSnapshot.
  factory Consultation.fromDocument(DocumentSnapshot doc) {
    return Consultation.fromMap(
      doc.data() as Map<String, dynamic>,
      id: doc.id,
    );
  }

  // ── Methods from UML ──

  /// Start a new consultation (creates an instance with startTime = now).
  static Consultation startConsultation({
    required String patientID,
    required String doctorID,
  }) {
    final now = DateTime.now();
    return Consultation(
      consultationID: FirebaseFirestore.instance
          .collection('consultations')
          .doc()
          .id,
      startTime: now,
      endTime: now, // will be updated when ended
      duration: 0,
      consultationDate: DateTime(now.year, now.month, now.day),
      patientID: patientID,
      doctorID: doctorID,
    );
  }

  /// End the consultation and calculate duration.
  Consultation endConsultation() {
    final now = DateTime.now();
    final durationMinutes = now.difference(startTime).inMinutes;
    return copyWith(
      endTime: now,
      duration: durationMinutes,
    );
  }

  /// Get the duration of the consultation in minutes (derived).
  double getDuration() {
    return endTime.difference(startTime).inMinutes.toDouble();
  }

  @override
  String toString() {
    return 'Consultation(consultationID: $consultationID, startTime: $startTime, '
        'endTime: $endTime, duration: $duration, consultationDate: $consultationDate, '
        'patientID: $patientID, doctorID: $doctorID, '
        'treatmentPlanID: $treatmentPlanID)';
  }

  /// Creates a copy with the given fields replaced.
  Consultation copyWith({
    String? consultationID,
    DateTime? startTime,
    DateTime? endTime,
    int? duration,
    DateTime? consultationDate,
    String? patientID,
    String? doctorID,
    String? treatmentPlanID,
  }) {
    return Consultation(
      consultationID: consultationID ?? this.consultationID,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
      consultationDate: consultationDate ?? this.consultationDate,
      patientID: patientID ?? this.patientID,
      doctorID: doctorID ?? this.doctorID,
      treatmentPlanID: treatmentPlanID ?? this.treatmentPlanID,
    );
  }
}
