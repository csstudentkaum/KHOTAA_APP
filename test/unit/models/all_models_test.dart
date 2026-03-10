import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khotaa_app/models/weekly_report.dart';
import 'package:khotaa_app/models/preventive_recommendation.dart';
import 'package:khotaa_app/models/consultation.dart';
import 'package:khotaa_app/models/treatment_plan.dart';

void main() {
  // ═══════════════════════════════════════════════════════
  // WeeklyReport Tests
  // ═══════════════════════════════════════════════════════
  group('WeeklyReport', () {
    late WeeklyReport report;
    final weekStart = DateTime(2026, 2, 10);
    final weekEnd = DateTime(2026, 2, 16);

    setUp(() {
      report = WeeklyReport(
        reportID: 'report_001',
        weekStart: weekStart,
        weekEnd: weekEnd,
        summary: 'Normal readings throughout the week',
        numAlerts: 3,
        patientID: 'patient_001',
      );
    });

    test('constructor creates instance with correct attributes', () {
      expect(report.reportID, 'report_001');
      expect(report.weekStart, weekStart);
      expect(report.weekEnd, weekEnd);
      expect(report.summary, 'Normal readings throughout the week');
      expect(report.numAlerts, 3);
      expect(report.patientID, 'patient_001');
    });

    test('toMap converts all fields to Firestore map', () {
      final map = report.toMap();
      expect(map['reportID'], 'report_001');
      expect(map['weekStart'], isA<Timestamp>());
      expect(map['weekEnd'], isA<Timestamp>());
      expect(map['summary'], 'Normal readings throughout the week');
      expect(map['numAlerts'], 3);
      expect(map['patientID'], 'patient_001');
    });

    test('fromMap creates instance from Firestore map', () {
      final map = {
        'reportID': 'report_002',
        'weekStart': Timestamp.fromDate(weekStart),
        'weekEnd': Timestamp.fromDate(weekEnd),
        'summary': 'High pressure detected',
        'numAlerts': 5,
        'patientID': 'patient_002',
      };
      final r = WeeklyReport.fromMap(map);
      expect(r.reportID, 'report_002');
      expect(r.weekStart, weekStart);
      expect(r.weekEnd, weekEnd);
      expect(r.summary, 'High pressure detected');
      expect(r.numAlerts, 5);
      expect(r.patientID, 'patient_002');
    });

    test('fromMap uses id parameter when provided', () {
      final map = {
        'reportID': 'old_id',
        'weekStart': Timestamp.fromDate(weekStart),
        'weekEnd': Timestamp.fromDate(weekEnd),
      };
      final r = WeeklyReport.fromMap(map, id: 'new_id');
      expect(r.reportID, 'new_id');
    });

    test('toMap → fromMap roundtrip preserves data', () {
      final restored = WeeklyReport.fromMap(report.toMap());
      expect(restored.reportID, report.reportID);
      expect(restored.summary, report.summary);
      expect(restored.numAlerts, report.numAlerts);
      expect(restored.patientID, report.patientID);
    });

    test('getSummary returns summary', () {
      expect(report.getSummary(), 'Normal readings throughout the week');
    });

    test('copyWith replaces specified fields only', () {
      final updated = report.copyWith(summary: 'New', numAlerts: 10);
      expect(updated.summary, 'New');
      expect(updated.numAlerts, 10);
      expect(updated.reportID, report.reportID);
      expect(updated.patientID, report.patientID);
    });

    test('toString contains class name', () {
      expect(report.toString(), contains('WeeklyReport'));
    });
  });

  // ═══════════════════════════════════════════════════════
  // PreventiveRecommendation Tests
  // ═══════════════════════════════════════════════════════
  group('PreventiveRecommendation', () {
    late PreventiveRecommendation rec;
    final createdAt = DateTime(2026, 2, 15, 10, 30);

    setUp(() {
      rec = PreventiveRecommendation(
        recID: 'rec_001',
        createdAt: createdAt,
        viewed: false,
        description: 'Reduce pressure on left foot',
        patientID: 'patient_001',
        weeklyReportID: 'report_001',
      );
    });

    test('constructor creates instance with correct attributes', () {
      expect(rec.recID, 'rec_001');
      expect(rec.createdAt, createdAt);
      expect(rec.viewed, false);
      expect(rec.description, 'Reduce pressure on left foot');
      expect(rec.patientID, 'patient_001');
      expect(rec.weeklyReportID, 'report_001');
    });

    test('weeklyReportID can be null', () {
      final r = PreventiveRecommendation(
        recID: 'rec_002',
        createdAt: createdAt,
        viewed: false,
        description: 'General advice',
        patientID: 'patient_001',
      );
      expect(r.weeklyReportID, isNull);
    });

    test('toMap converts all fields correctly', () {
      final map = rec.toMap();
      expect(map['recID'], 'rec_001');
      expect(map['createdAt'], isA<Timestamp>());
      expect(map['viewed'], false);
      expect(map['description'], 'Reduce pressure on left foot');
      expect(map['patientID'], 'patient_001');
      expect(map['weeklyReportID'], 'report_001');
    });

    test('fromMap creates instance from Firestore map', () {
      final map = {
        'recID': 'rec_003',
        'createdAt': Timestamp.fromDate(createdAt),
        'viewed': true,
        'description': 'Wear orthopedic shoes',
        'patientID': 'patient_002',
        'weeklyReportID': 'report_002',
      };
      final r = PreventiveRecommendation.fromMap(map);
      expect(r.recID, 'rec_003');
      expect(r.viewed, true);
      expect(r.description, 'Wear orthopedic shoes');
    });

    test('toMap → fromMap roundtrip preserves data', () {
      final restored = PreventiveRecommendation.fromMap(rec.toMap());
      expect(restored.recID, rec.recID);
      expect(restored.viewed, rec.viewed);
      expect(restored.description, rec.description);
      expect(restored.weeklyReportID, rec.weeklyReportID);
    });

    test('markAsViewed returns new instance with viewed=true', () {
      final viewed = rec.markAsViewed();
      expect(viewed.viewed, true);
      expect(rec.viewed, false); // original unchanged
      expect(viewed.recID, rec.recID);
    });

    test('getDetails returns description', () {
      expect(rec.getDetails(), 'Reduce pressure on left foot');
    });

    test('copyWith replaces specified fields only', () {
      final updated = rec.copyWith(description: 'Updated', viewed: true);
      expect(updated.description, 'Updated');
      expect(updated.viewed, true);
      expect(updated.recID, rec.recID);
    });

    test('toString contains class name', () {
      expect(rec.toString(), contains('PreventiveRecommendation'));
    });
  });

  // ═══════════════════════════════════════════════════════
  // Consultation Tests
  // ═══════════════════════════════════════════════════════
  group('Consultation', () {
    late Consultation consultation;
    final startTime = DateTime(2026, 2, 15, 9, 0);
    final endTime = DateTime(2026, 2, 15, 9, 30);
    final consultationDate = DateTime(2026, 2, 15);

    setUp(() {
      consultation = Consultation(
        consultationID: 'cons_001',
        startTime: startTime,
        endTime: endTime,
        duration: 30,
        consultationDate: consultationDate,
        patientID: 'patient_001',
        doctorID: 'doctor_001',
        treatmentPlanID: 'tp_001',
      );
    });

    test('constructor creates instance with correct attributes', () {
      expect(consultation.consultationID, 'cons_001');
      expect(consultation.startTime, startTime);
      expect(consultation.endTime, endTime);
      expect(consultation.duration, 30);
      expect(consultation.consultationDate, consultationDate);
      expect(consultation.patientID, 'patient_001');
      expect(consultation.doctorID, 'doctor_001');
      expect(consultation.treatmentPlanID, 'tp_001');
    });

    test('treatmentPlanID can be null', () {
      final c = Consultation(
        consultationID: 'cons_002',
        startTime: startTime,
        endTime: endTime,
        duration: 30,
        consultationDate: consultationDate,
        patientID: 'patient_001',
        doctorID: 'doctor_001',
      );
      expect(c.treatmentPlanID, isNull);
    });

    test('toMap converts all fields correctly', () {
      final map = consultation.toMap();
      expect(map['consultationID'], 'cons_001');
      expect(map['startTime'], isA<Timestamp>());
      expect(map['endTime'], isA<Timestamp>());
      expect(map['duration'], 30);
      expect(map['consultationDate'], isA<Timestamp>());
      expect(map['patientID'], 'patient_001');
      expect(map['doctorID'], 'doctor_001');
      expect(map['treatmentPlanID'], 'tp_001');
    });

    test('fromMap creates instance from Firestore map', () {
      final map = {
        'consultationID': 'cons_003',
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        'duration': 45,
        'consultationDate': Timestamp.fromDate(consultationDate),
        'patientID': 'patient_003',
        'doctorID': 'doctor_003',
        'treatmentPlanID': 'tp_003',
      };
      final c = Consultation.fromMap(map);
      expect(c.consultationID, 'cons_003');
      expect(c.duration, 45);
      expect(c.doctorID, 'doctor_003');
    });

    test('toMap → fromMap roundtrip preserves data', () {
      final restored = Consultation.fromMap(consultation.toMap());
      expect(restored.consultationID, consultation.consultationID);
      expect(restored.duration, consultation.duration);
      expect(restored.patientID, consultation.patientID);
      expect(restored.doctorID, consultation.doctorID);
      expect(restored.treatmentPlanID, consultation.treatmentPlanID);
    });

    test('getDuration calculates minutes between start and end', () {
      expect(consultation.getDuration(), 30.0);
    });

    test('copyWith replaces specified fields only', () {
      final updated = consultation.copyWith(duration: 60, doctorID: 'doc_new');
      expect(updated.duration, 60);
      expect(updated.doctorID, 'doc_new');
      expect(updated.consultationID, consultation.consultationID);
      expect(updated.patientID, consultation.patientID);
    });

    test('toString contains class name', () {
      expect(consultation.toString(), contains('Consultation'));
    });

    test('relationship: doctorID and patientID link correctly', () {
      expect(consultation.doctorID, 'doctor_001');
      expect(consultation.patientID, 'patient_001');
    });

    test('relationship: treatmentPlanID links to TreatmentPlan', () {
      expect(consultation.treatmentPlanID, 'tp_001');
    });
  });

  // ═══════════════════════════════════════════════════════
  // TreatmentPlan Tests
  // ═══════════════════════════════════════════════════════
  group('TreatmentPlan', () {
    late TreatmentPlan plan;
    final createdAt = DateTime(2026, 2, 15, 12, 0);

    setUp(() {
      plan = TreatmentPlan(
        treatmentPlanID: 'tp_001',
        consultationID: 'cons_001',
        doctorId: 'doc_001',
        patientId: 'pat_001',
        patientName: 'Test Patient',
        diagnosis: 'Type 2 Diabetes',
        medications: [
          {'name': 'Metformin', 'dosage': '500mg', 'frequency': '2x daily', 'duration': '3 months'},
        ],
        notes: 'Follow up in 3 months',
        status: 'active',
        createdAt: createdAt,
      );
    });

    test('constructor creates instance with correct attributes', () {
      expect(plan.treatmentPlanID, 'tp_001');
      expect(plan.medicationName, 'Metformin');
      expect(plan.dosage, '500mg');
      expect(plan.consultationID, 'cons_001');
      expect(plan.diagnosis, 'Type 2 Diabetes');
    });

    test('toMap converts all fields correctly', () {
      final map = plan.toMap();
      expect(map['treatmentPlanID'], 'tp_001');
      expect(map['consultationID'], 'cons_001');
      expect(map['diagnosis'], 'Type 2 Diabetes');
      expect(map['medications'], isA<List>());
      expect(map['createdAt'], isA<Timestamp>());
    });

    test('fromMap creates instance from Firestore map', () {
      final map = {
        'treatmentPlanID': 'tp_002',
        'consultationID': 'cons_002',
        'diagnosis': 'Foot Ulcer',
        'medications': [
          {'name': 'Insulin', 'dosage': '10 units', 'frequency': '1x daily', 'duration': '6 months'},
        ],
        'createdAt': Timestamp.fromDate(createdAt),
      };
      final tp = TreatmentPlan.fromMap(map);
      expect(tp.treatmentPlanID, 'tp_002');
      expect(tp.medicationName, 'Insulin');
    });

    test('fromMap uses id parameter when provided', () {
      final map = {
        'treatmentPlanID': 'old_id',
        'createdAt': Timestamp.fromDate(createdAt),
      };
      final tp = TreatmentPlan.fromMap(map, id: 'new_id');
      expect(tp.treatmentPlanID, 'new_id');
    });

    test('toMap → fromMap roundtrip preserves data', () {
      final restored = TreatmentPlan.fromMap(plan.toMap());
      expect(restored.treatmentPlanID, plan.treatmentPlanID);
      expect(restored.medicationName, plan.medicationName);
      expect(restored.dosage, plan.dosage);
      expect(restored.consultationID, plan.consultationID);
    });

    test('getPlanSummary returns formatted summary', () {
      final summary = plan.getPlanSummary();
      expect(summary, contains('Metformin'));
      expect(summary, contains('Type 2 Diabetes'));
    });

    test('toString contains class name', () {
      expect(plan.toString(), contains('TreatmentPlan'));
    });

    test('relationship: consultationID links to Consultation', () {
      expect(plan.consultationID, 'cons_001');
    });
  });
}
