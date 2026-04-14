import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../services/expert_system/expert_system.dart';
import '../../services/local_notification_service.dart';
import '../patient/booking/all_doctors_screen.dart';
import '../patient/services/sensor_data_service.dart';
import 'alert_service.dart';
import '../../models/alert.dart' as alert_model;

/// Sensor Alert Handler
///
/// Single source for all sensor-based temperature/pressure alerts.
/// Handles the 3 notification cases based on expert system results:
///
/// 1. HIGH RISK (app open)     → Modal dialog + sound + save alert
/// 2. MODERATE RISK            → Push notification + save alert
/// 3. HIGH RISK (app background) → High-priority push notification + save alert
///
/// Based on IWGDF 2023 Guidelines.
class SensorAlertHandler {
  static final SensorAlertHandler _instance = SensorAlertHandler._internal();
  factory SensorAlertHandler() => _instance;
  SensorAlertHandler._internal();

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

  /// CASE 1: HIGH RISK + app open → Show in-app modal dialog with sound
  Future<void> _handleHighRiskAlert(ExpertSystemResult result) async {
    if (_lastAlertTime != null &&
        DateTime.now().difference(_lastAlertTime!) < _alertCooldown) {
      debugPrint('⏱ Alert cooldown active, skipping');
      return;
    }

    _lastAlertTime = DateTime.now();
    await _saveAlertToService(result, isHighRisk: true);

    if (_dialogContext != null && _dialogContext!.mounted) {
      await _MedicalAlertDialog.show(
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
      // CASE 3: HIGH RISK + app in background → high-priority push
      await _sendHighPriorityNotification(result);
    }
  }

  /// CASE 2: MODERATE RISK → Push notification
  Future<void> _handleModerateRiskNotification(ExpertSystemResult result) async {
    if (_lastNotificationTime != null &&
        DateTime.now().difference(_lastNotificationTime!) <
            _notificationCooldown) {
      debugPrint('⏱ Notification cooldown active, skipping');
      return;
    }

    _lastNotificationTime = DateTime.now();

    final region = result.fullRegionName;
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

    await _saveAlertToService(result, isHighRisk: false);

    await _localNotificationService.show(
      title: title,
      body: body,
      type: type,
    );

    debugPrint('📱 Moderate risk notification sent: $title');
  }

  /// CASE 3: HIGH RISK + app in background → high-priority push notification
  Future<void> _sendHighPriorityNotification(ExpertSystemResult result) async {
    final region = result.fullRegionName;

    await _localNotificationService.show(
      title: '⚠️ High Risk - Immediate Action Required',
      body: 'Combined temperature and pressure abnormality in $region. '
          'Stop weight-bearing, inspect your foot, and contact your healthcare provider.',
      type: 'combined_risk',
    );

    debugPrint('🚨 High priority notification sent (app in background): combined_risk');
  }

  /// Save alert to AlertService for history & recommendations screens
  Future<void> _saveAlertToService(ExpertSystemResult result, {required bool isHighRisk}) async {
    try {
      final hasTemp = result.triggeredRules.any(
        (r) => r.type == RuleType.temperatureAsymmetry,
      );
      final hasPressure = result.triggeredRules.any(
        (r) => r.type == RuleType.elevatedPressure || r.type == RuleType.pressureAboveBaseline,
      );

      alert_model.RiskCategory category;
      if (hasTemp && hasPressure) {
        category = alert_model.RiskCategory.combined;
      } else if (hasTemp) {
        category = alert_model.RiskCategory.temperature;
      } else {
        category = alert_model.RiskCategory.pressure;
      }

      final recommendation = result.recommendedActions.isNotEmpty
          ? result.recommendedActions.first
          : null;

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

      final affectedFoot = result.affectedFoot;
      final regionName = result.affectedRegion?.displayName ?? 'Foot';

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

  String _buildExplanation(ExpertSystemResult result) {
    final buf = StringBuffer('Expert system findings:\n\n');
    for (final rule in result.triggeredRules) {
      buf.writeln('• ${rule.description}');
    }
    return buf.toString();
  }

  void _navigateToDoctorContact() {
    if (_dialogContext != null && _dialogContext!.mounted) {
      Navigator.of(_dialogContext!).pushNamed('/doctors-list');
    }
  }

  /// Reset cooldowns (for testing)
  void resetCooldowns() {
    _lastAlertTime = null;
    _lastNotificationTime = null;
  }

  bool canShowAlert() {
    if (_lastAlertTime == null) return true;
    return DateTime.now().difference(_lastAlertTime!) >= _alertCooldown;
  }

  bool canSendNotification() {
    if (_lastNotificationTime == null) return true;
    return DateTime.now().difference(_lastNotificationTime!) >=
        _notificationCooldown;
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Medical Alert Dialog (HIGH RISK - shown when app is open)
// ────────────────────────────────────────────────────────────────────────────

class _MedicalAlertDialog extends StatefulWidget {
  final ExpertSystemResult result;
  final VoidCallback? onDismiss;
  final VoidCallback? onContactDoctor;

  const _MedicalAlertDialog({
    required this.result,
    this.onDismiss,
    this.onContactDoctor,
  });

  static Future<void> show(
    BuildContext context,
    ExpertSystemResult result, {
    VoidCallback? onDismiss,
    VoidCallback? onContactDoctor,
  }) async {
    try {
      final player = AudioPlayer();
      await player.play(AssetSource('sounds/alert_sound.wav'));
      player.onPlayerComplete.listen((_) => player.dispose());
    } catch (e) {
      debugPrint('⚠️ Could not play alert sound: $e');
    }

    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (ctx) => _MedicalAlertDialog(
        result: result,
        onDismiss: () {
          Navigator.of(ctx).pop();
          onDismiss?.call();
        },
        onContactDoctor: onContactDoctor,
      ),
    );
  }

  @override
  State<_MedicalAlertDialog> createState() => _MedicalAlertDialogState();
}

class _MedicalAlertDialogState extends State<_MedicalAlertDialog> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        constraints: BoxConstraints(
          maxWidth: 340,
          maxHeight: _showDetails ? 560 : 380,
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Stack(
              children: [
                SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 16),
                      _buildCompactAlert(),
                      if (_showDetails) _buildDetails(),
                      _buildActions(),
                    ],
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onDismiss,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.grey[600],
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactAlert() {
    final region = widget.result.affectedRegion?.displayName ?? 'Foot';

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFFFEBEE),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_rounded,
              color: Color(0xFFE53935),
              size: 42,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Health Alert',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Abnormal readings detected in $region.\nPlease take action.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          if (!_showDetails)
            TextButton.icon(
              onPressed: () => setState(() => _showDetails = true),
              icon: const Icon(Icons.expand_more, size: 24),
              label: const Text('View Details', style: TextStyle(fontSize: 15)),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF64ADB3),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetails() {
    final result = widget.result;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _showDetails = false),
              icon: const Icon(Icons.expand_less, size: 20),
              label: const Text('Hide Details'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[500],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline,
                      color: Colors.orange[700], size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'What was detected',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.orange[700],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...result.triggeredRules.map((rule) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ', style: TextStyle(
                        color: Colors.orange[700],
                        fontWeight: FontWeight.bold,
                      )),
                      Expanded(
                        child: Text(
                          rule.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (result.recommendedActions.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline,
                        color: Colors.green[700], size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'What to do',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.green[700],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result.recommendedActions.first.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    result.recommendedActions.first.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AllDoctorsScreen()),
                );
              },
              icon: const Icon(Icons.medical_services_rounded, size: 26),
              label: const Text(
                'Contact a Doctor',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 3,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: widget.onDismiss,
            child: Text(
              'Dismiss',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[500],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
