import 'package:cloud_firestore/cloud_firestore.dart';

/// PreventiveRecommendation model
/// Relationships:
///   - Patient (1) receives (0..*) PreventiveRecommendation
///   - PreventiveRecommendation receives/basedOn WeeklyReport
class PreventiveRecommendation {
  final String recID;
  final DateTime createdAt;
  final bool viewed;
  final String description;
  final String patientID; // FK to Patient
  final String? weeklyReportID; // FK to WeeklyReport (basedOn relationship)

  PreventiveRecommendation({
    required this.recID,
    required this.createdAt,
    required this.viewed,
    required this.description,
    required this.patientID,
    this.weeklyReportID,
  });

  // ── Firestore serialization ──

  /// Create a PreventiveRecommendation from a Firestore document map.
  factory PreventiveRecommendation.fromMap(Map<String, dynamic> map,
      {String? id}) {
    return PreventiveRecommendation(
      recID: id ?? map['recID'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      viewed: map['viewed'] as bool? ?? false,
      description: map['description'] as String? ?? '',
      patientID: map['patientID'] as String? ?? '',
      weeklyReportID: map['weeklyReportID'] as String?,
    );
  }

  /// Convert the PreventiveRecommendation to a Map for Firestore storage.
  Map<String, dynamic> toMap() {
    return {
      'recID': recID,
      'createdAt': Timestamp.fromDate(createdAt),
      'viewed': viewed,
      'description': description,
      'patientID': patientID,
      'weeklyReportID': weeklyReportID,
    };
  }

  /// Convenience factory from a Firestore DocumentSnapshot.
  factory PreventiveRecommendation.fromDocument(DocumentSnapshot doc) {
    return PreventiveRecommendation.fromMap(
      doc.data() as Map<String, dynamic>,
      id: doc.id,
    );
  }

  // ── Methods from UML ──

  /// Create a new recommendation (returns an instance with a generated ID).
  static PreventiveRecommendation createRecommendation({
    required String patientID,
    required String description,
    String? weeklyReportID,
  }) {
    return PreventiveRecommendation(
      recID: FirebaseFirestore.instance
          .collection('patients')
          .doc(patientID)
          .collection('preventiveRecommendations')
          .doc()
          .id,
      createdAt: DateTime.now(),
      viewed: false,
      description: description,
      patientID: patientID,
      weeklyReportID: weeklyReportID,
    );
  }

  /// Mark the recommendation as viewed.
  PreventiveRecommendation markAsViewed() {
    return copyWith(viewed: true);
  }

  /// Get details of the recommendation.
  String getDetails() => description;

  @override
  String toString() {
    return 'PreventiveRecommendation(recID: $recID, createdAt: $createdAt, '
        'viewed: $viewed, description: $description, patientID: $patientID, '
        'weeklyReportID: $weeklyReportID)';
  }

  /// Creates a copy with the given fields replaced.
  PreventiveRecommendation copyWith({
    String? recID,
    DateTime? createdAt,
    bool? viewed,
    String? description,
    String? patientID,
    String? weeklyReportID,
  }) {
    return PreventiveRecommendation(
      recID: recID ?? this.recID,
      createdAt: createdAt ?? this.createdAt,
      viewed: viewed ?? this.viewed,
      description: description ?? this.description,
      patientID: patientID ?? this.patientID,
      weeklyReportID: weeklyReportID ?? this.weeklyReportID,
    );
  }
}
