import 'package:flutter/material.dart';
import '../../../services/expert_system/expert_system.dart';
import '../../../services/local_notification_service.dart';
import '../../../services/alert_service.dart';
import '../../../models/smart_alert.dart' as alert_model;
import '../widgets/medical_alert_dialog.dart';
import 'sensor_data_service.dart';

/// Sensor Notification Service
/// 
/// Single source for all sensor-based alerts and notifications.
/// Handles the decision logic based on expert system results:
/// - HIGH RISK → In-app Alert (modal dialog + sound) + Save to AlertService
/// - MODERATE RISK → Push notification + Save to AlertService
/// - NORMAL → No action
///
/// Recommendations are stored in AlertService and displayed in:
/// - Preventive Recommendations Screen
/// - Alert History Screen
///
/// Based on IWGDF 2023 Guidelines.
class SensorNotificationService {
  static final SensorNotificationService _instance =
      SensorNotificationService._internal();
  factory SensorNotificationService() => _instance;
  SensorNotificationService._internal();

  final AlertService _alertService = AlertService();
  final LocalNotificationService _localNotificationService =
      LocalNotificationService();

  // Cooldown management to prevent alert fatigue
  DateTime? _lastAlertTime;
  DateTime? _lastNotificationTime;
  static const Duration _alertCooldown = Duration(minutes: 5);
  static const Duration _notificationCooldown = Duration(minutes: 10);

  // Context for showing dialogs (set from dashboard)
  BuildContext? _dialogContext;

  /// Set the context for showing alert dialogs
  void setDialogContext(BuildContext context) {
    _dialogContext = context;
  }

  /// Clear the dialog context when dashboard is disposed
  void clearDialogContext() {
    _dialogContext = null;
  }

  /// Handle expert system result and trigger appropriate action
  /// 
  /// Flow:
  /// - HIGH risk (shouldTriggerAlert) → Show modal dialog
  /// - MODERATE risk (shouldTriggerNotification) → Send push notification
  /// - NORMAL → No action
  Future<void> handleExpertResult(ExpertSystemResult result) async {
    if (!result.hasRisk) return;

    if (result.shouldTriggerAlert) {
      await _handleHighRiskAlert(result);
    } else if (result.shouldTriggerNotification) {
      await _handleModerateRiskNotification(result);
    }
  }

  /// HIGH RISK: Show in-app modal dialog with sound
  /// Also saves to AlertService for Preventive Recommendations screen
  Future<void> _handleHighRiskAlert(ExpertSystemResult result) async {
    // Check cooldown
    if (_lastAlertTime != null &&
        DateTime.now().difference(_lastAlertTime!) < _alertCooldown) {
      debugPrint('⏱ Alert cooldown active, skipping');
      return;
    }

    _lastAlertTime = DateTime.now();

    // Save to AlertService (for Preventive Recommendations screen)
    await _saveAlertToService(result, isHighRisk: true);

    // Show dialog only if context is available (app is open)
    if (_dialogContext != null && _dialogContext!.mounted) {
      await MedicalAlertDialog.show(
        _dialogContext!,
        result,
        onDismiss: () {
          debugPrint('✅ High risk alert acknowledged');
        },
        onContactDoctor: () {
          debugPrint('📞 User wants to contact doctor');
          _navigateToDoctorContact();
        },
      );
    } else {
      // App is not in foreground, send high priority notification instead
      await _sendHighPriorityNotification(result);
    }
  }

  /// MODERATE RISK: Send push notification (works in all app states)
  /// Also saves to AlertService for Preventive Recommendations screen
  Future<void> _handleModerateRiskNotification(ExpertSystemResult result) async {
    // Check cooldown
    if (_lastNotificationTime != null &&
        DateTime.now().difference(_lastNotificationTime!) <
            _notificationCooldown) {
      debugPrint('⏱ Notification cooldown active, skipping');
      return;
    }

    _lastNotificationTime = DateTime.now();

    final region = result.fullRegionName; // Includes left/right
    
    // Determine notification content based on triggered rule type
    final hasTemp = result.triggeredRules.any(
      (r) => r.type == RuleType.temperatureAsymmetry,
    );

    final String title;
    final String body;
    final String type;

    if (hasTemp) {
      title = 'Temperature Asymmetry Detected';
      body = 'Temperature difference ≥2.2°C in $region. Rest and monitor. If persistent, reduce activity.';
      type = 'abnormal_temperature';
    } else {
      title = 'Elevated Plantar Pressure';
      body = 'High pressure in $region. Take a seated break and avoid prolonged standing.';
      type = 'elevated_pressure';
    }

    // Save to AlertService (for Preventive Recommendations screen)
    await _saveAlertToService(result, isHighRisk: false);

    // Show local notification (works in foreground/background)
    await _localNotificationService.show(
      title: title,
      body: body,
      type: type,
    );

    debugPrint('📱 Moderate risk notification sent: $title');
  }

  /// Send high priority notification when app is in background/terminated
  Future<void> _sendHighPriorityNotification(ExpertSystemResult result) async {
    final region = result.fullRegionName;

    const title = '⚠️ High Risk - Immediate Action Required';
    final body = 'Combined temperature and pressure abnormality in $region. '
        'Stop weight-bearing, inspect your foot, and contact your healthcare provider.';

    await _localNotificationService.show(
      title: title,
      body: body,
      type: 'high_pressure',
    );

    debugPrint('🚨 High priority notification sent (app in background)');
  }

  /// Save alert to AlertService for Preventive Recommendations screen
  /// This is the SINGLE source for storing recommendations
  Future<void> _saveAlertToService(ExpertSystemResult result, {required bool isHighRisk}) async {
    try {
      final hasTemp = result.triggeredRules.any(
        (r) => r.type == RuleType.temperatureAsymmetry,
      );
      final hasPressure = result.triggeredRules.any(
        (r) => r.type == RuleType.elevatedPressure || r.type == RuleType.pressureAboveBaseline,
      );

      // Determine category based on triggered rules
      alert_model.RiskCategory category;
      if (hasTemp && hasPressure) {
        category = alert_model.RiskCategory.combined;
      } else if (hasTemp) {
        category = alert_model.RiskCategory.temperature;
      } else {
        category = alert_model.RiskCategory.pressure;
      }

      // Get first recommendation from expert system
      final recommendation = result.recommendedActions.isNotEmpty
          ? result.recommendedActions.first
          : null;

      // Alert titles
      String title;
      if (hasTemp && hasPressure) {
        title = 'Pressure & Temperature Alert';
      } else if (isHighRisk) {
        title = 'High Risk Alert';
      } else if (hasTemp) {
        title = 'Temperature Asymmetry';
      } else {
        title = 'Elevated Pressure';
      }

      // Get foot and region info from result
      final affectedFoot = result.affectedFoot;
      final regionName = result.affectedRegion?.displayName ?? 'Foot';
      
      // Get actual sensor values from SensorDataService (always show both)
      final sensorService = SensorDataService();
      final pressure = sensorService.pressure;
      final temperature = sensorService.temperature;
      
      await _alertService.createCustomAlert(
        title: title,
        shortDescription: result.userMessage,
        detailedExplanation: _buildExplanation(result),
        riskLevel: isHighRisk ? alert_model.RiskLevel.high : alert_model.RiskLevel.medium,
        category: category,
        recommendationTitle: recommendation?.title,
        recommendationDescription: recommendation?.description,
        instructions: recommendation?.instructions,
        sensorData: {
          'footSide': affectedFoot == 'left' ? 'Left Foot' : 'Right Foot',
          'sensorRegion': regionName,
          'pressureValue': pressure,
          'temperatureValue': temperature,
        },
      );

      debugPrint('✅ Alert saved to AlertService');
    } catch (e) {
      debugPrint('❌ Error saving alert: $e');
    }
  }

  /// Build detailed explanation from expert system result
  String _buildExplanation(ExpertSystemResult result) {
    final buf = StringBuffer('Expert system findings:\n\n');
    for (final rule in result.triggeredRules) {
      buf.writeln('• ${rule.description}');
    }
    return buf.toString();
  }

  /// Navigate to doctor contact screen
  void _navigateToDoctorContact() {
    if (_dialogContext != null && _dialogContext!.mounted) {
      Navigator.of(_dialogContext!).pushNamed('/doctors-list');
    }
  }

  /// Reset cooldowns (for testing or after significant time gap)
  void resetCooldowns() {
    _lastAlertTime = null;
    _lastNotificationTime = null;
  }

  /// Check if alert can be shown (not in cooldown)
  bool canShowAlert() {
    if (_lastAlertTime == null) return true;
    return DateTime.now().difference(_lastAlertTime!) >= _alertCooldown;
  }

  /// Check if notification can be sent (not in cooldown)
  bool canSendNotification() {
    if (_lastNotificationTime == null) return true;
    return DateTime.now().difference(_lastNotificationTime!) >=
        _notificationCooldown;
  }
}
