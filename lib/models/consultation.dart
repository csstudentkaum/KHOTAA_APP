import 'package:cloud_firestore/cloud_firestore.dart';

/// Consultation status values
/// pending   → patient requested, doctor not yet accepted
/// accepted  → doctor accepted, waiting for session time
/// active    → session in progress (chat + video open)
/// followUp  → session ended but follow-up needed, chat open
/// completed → fully done, chat locked read-only
/// rejected  → doctor rejected the request
enum ConsultationStatus { pending, accepted, active, followUp, completed, rejected }

extension ConsultationStatusX on ConsultationStatus {
  String get value {
    switch (this) {
      case ConsultationStatus.pending: return 'pending';
      case ConsultationStatus.accepted: return 'accepted';
      case ConsultationStatus.active: return 'active';
      case ConsultationStatus.followUp: return 'followUp';
      case ConsultationStatus.completed: return 'completed';
      case ConsultationStatus.rejected: return 'rejected';
    }
  }

  static ConsultationStatus fromString(String s) {
    switch (s) {
      case 'accepted': return ConsultationStatus.accepted;
      case 'active': return ConsultationStatus.active;
      case 'followUp': return ConsultationStatus.followUp;
      case 'completed': return ConsultationStatus.completed;
      case 'rejected': return ConsultationStatus.rejected;
      default: return ConsultationStatus.pending;
    }
  }
}

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
  final String? treatmentPlanID;
  // Denormalized display fields (from Manar's model)
  final String? patientName;
  final String? doctorName;
  final String? reason;
  final String? timeSlot; // e.g., "10:00 AM"
  final ConsultationStatus status;
  // Sara's telemedicine fields
  final String? channelName; // Agora channel: khotaa_{consultationID}
  final String? notes;
  final String? diagnosis;
  final String? prescription;
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
    this.timeSlot,
    this.status = ConsultationStatus.pending,
    this.channelName,
    this.notes,
    this.diagnosis,
    this.prescription,
    this.createdAt,
    this.updatedAt,
  });

  // ── Firestore serialization ──

  factory Consultation.fromMap(Map<String, dynamic> map, {String? id}) {
    final rawStatus = map['status'] as String? ?? 'pending';
    return Consultation(
      consultationID: id ?? map['consultationID'] as String? ?? '',
      startTime: map['startTime'] != null ? (map['startTime'] as Timestamp).toDate() : null,
      endTime: map['endTime'] != null ? (map['endTime'] as Timestamp).toDate() : null,
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
      timeSlot: map['timeSlot'] as String?,
      status: ConsultationStatusX.fromString(rawStatus),
      channelName: map['channelName'] as String?,
      notes: map['notes'] as String?,
      diagnosis: map['diagnosis'] as String?,
      prescription: map['prescription'] as String?,
      createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : null,
      updatedAt: map['updatedAt'] != null ? (map['updatedAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'consultationID': consultationID,
      'startTime': startTime != null ? Timestamp.fromDate(startTime!) : null,
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'duration': duration,
      'consultationDate': consultationDate != null ? Timestamp.fromDate(consultationDate!) : null,
      'patientID': patientID,
      'doctorID': doctorID,
      'treatmentPlanID': treatmentPlanID,
      'patientName': patientName,
      'doctorName': doctorName,
      'reason': reason,
      'timeSlot': timeSlot,
      'status': status.value,
      'channelName': channelName,
      'notes': notes,
      'diagnosis': diagnosis,
      'prescription': prescription,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory Consultation.fromDocument(DocumentSnapshot doc) {
    return Consultation.fromMap(doc.data() as Map<String, dynamic>, id: doc.id);
  }

  /// Derived channel name for Agora video
  String get agoraChannel => channelName ?? 'khotaa_$consultationID';

  /// Whether the session chat is open (active or followUp)
  bool get isChatOpen =>
      status == ConsultationStatus.active || status == ConsultationStatus.followUp;

  /// Whether the session is fully done
  bool get isCompleted => status == ConsultationStatus.completed;

  /// Whether the Start Consultation button should be visible
  bool get canJoin =>
      status == ConsultationStatus.accepted || status == ConsultationStatus.active;

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
    String? timeSlot,
    ConsultationStatus? status,
    String? channelName,
    String? notes,
    String? diagnosis,
    String? prescription,
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
      timeSlot: timeSlot ?? this.timeSlot,
      status: status ?? this.status,
      channelName: channelName ?? this.channelName,
      notes: notes ?? this.notes,
      diagnosis: diagnosis ?? this.diagnosis,
      prescription: prescription ?? this.prescription,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
