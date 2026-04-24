// KHOTAA Expert System - Rule-Based Diabetic Foot Ulcer Risk Detection
// Based on IWGDF 2023 Guidelines:
// - Prevention Guideline: Temperature monitoring (≥2.2°C asymmetry)
// - Offloading Guideline: Pressure thresholds (≥200 kPa)

import 'package:flutter/material.dart';

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
  final String affectedFoot; // "left" or "right"
  final DateTime timestamp;

  const ExpertSystemResult({
    required this.riskLevel,
    required this.triggeredRules,
    required this.recommendedActions,
    required this.userMessage,
    required this.shouldTriggerNotification,
    required this.shouldTriggerAlert,
    this.affectedRegion,
    this.affectedFoot = 'left',
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
  
  /// Get display name with foot side (e.g., "Left Metatarsal 1 (MTK1)")
  String get fullRegionName {
    final footLabel = affectedFoot == 'left' ? 'Left' : 'Right';
    final regionName = affectedRegion?.displayName ?? 'Foot';
    return '$footLabel $regionName';
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// KNOWLEDGE BASE - Clinical Thresholds (IWGDF)
// ═══════════════════════════════════════════════════════════════════════════════

class KhotaaExpertSystem {

    /// Evaluate temperature asymmetry between feet
    TriggeredRule? evaluateTemperatureRisk(double leftTemp, double rightTemp) {
      const threshold = 2.2;
      final tempDiff = (leftTemp - rightTemp).abs();
      if (tempDiff >= threshold) {
        return TriggeredRule(
          type: RuleType.temperatureAsymmetry,
          description: 'Temperature difference of ${tempDiff.toStringAsFixed(1)}°C detected',
          measuredValue: tempDiff,
          threshold: threshold,
        );
      }
      return null;
    }

    /// Evaluate pressure against absolute and baseline thresholds
    List<TriggeredRule> evaluatePressureRisk(
      double pressure, double baseline, SensorRegion region) {
      final List<TriggeredRule> rules = [];
      const absoluteThreshold = 200.0;
      const baselinePct = 0.30;
      // Rule 1: Absolute threshold
      if (pressure >= absoluteThreshold) {
        rules.add(TriggeredRule(
          type: RuleType.elevatedPressure,
          description: 'Pressure ${pressure.toStringAsFixed(0)} kPa exceeds ${absoluteThreshold.toStringAsFixed(0)} kPa threshold in ${region.displayName}',
          measuredValue: pressure,
          threshold: absoluteThreshold,
          region: region,
        ));
      }
      if (baseline > 0) {
        final baselineThreshold = baseline * (1 + baselinePct);
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
  /// HIGH RISK recommendation based on IWGDF 2023 Prevention Guideline
  /// Combined temperature and pressure abnormality indicates pre-ulcerative state
  RecommendedAction _getHighRiskRecommendation(SensorRegion region) {
    return RecommendedAction(
      title: 'Offload Immediately',
      description: 'Stop weight-bearing on the affected foot',
      instructions: 'Sit or lie down. Elevate your foot above heart level for 15-20 minutes.',
      isUrgent: true,
    );
  }

  /// TEMPERATURE recommendation based on IWGDF 2023
  /// Temperature asymmetry ≥2.2°C may indicate inflammation or early infection
  RecommendedAction _getTemperatureRecommendation(SensorRegion region) {
    return RecommendedAction(
      title: 'Monitor Temperature',
      description: 'Temperature difference detected between feet',
      instructions: 'Rest your feet and recheck in 1-2 hours. If asymmetry persists, reduce activity.',
      isUrgent: false,
    );
  }

  /// PRESSURE recommendation based on IWGDF 2023 Offloading Guideline
  /// Peak plantar pressure ≥200 kPa increases ulceration risk
  RecommendedAction _getPressureRecommendation(SensorRegion region) {
    return RecommendedAction(
      title: 'Reduce Weight-Bearing',
      description: 'Lower plantar pressure to prevent tissue damage',
      instructions: 'Take a seated break. Avoid prolonged standing or walking.',
      isUrgent: false,
    );
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
        description: 'Combined temperature and pressure abnormality in ${input.footSide} ${input.sensorRegion.displayName}',
        region: input.sensorRegion,
      ));
    }

    if (allRules.isEmpty) return ExpertSystemResult.normal();

    final footLabel = input.footSide == 'left' ? 'Left' : 'Right';
    final regionName = input.sensorRegion.displayName;

    // HIGH: combined risk, MODERATE: single factor
    if (hasCombined) {
      return ExpertSystemResult(
        riskLevel: RiskLevel.high,
        triggeredRules: allRules,
        recommendedActions: [_getHighRiskRecommendation(input.sensorRegion)],
        userMessage: 'High risk detected in $footLabel $regionName. Immediate action required.',
        shouldTriggerNotification: false,
        shouldTriggerAlert: true,
        affectedRegion: input.sensorRegion,
        affectedFoot: input.footSide,
        timestamp: DateTime.now(),
      );
    }

    // MODERATE: Single factor risk
    return ExpertSystemResult(
      riskLevel: RiskLevel.moderate,
      triggeredRules: allRules,
      recommendedActions: [
        tempRule != null
            ? _getTemperatureRecommendation(input.sensorRegion)
            : _getPressureRecommendation(input.sensorRegion)
      ],
      userMessage: tempRule != null
          ? 'Temperature asymmetry detected in $footLabel foot. Monitor closely.'
          : 'Elevated pressure in $footLabel $regionName. Reduce activity.',
      shouldTriggerNotification: true,
      shouldTriggerAlert: false,
      affectedRegion: input.sensorRegion,
      affectedFoot: input.footSide,
      timestamp: DateTime.now(),
    );
  }

}

// ═══════════════════════════════════════════════════════════════════════════════
// INTEGRATION SERVICE
// ═══════════════════════════════════════════════════════════════════════════════

class ExpertSystemIntegration {
  final KhotaaExpertSystem _expertSystem = KhotaaExpertSystem();

  static final ExpertSystemIntegration _instance = ExpertSystemIntegration._internal();
  factory ExpertSystemIntegration() => _instance;
  ExpertSystemIntegration._internal();

  /// Process sensor data and return evaluation result
  /// NOTE: Alert/notification handling is done by SensorAlertHandler
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

    return _expertSystem.evaluateSensorData(input);
  }
}

extension ExpertSystemContext on BuildContext {
  ExpertSystemIntegration get expertSystem => ExpertSystemIntegration();
}
