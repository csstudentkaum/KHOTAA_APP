import 'package:cloud_firestore/cloud_firestore.dart';

/// WeeklyReport model
/// Relationships:
///   - Patient (1) has (0..*) WeeklyReport
///   - WeeklyReport receives/basedOn (0..*) Alerts
///   - PreventiveRecommendation receives/basedOn WeeklyReport
class WeeklyReport {
  final String reportID;
  final DateTime weekStart;
  final DateTime weekEnd;
  final String summary;
  final int numAlerts;
  final String patientID; // FK to Patient

  WeeklyReport({
    required this.reportID,
    required this.weekStart,
    required this.weekEnd,
    required this.summary,
    required this.numAlerts,
    required this.patientID,
  });

  // ── Firestore serialization ──

  /// Create a WeeklyReport from a Firestore document snapshot.
  factory WeeklyReport.fromMap(Map<String, dynamic> map, {String? id}) {
    return WeeklyReport(
      reportID: id ?? map['reportID'] as String,
      weekStart: (map['weekStart'] as Timestamp).toDate(),
      weekEnd: (map['weekEnd'] as Timestamp).toDate(),
      summary: map['summary'] as String? ?? '',
      numAlerts: map['numAlerts'] as int? ?? 0,
      patientID: map['patientID'] as String? ?? '',
    );
  }

  /// Convert the WeeklyReport to a Map for Firestore storage.
  Map<String, dynamic> toMap() {
    return {
      'reportID': reportID,
      'weekStart': Timestamp.fromDate(weekStart),
      'weekEnd': Timestamp.fromDate(weekEnd),
      'summary': summary,
      'numAlerts': numAlerts,
      'patientID': patientID,
    };
  }

  /// Convenience factory from a Firestore DocumentSnapshot.
  factory WeeklyReport.fromDocument(DocumentSnapshot doc) {
    return WeeklyReport.fromMap(doc.data() as Map<String, dynamic>, id: doc.id);
  }

  // ── Methods from UML ──

  /// Generate a new WeeklyReport (placeholder – logic depends on your service layer).
  static Future<WeeklyReport> generate({
    required String patientID,
    required DateTime weekStart,
    required DateTime weekEnd,
    required String summary,
    required int numAlerts,
  }) async {
    final report = WeeklyReport(
      reportID: FirebaseFirestore.instance
          .collection('patients')
          .doc(patientID)
          .collection('weeklyReports')
          .doc()
          .id,
      weekStart: weekStart,
      weekEnd: weekEnd,
      summary: summary,
      numAlerts: numAlerts,
      patientID: patientID,
    );
    return report;
  }

  /// Return the summary text.
  String getSummary() => summary;

  /// Mark the report as viewed (to be handled at the service layer).
  /// Returns a new copy with any view‑tracking field you add later.
  void markAsViewed() {
    // Implementation depends on your view‑tracking strategy.
  }

  @override
  String toString() {
    return 'WeeklyReport(reportID: $reportID, weekStart: $weekStart, '
        'weekEnd: $weekEnd, summary: $summary, numAlerts: $numAlerts, '
        'patientID: $patientID)';
  }

  /// Creates a copy with the given fields replaced.
  WeeklyReport copyWith({
    String? reportID,
    DateTime? weekStart,
    DateTime? weekEnd,
    String? summary,
    int? numAlerts,
    String? patientID,
  }) {
    return WeeklyReport(
      reportID: reportID ?? this.reportID,
      weekStart: weekStart ?? this.weekStart,
      weekEnd: weekEnd ?? this.weekEnd,
      summary: summary ?? this.summary,
      numAlerts: numAlerts ?? this.numAlerts,
      patientID: patientID ?? this.patientID,
    );
  }
}
