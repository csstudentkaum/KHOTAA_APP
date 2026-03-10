import 'package:cloud_firestore/cloud_firestore.dart';

/// TreatmentPlan model — aligned with Manar's treatment_plans Firebase structure.
/// Relationships:
///   - Consultation (1) generates (1) TreatmentPlan
class TreatmentPlan {
  final String treatmentPlanID;
  final String consultationID;
  final String doctorId;
  final String patientId;
  final String patientName;
  final String diagnosis;
  final List<Map<String, String>> medications; // [{name, dosage, frequency, duration}]
  final String notes;
  final String status; // 'active' or 'completed'
  final DateTime createdAt;

  // Legacy single-medication fields (backward compat with UML)
  String get medicationName =>
      medications.isNotEmpty ? (medications.first['name'] ?? '') : '';
  String get dosage =>
      medications.isNotEmpty ? (medications.first['dosage'] ?? '') : '';
  String get duration =>
      medications.isNotEmpty ? (medications.first['duration'] ?? '') : '';
  double get frequency => 0.0;
  DateTime get lastUpdated => createdAt;

  TreatmentPlan({
    required this.treatmentPlanID,
    required this.consultationID,
    this.doctorId = '',
    this.patientId = '',
    this.patientName = '',
    this.diagnosis = '',
    this.medications = const [],
    this.notes = '',
    this.status = 'active',
    required this.createdAt,
  });

  // ── Firestore serialization ──

  factory TreatmentPlan.fromMap(Map<String, dynamic> map, {String? id}) {
    final rawMeds = map['medications'] as List<dynamic>? ?? [];
    final meds = rawMeds.map((m) {
      final med = m as Map<String, dynamic>;
      return {
        'name': med['name'] as String? ?? '',
        'dosage': med['dosage'] as String? ?? '',
        'frequency': med['frequency'] as String? ?? '',
        'duration': med['duration'] as String? ?? '',
      };
    }).toList();

    return TreatmentPlan(
      treatmentPlanID: id ?? map['treatmentPlanID'] as String? ?? '',
      consultationID: map['consultationID'] as String? ?? '',
      doctorId: map['doctorId'] as String? ?? '',
      patientId: map['patientId'] as String? ?? '',
      patientName: map['patientName'] as String? ?? '',
      diagnosis: map['diagnosis'] as String? ?? '',
      medications: meds,
      notes: map['notes'] as String? ?? '',
      status: map['status'] as String? ?? 'active',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'treatmentPlanID': treatmentPlanID,
      'consultationID': consultationID,
      'doctorId': doctorId,
      'patientId': patientId,
      'patientName': patientName,
      'diagnosis': diagnosis,
      'medications': medications,
      'notes': notes,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory TreatmentPlan.fromDocument(DocumentSnapshot doc) {
    return TreatmentPlan.fromMap(
      doc.data() as Map<String, dynamic>,
      id: doc.id,
    );
  }

  String getPlanSummary() {
    final medNames = medications.map((m) => m['name']).join(', ');
    return 'Diagnosis: $diagnosis • Medications: $medNames';
  }

  @override
  String toString() {
    return 'TreatmentPlan(id: $treatmentPlanID, diagnosis: $diagnosis, '
        'meds: ${medications.length}, status: $status)';
  }

  TreatmentPlan copyWith({
    String? treatmentPlanID,
    String? consultationID,
    String? doctorId,
    String? patientId,
    String? patientName,
    String? diagnosis,
    List<Map<String, String>>? medications,
    String? notes,
    String? status,
    DateTime? createdAt,
  }) {
    return TreatmentPlan(
      treatmentPlanID: treatmentPlanID ?? this.treatmentPlanID,
      consultationID: consultationID ?? this.consultationID,
      doctorId: doctorId ?? this.doctorId,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      diagnosis: diagnosis ?? this.diagnosis,
      medications: medications ?? this.medications,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
