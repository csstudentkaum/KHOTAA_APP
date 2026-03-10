/// KHOTAA Expert System - Rule-Based Diabetic Foot Ulcer Risk Detection
///
/// Based on IWGDF guidelines and Niemann et al. dataset with 8 sensor regions.
/// Designed to prevent alert fatigue - only notifies for clinically significant risk.

import 'package:flutter/material.dart';
import '../alert_service.dart';
import '../../models/smart_alert.dart' as alert_model;

// ═══════════════════════════════════════════════════════════════════════════════
// ENUMS
// ═══════════════════════════════════════════════════════════════════════════════

/// 8 anatomical sensor regions from Niemann et al. dataset
enum SensorRegion {
  metatarsal1, // MTK1 - First metatarsal head
  metatarsal2, // MTK2 - Second metatarsal head
  metatarsal3, // MTK3 - Third metatarsal head
  metatarsal4, // MTK4 - Fourth metatarsal head
  metatarsal5, // MTK5 - Fifth metatarsal head
  hallux,      // D1 - Big toe
  lateralMidfoot, // L - Lateral midfoot
  heel,        // C - Heel (Calcaneus)
}

extension SensorRegionExtension on SensorRegion {
  String get displayName => switch (this) {
    SensorRegion.metatarsal1 => 'Metatarsal 1 (MTK1)',
    SensorRegion.metatarsal2 => 'Metatarsal 2 (MTK2)',
    SensorRegion.metatarsal3 => 'Metatarsal 3 (MTK3)',
    SensorRegion.metatarsal4 => 'Metatarsal 4 (MTK4)',
    SensorRegion.metatarsal5 => 'Metatarsal 5 (MTK5)',
    SensorRegion.hallux => 'Hallux (D1)',
    SensorRegion.lateralMidfoot => 'Lateral Midfoot (L)',
    SensorRegion.heel => 'Heel (C)',
  };

  String get code => switch (this) {
    SensorRegion.metatarsal1 => 'MTK1',
    SensorRegion.metatarsal2 => 'MTK2',
    SensorRegion.metatarsal3 => 'MTK3',
    SensorRegion.metatarsal4 => 'MTK4',
    SensorRegion.metatarsal5 => 'MTK5',
    SensorRegion.hallux => 'D1',
    SensorRegion.lateralMidfoot => 'L',
    SensorRegion.heel => 'C',
  };

  bool get isForefootRegion => this == SensorRegion.metatarsal1 ||
      this == SensorRegion.metatarsal2 ||
      this == SensorRegion.metatarsal3 ||
      this == SensorRegion.metatarsal4 ||
      this == SensorRegion.metatarsal5 ||
      this == SensorRegion.hallux;
}

enum RiskLevel { normal, moderate, high }

enum RuleType {
  temperatureAsymmetry,
  elevatedPressure,
  pressureAboveBaseline,
  combinedRisk,
}

// ═══════════════════════════════════════════════════════════════════════════════
// DATA MODELS
// ═══════════════════════════════════════════════════════════════════════════════

class SensorInput {
  final double leftFootTemperature;
  final double rightFootTemperature;
  final double plantarPressure;
  final double pressureBaseline;
  final SensorRegion sensorRegion;
  final String footSide;

  const SensorInput({
    required this.leftFootTemperature,
    required this.rightFootTemperature,
    required this.plantarPressure,
    required this.pressureBaseline,
    required this.sensorRegion,
    this.footSide = 'left',
  });
}

class TriggeredRule {
  final RuleType type;
  final String description;
  final double? measuredValue;
  final double? threshold;
  final SensorRegion? region;

  const TriggeredRule({
    required this.type,
    required this.description,
    this.measuredValue,
    this.threshold,
    this.region,
  });
}

class RecommendedAction {
  final String title;
  final String description;
  final String? instructions;
  final bool isUrgent;

  const RecommendedAction({
    required this.title,
    required this.description,
    this.instructions,
    this.isUrgent = false,
  });
}

class ExpertSystemResult {
  final RiskLevel riskLevel;
  final List<TriggeredRule> triggeredRules;
  final List<RecommendedAction> recommendedActions;
  final String userMessage;
  final bool shouldTriggerNotification;
  final bool shouldTriggerAlert;
  final SensorRegion? affectedRegion;
  final DateTime timestamp;

  const ExpertSystemResult({
    required this.riskLevel,
    required this.triggeredRules,
    required this.recommendedActions,
    required this.userMessage,
    required this.shouldTriggerNotification,
    required this.shouldTriggerAlert,
    this.affectedRegion,
    required this.timestamp,
  });

  factory ExpertSystemResult.normal() => ExpertSystemResult(
    riskLevel: RiskLevel.normal,
    triggeredRules: [],
    recommendedActions: [],
    userMessage: '',
    shouldTriggerNotification: false,
    shouldTriggerAlert: false,
    timestamp: DateTime.now(),
  );

  bool get hasRisk => riskLevel != RiskLevel.normal;
}

// ═══════════════════════════════════════════════════════════════════════════════
// KNOWLEDGE BASE - Clinical Thresholds (IWGDF)
// ═══════════════════════════════════════════════════════════════════════════════

class KnowledgeBase {
  /// Temperature difference threshold: ≥2.2°C indicates inflammation risk
  /// Reference: Armstrong et al. (2007) - Skin Temperature Monitoring
  static const double temperatureDifferenceThreshold = 2.2;
  
  /// Absolute pressure threshold: ≥200 kPa indicates tissue stress
  /// Reference: Bus et al. (2016) - IWGDF guidance on footwear and offloading
  static const double absolutePressureThreshold = 200.0;
  
  /// Baseline percentage: 30% above personal baseline is abnormal
  /// Reference: Clinical practice guidelines for personalized monitoring
  static const double pressureBaselinePercentage = 0.30;
}

// ═══════════════════════════════════════════════════════════════════════════════
// EXPERT SYSTEM ENGINE
// ═══════════════════════════════════════════════════════════════════════════════

class KhotaaExpertSystem {
  
  /// Evaluate temperature asymmetry between feet
  TriggeredRule? evaluateTemperatureRisk(double leftTemp, double rightTemp) {
    final tempDiff = (leftTemp - rightTemp).abs();
    if (tempDiff >= KnowledgeBase.temperatureDifferenceThreshold) {
      return TriggeredRule(
        type: RuleType.temperatureAsymmetry,
        description: 'Temperature difference of ${tempDiff.toStringAsFixed(1)}°C detected',
        measuredValue: tempDiff,
        threshold: KnowledgeBase.temperatureDifferenceThreshold,
      );
    }
    return null;
  }

  /// Evaluate pressure against absolute and baseline thresholds (IWGDF)
  List<TriggeredRule> evaluatePressureRisk(
    double pressure, double baseline, SensorRegion region) {
    final List<TriggeredRule> rules = [];

    // Rule 1: Absolute threshold (200 kPa - IWGDF standard)
    if (pressure >= KnowledgeBase.absolutePressureThreshold) {
      rules.add(TriggeredRule(
        type: RuleType.elevatedPressure,
        description: 'Pressure ${pressure.toStringAsFixed(0)} kPa exceeds ${KnowledgeBase.absolutePressureThreshold.toStringAsFixed(0)} kPa threshold in ${region.displayName}',
        measuredValue: pressure,
        threshold: KnowledgeBase.absolutePressureThreshold,
        region: region,
      ));
    }

    if (baseline > 0) {
      final baselineThreshold = baseline * (1 + KnowledgeBase.pressureBaselinePercentage);
      if (pressure >= baselineThreshold) {
        final pct = ((pressure - baseline) / baseline * 100);
        rules.add(TriggeredRule(
          type: RuleType.pressureAboveBaseline,
          description: 'Pressure ${pct.toStringAsFixed(0)}% above baseline in ${region.displayName}',
          measuredValue: pressure,
          threshold: baselineThreshold,
          region: region,
        ));
      }
    }
    return rules;
  }

  /// Main evaluation - combines all rules
  ExpertSystemResult evaluateSensorData(SensorInput input) {
    final List<TriggeredRule> allRules = [];

    final tempRule = evaluateTemperatureRisk(
      input.leftFootTemperature, input.rightFootTemperature);
    if (tempRule != null) allRules.add(tempRule);

    final pressureRules = evaluatePressureRisk(
      input.plantarPressure, input.pressureBaseline, input.sensorRegion);
    allRules.addAll(pressureRules);

    // Check combined risk
    final hasCombined = tempRule != null && pressureRules.isNotEmpty;
    if (hasCombined) {
      allRules.add(TriggeredRule(
        type: RuleType.combinedRisk,
        description: 'Combined temperature and pressure abnormality in ${input.sensorRegion.displayName}',
        region: input.sensorRegion,
      ));
    }

    if (allRules.isEmpty) return ExpertSystemResult.normal();

    // HIGH: combined risk, MODERATE: single factor
    if (hasCombined) {
      return ExpertSystemResult(
        riskLevel: RiskLevel.high,
        triggeredRules: allRules,
        recommendedActions: [
          RecommendedAction(
            title: 'Offload Pressure',
            description: 'Reduce pressure on ${input.sensorRegion.displayName}',
            instructions: 'Sit down and elevate your foot for 15-20 minutes.',
            isUrgent: true,
          ),
          RecommendedAction(
            title: 'Inspect Your Foot',
            description: 'Check for redness, swelling, or wounds',
            isUrgent: true,
          ),
        ],
        userMessage: 'High risk in ${input.sensorRegion.displayName}. Please offload and inspect.',
        shouldTriggerNotification: false,
        shouldTriggerAlert: true,
        affectedRegion: input.sensorRegion,
        timestamp: DateTime.now(),
      );
    }

    return ExpertSystemResult(
      riskLevel: RiskLevel.moderate,
      triggeredRules: allRules,
      recommendedActions: [
        RecommendedAction(
          title: tempRule != null ? 'Monitor Temperature' : 'Reduce Activity',
          description: tempRule != null 
            ? 'Temperature variation detected' 
            : 'Elevated pressure detected',
        ),
      ],
      userMessage: 'Foot stress detected. Monitor and reduce activity.',
      shouldTriggerNotification: true,
      shouldTriggerAlert: false,
      affectedRegion: input.sensorRegion,
      timestamp: DateTime.now(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// INTEGRATION SERVICE (AlertService Bridge)
// ═══════════════════════════════════════════════════════════════════════════════

class ExpertSystemIntegration {
  final KhotaaExpertSystem _expertSystem = KhotaaExpertSystem();
  final AlertService _alertService = AlertService();

  static final ExpertSystemIntegration _instance = ExpertSystemIntegration._internal();
  factory ExpertSystemIntegration() => _instance;
  ExpertSystemIntegration._internal();

  DateTime? _lastAlertTime;
  static const Duration _alertCooldown = Duration(minutes: 5);

  /// Process sensor data and create alerts if needed
  Future<ExpertSystemResult> processSensorData({
    required double leftFootTemperature,
    required double rightFootTemperature,
    required double plantarPressure,
    required double pressureBaseline,
    required SensorRegion sensorRegion,
    String footSide = 'left',
  }) async {
    final input = SensorInput(
      leftFootTemperature: leftFootTemperature,
      rightFootTemperature: rightFootTemperature,
      plantarPressure: plantarPressure,
      pressureBaseline: pressureBaseline,
      sensorRegion: sensorRegion,
      footSide: footSide,
    );

    final result = _expertSystem.evaluateSensorData(input);
    await _handleResult(result, input);
    return result;
  }

  Future<void> _handleResult(ExpertSystemResult result, SensorInput input) async {
    if (!result.hasRisk) return;

    // Cooldown check
    if (_lastAlertTime != null &&
        DateTime.now().difference(_lastAlertTime!) < _alertCooldown) {
      return;
    }

    if (result.shouldTriggerAlert || result.shouldTriggerNotification) {
      await _createAlert(result, input);
      _lastAlertTime = DateTime.now();
    }
  }

  Future<void> _createAlert(ExpertSystemResult result, SensorInput input) async {
    try {
      final alertRiskLevel = switch (result.riskLevel) {
        RiskLevel.high => alert_model.RiskLevel.high,
        RiskLevel.moderate => alert_model.RiskLevel.medium,
        RiskLevel.normal => alert_model.RiskLevel.low,
      };

      await _alertService.createCustomAlert(
        title: result.riskLevel == RiskLevel.high ? 'High Risk Alert' : 'Foot Stress Detected',
        shortDescription: result.userMessage,
        detailedExplanation: _buildExplanation(result, input),
        riskLevel: alertRiskLevel,
        category: alert_model.RiskCategory.pressure,
        recommendationTitle: result.recommendedActions.isNotEmpty
            ? result.recommendedActions.first.title : null,
        recommendationDescription: result.recommendedActions.isNotEmpty
            ? result.recommendedActions.first.description : null,
        instructions: result.recommendedActions.isNotEmpty
            ? result.recommendedActions.first.instructions : null,
      );
    } catch (e) {
      debugPrint('Error creating alert: $e');
    }
  }

  String _buildExplanation(ExpertSystemResult result, SensorInput input) {
    final buf = StringBuffer('Expert system findings:\n\n');
    for (final rule in result.triggeredRules) {
      buf.writeln('• ${rule.description}');
    }
    buf.writeln('\nReadings:');
    buf.writeln('• Left temp: ${input.leftFootTemperature.toStringAsFixed(1)}°C');
    buf.writeln('• Right temp: ${input.rightFootTemperature.toStringAsFixed(1)}°C');
    buf.writeln('• Pressure: ${input.plantarPressure.toStringAsFixed(0)} kPa');
    buf.writeln('• Region: ${input.sensorRegion.displayName}');
    return buf.toString();
  }

  void resetCooldown() => _lastAlertTime = null;
}

extension ExpertSystemContext on BuildContext {
  ExpertSystemIntegration get expertSystem => ExpertSystemIntegration();
}
