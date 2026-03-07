import 'package:cloud_firestore/cloud_firestore.dart';

/// Consultation model
/// Relationships:
///   - Doctor (1) conducts (0..*) Consultation
///   - Patient (1) undergoes (0..*) Consultation
///   - Consultation (1) generates (1) TreatmentPlan
class Consultation {
  final String consultationID;
  final DateTime? startTime;
  final DateTime? endTime;
  final int duration; // derived attribute (in minutes)
  final DateTime? consultationDate;
  final String patientID; // FK to Patient
  final String doctorID; // FK to Doctor
  final String? treatmentPlanID; // FK to TreatmentPlan (generates relationship)
  final String? patientName; // Denormalized for display in lists
  final String? doctorName; // Denormalized for display in lists
  final String? reason; // Why the patient requested the consultation
  final String status; // 'pending', 'accepted', 'rejected', 'completed'
  final String? timeSlot; // e.g., "10:00 AM"
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Consultation({
    required this.consultationID,
    this.startTime,
    this.endTime,
    this.duration = 0,
    this.consultationDate,
    required this.patientID,
    required this.doctorID,
    this.treatmentPlanID,
    this.patientName,
    this.doctorName,
    this.reason,
    this.status = 'pending',
    this.timeSlot,
    this.createdAt,
    this.updatedAt,
  });

  // ── Firestore serialization ──

  /// Create a Consultation from a Firestore document map.
  factory Consultation.fromMap(Map<String, dynamic> map, {String? id}) {
    return Consultation(
      consultationID: id ?? map['consultationID'] as String,
      startTime: map['startTime'] != null
          ? (map['startTime'] as Timestamp).toDate()
          : null,
      endTime: map['endTime'] != null
          ? (map['endTime'] as Timestamp).toDate()
          : null,
      duration: map['duration'] as int? ?? 0,
      consultationDate: map['consultationDate'] != null
          ? (map['consultationDate'] as Timestamp).toDate()
          : null,
      patientID: map['patientID'] as String? ?? '',
      doctorID: map['doctorID'] as String? ?? '',
      treatmentPlanID: map['treatmentPlanID'] as String?,
      patientName: map['patientName'] as String?,
      doctorName: map['doctorName'] as String?,
      reason: map['reason'] as String?,
      status: map['status'] as String? ?? 'pending',
      timeSlot: map['timeSlot'] as String?,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Convert the Consultation to a Map for Firestore storage.
  Map<String, dynamic> toMap() {
    return {
      'consultationID': consultationID,
      'startTime': startTime != null ? Timestamp.fromDate(startTime!) : null,
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'duration': duration,
      'consultationDate': consultationDate != null
          ? Timestamp.fromDate(consultationDate!)
          : null,
      'patientID': patientID,
      'doctorID': doctorID,
      'treatmentPlanID': treatmentPlanID,
      'patientName': patientName,
      'doctorName': doctorName,
      'reason': reason,
      'status': status,
      'timeSlot': timeSlot,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// Convenience factory from a Firestore DocumentSnapshot.
  factory Consultation.fromDocument(DocumentSnapshot doc) {
    return Consultation.fromMap(doc.data() as Map<String, dynamic>, id: doc.id);
  }

  // ── Methods from UML ──

  /// Start a new consultation (creates an instance with startTime = now).
  static Consultation startConsultation({
    required String patientID,
    required String doctorID,
    String? patientName,
    String? doctorName,
    String? reason,
    String? timeSlot,
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
      patientName: patientName,
      doctorName: doctorName,
      reason: reason,
      status: 'pending',
      timeSlot: timeSlot,
      createdAt: now,
    );
  }

  /// End the consultation and calculate duration.
  Consultation endConsultation() {
    final now = DateTime.now();
    final durationMinutes = now.difference(startTime!).inMinutes;
    return copyWith(
      endTime: now,
      duration: durationMinutes,
      status: 'completed',
    );
  }

  /// Get the duration of the consultation in minutes (derived).
  double getDuration() {
    if (startTime == null || endTime == null) return 0;
    return endTime!.difference(startTime!).inMinutes.toDouble();
  }

  // ── Helper getters ──

  /// Check if consultation is upcoming (today or future, and not finished)
  bool get isUpcoming {
    final date = consultationDate;
    if (date == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final consultDay = DateTime(date.year, date.month, date.day);
    return !consultDay.isBefore(today) &&
        (status == 'pending' || status == 'accepted');
  }

  /// Check if consultation is past (before today, or completed/rejected)
  bool get isPast {
    final date = consultationDate;
    if (date == null) return true;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final consultDay = DateTime(date.year, date.month, date.day);
    return consultDay.isBefore(today) ||
        status == 'completed' ||
        status == 'rejected';
  }

  /// Formatted date string
  String get formattedDate {
    final date = consultationDate;
    if (date == null) return 'No date';
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  String toString() {
    return 'Consultation(consultationID: $consultationID, status: $status, '
        'patientName: $patientName, doctorID: $doctorID)';
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
    String? patientName,
    String? doctorName,
    String? reason,
    String? status,
    String? timeSlot,
    DateTime? createdAt,
    DateTime? updatedAt,
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
      patientName: patientName ?? this.patientName,
      doctorName: doctorName ?? this.doctorName,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      timeSlot: timeSlot ?? this.timeSlot,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
