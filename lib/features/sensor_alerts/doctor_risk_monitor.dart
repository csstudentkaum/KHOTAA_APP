import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../services/notification_service.dart';

/// Monitors DFU readings for the doctor's patients and generates
/// risk alert notifications for abnormal temperature/pressure.
class DoctorRiskMonitor {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  StreamSubscription<QuerySnapshot>? _subscription;
  bool _initialLoadDone = false;

  // Thresholds
  static const double _pressureHighRisk = 80.0; // kPa — High risk
  static const double _pressureElevated = 60.0; // kPa — Above normal
  static const double _temperatureHigh = 35.0; // °C — High
  static const double _temperatureElevated = 33.0; // °C — Elevated

  /// Start monitoring DFU readings for all patients assigned to this doctor.
  void startMonitoring(String doctorID) {
    stopMonitoring();
    _initialLoadDone = false;
    _listenToPatientReadings(doctorID);
  }

  void _listenToPatientReadings(String doctorID) {
    _subscription = _firestore
        .collection('dfu_readings')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .listen(
          (snapshot) {
            if (!_initialLoadDone) {
              _initialLoadDone = true;
              return;
            }

            for (final change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added) {
                final data = change.doc.data();
                if (data != null) {
                  _processReading(
                    doctorID: doctorID,
                    readingID: change.doc.id,
                    data: data,
                  );
                }
              }
            }
          },
          onError: (e) {
            debugPrint('❌ DFU Monitor error: $e');
          },
        );

    debugPrint('🔍 DFU Risk Monitor started for doctor: $doctorID');
  }

  Future<void> _processReading({
    required String doctorID,
    required String readingID,
    required Map<String, dynamic> data,
  }) async {
    final patientId = data['patientId'] as String? ?? '';
    if (patientId.isEmpty) return;

    final pressure = (data['pressure'] ?? 0).toDouble();
    final temperature = (data['temperature'] ?? 0).toDouble();

    final patientDoc = await _firestore
        .collection('users')
        .doc(patientId)
        .get();
    if (!patientDoc.exists) return;

    final patientData = patientDoc.data() as Map<String, dynamic>;
    final assignedDoctor = patientData['doctorId'] as String? ?? '';

    bool isMyPatient = assignedDoctor == doctorID;

    if (!isMyPatient) {
      final consultationSnap = await _firestore
          .collection('consultations')
          .where('doctorID', isEqualTo: doctorID)
          .where('patientID', isEqualTo: patientId)
          .where('status', whereIn: ['active', 'followUp'])
          .limit(1)
          .get();
      isMyPatient = consultationSnap.docs.isNotEmpty;
    }

    if (!isMyPatient) return;

    final firstName = patientData['firstName'] ?? '';
    final lastName = patientData['lastName'] ?? '';
    final patientName = '$firstName $lastName'.trim();
    final displayName = patientName.isNotEmpty ? patientName : 'A patient';

    // ── Pressure Alerts ──
    if (pressure >= _pressureHighRisk) {
      await _notificationService.notifyDoctorHighPressure(
        doctorID: doctorID,
        patientName: displayName,
        patientID: patientId,
        pressureValue: pressure,
        readingID: readingID,
      );
      await _notificationService.notifyPatientRiskAlert(
        patientID: patientId,
        title: '⚠️ High Pressure Detected',
        body:
            'Your foot pressure is ${pressure.toStringAsFixed(0)} kPa (High Risk). Please contact your doctor.',
        type: 'high_pressure',
        readingID: readingID,
      );
      debugPrint(
        '🚨 High pressure alert for $displayName: ${pressure.toStringAsFixed(0)} kPa',
      );
    } else if (pressure >= _pressureElevated) {
      await _notificationService.notifyDoctorElevatedPressure(
        doctorID: doctorID,
        patientName: displayName,
        patientID: patientId,
        pressureValue: pressure,
        readingID: readingID,
      );
      debugPrint(
        '⚠️ Elevated pressure warning for $displayName: ${pressure.toStringAsFixed(0)} kPa',
      );
    }

    // ── Temperature Alerts ──
    if (temperature >= _temperatureHigh) {
      await _notificationService.notifyDoctorAbnormalTemperature(
        doctorID: doctorID,
        patientName: displayName,
        patientID: patientId,
        temperatureValue: temperature,
        readingID: readingID,
      );
      await _notificationService.notifyPatientRiskAlert(
        patientID: patientId,
        title: '🌡️ High Temperature Detected',
        body:
            'Your foot temperature is ${temperature.toStringAsFixed(1)} °C (High). Please contact your doctor.',
        type: 'abnormal_temperature',
        readingID: readingID,
      );
      debugPrint(
        '🚨 High temperature alert for $displayName: ${temperature.toStringAsFixed(1)} °C',
      );
    } else if (temperature >= _temperatureElevated) {
      await _notificationService.notifyDoctorElevatedTemperature(
        doctorID: doctorID,
        patientName: displayName,
        patientID: patientId,
        temperatureValue: temperature,
        readingID: readingID,
      );
      debugPrint(
        '⚠️ Elevated temperature warning for $displayName: ${temperature.toStringAsFixed(1)} °C',
      );
    }
  }

  /// Stop monitoring
  void stopMonitoring() {
    _subscription?.cancel();
    _subscription = null;
    debugPrint('🛑 DFU Risk Monitor stopped');
  }
}
