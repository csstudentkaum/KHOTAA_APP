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
  final String
  status; // 'pending', 'accepted', 'active', 'followUp', 'completed', 'rejected'
  final String? timeSlot; // e.g., "10:00 AM"
  // Telemedicine fields
  final String? channelName; // Agora channel: khotaa_{consultationID}
  final String? notes;
  final String? diagnosis;
  final String? prescription;
  // Follow-up fields
  final DateTime? followUpDueDate;
  final List<Map<String, dynamic>> followUpTasks;
  final String? followUpInstructions;
  final Map<String, dynamic>? followUpCheckIn; // patient responses
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool rated; // Whether the patient has rated this consultation

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
    this.channelName,
    this.notes,
    this.diagnosis,
    this.prescription,
    this.followUpDueDate,
    this.followUpTasks = const [],
    this.followUpInstructions,
    this.followUpCheckIn,
    this.createdAt,
    this.updatedAt,
    this.rated = false,
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
      duration: (map['duration'] as num?)?.toInt() ?? 0,
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
      channelName: map['channelName'] as String?,
      notes: map['notes'] as String?,
      diagnosis: map['diagnosis'] as String?,
      prescription: map['prescription'] as String?,
      followUpDueDate: map['followUpDueDate'] != null
          ? (map['followUpDueDate'] as Timestamp).toDate()
          : null,
      followUpTasks:
          (map['followUpTasks'] as List<dynamic>?)
              ?.map((t) => Map<String, dynamic>.from(t as Map))
              .toList() ??
          [],
      followUpInstructions: map['followUpInstructions'] as String?,
      followUpCheckIn: map['followUpCheckIn'] != null
          ? Map<String, dynamic>.from(map['followUpCheckIn'] as Map)
          : null,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
      rated: map['rated'] as bool? ?? false,
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
      'channelName': channelName,
      'notes': notes,
      'diagnosis': diagnosis,
      'prescription': prescription,
      'followUpDueDate': followUpDueDate != null
          ? Timestamp.fromDate(followUpDueDate!)
          : null,
      'followUpTasks': followUpTasks,
      'followUpInstructions': followUpInstructions,
      'followUpCheckIn': followUpCheckIn,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'rated': rated,
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
        (status == 'pending' || status == 'accepted' || status == 'active');
  }

  /// Check if consultation is in follow-up period
  bool get isFollowUp => status == 'followUp';

  /// Check if consultation is past (before today, or completed/rejected)
  bool get isPast {
    final date = consultationDate;
    if (date == null) return true;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final consultDay = DateTime(date.year, date.month, date.day);
    return (consultDay.isBefore(today) &&
            status != 'followUp' &&
            status != 'pending' &&
            status != 'accepted' &&
            status != 'active') ||
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

  /// Derived channel name for Agora video
  String get agoraChannel => channelName ?? 'khotaa_$consultationID';

  /// Whether the session chat is open (active or followUp)
  bool get isChatOpen => status == 'active' || status == 'followUp';

  /// Whether follow-up check-in is due for the patient
  bool get isCheckInDue {
    if (status != 'followUp' || followUpDueDate == null) return false;
    final now = DateTime.now();
    // Check-in becomes available 1 day before due date
    return now.isAfter(followUpDueDate!.subtract(const Duration(days: 1)));
  }

  /// Whether patient has submitted their check-in
  bool get hasCheckIn => followUpCheckIn != null && followUpCheckIn!.isNotEmpty;

  /// Whether the follow-up duration has expired (due date has passed)
  bool get isFollowUpExpired {
    if (status != 'followUp' || followUpDueDate == null) return false;
    final now = DateTime.now();
    // Expired when we're past the end of the due date day
    final endOfDueDay = DateTime(
      followUpDueDate!.year,
      followUpDueDate!.month,
      followUpDueDate!.day,
      23,
      59,
      59,
    );
    return now.isAfter(endOfDueDay);
  }

  /// Whether the session is fully done
  bool get isCompleted => status == 'completed';

  /// Whether the Start Consultation button should be visible
  bool get canJoin => status == 'accepted' || status == 'active';

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
    String? channelName,
    String? notes,
    String? diagnosis,
    String? prescription,
    DateTime? followUpDueDate,
    List<Map<String, dynamic>>? followUpTasks,
    String? followUpInstructions,
    Map<String, dynamic>? followUpCheckIn,
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
      channelName: channelName ?? this.channelName,
      followUpDueDate: followUpDueDate ?? this.followUpDueDate,
      followUpTasks: followUpTasks ?? this.followUpTasks,
      followUpInstructions: followUpInstructions ?? this.followUpInstructions,
      followUpCheckIn: followUpCheckIn ?? this.followUpCheckIn,
      notes: notes ?? this.notes,
      diagnosis: diagnosis ?? this.diagnosis,
      prescription: prescription ?? this.prescription,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
