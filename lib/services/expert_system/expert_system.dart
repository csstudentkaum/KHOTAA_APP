// KHOTAA Expert System - Rule-Based Diabetic Foot Ulcer Risk Detection
//
// Based on IWGDF 2023 Guidelines:
// - Prevention Guideline: Temperature monitoring (≥2.2°C asymmetry)
// - Offloading Guideline: Pressure thresholds (≥200 kPa)
// - References: Armstrong et al. (2007), Bus et al. (2016)
//
// Designed to prevent alert fatigue - only notifies for clinically significant risk.

import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// ENUMS
// ═══════════════════════════════════════════════════════════════════════════════

/// 8 anatomical sensor regions monitored by the insole.
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
        recommendedActions: _getHighRiskRecommendations(input.sensorRegion),
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
      recommendedActions: tempRule != null
          ? _getTemperatureRecommendations(input.sensorRegion)
          : _getPressureRecommendations(input.sensorRegion),
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

  /// COMBINED RISK recommendations — IWGDF 2023 (Prevention + Offloading Guidelines)
  /// Simultaneous temperature asymmetry ≥2.2°C and pressure ≥200 kPa: pre-ulcerative state
  /// Reference: Bus et al. (2023) IWGDF Guidelines on prevention and offloading
  List<RecommendedAction> _getHighRiskRecommendations(SensorRegion region) {
    return [
      RecommendedAction(
        title: 'Urgent: Stop Activity Immediately',
        description:
            'Combined elevated pressure and skin temperature asymmetry indicate a pre-ulcerative state. '
            'Immediate action is required to prevent diabetic foot ulceration (IWGDF 2023).',
        instructions: '1. Stop all weight-bearing activity immediately\n'
            '2. Sit or lie down and elevate your foot above heart level\n'
            '3. Inspect the ${region.displayName} for redness, warmth, swelling, or blisters\n'
            '4. Do not apply heat or massage the affected area\n'
            '5. Use a wheelchair or crutches if you must move\n'
            '6. Contact your healthcare provider or diabetic foot clinic today — do not wait',
        isUrgent: true,
      ),
    ];
  }

  /// TEMPERATURE recommendations — IWGDF 2023 Prevention Guideline
  /// Temperature asymmetry ≥2.2°C between feet signals early inflammation or increased ulcer risk
  /// Reference: Armstrong et al. (2007); Bus et al. (2023) IWGDF Prevention Guideline
  List<RecommendedAction> _getTemperatureRecommendations(SensorRegion region) {
    return [
      RecommendedAction(
        title: 'Elevated Skin Temperature Detected',
        description:
            'A temperature difference of ≥2.2°C between your feet has been detected in the ${region.displayName}. '
            'This is a clinically recognised early warning sign of inflammation or increased ulceration risk '
            'according to the IWGDF 2023 Prevention Guideline.',
        instructions: '1. Stop activity and rest your feet for at least 30 minutes\n'
            '2. Remove shoes and socks to allow the foot to cool naturally\n'
            '3. Inspect the warmer foot for redness, swelling, or any skin changes\n'
            '4. Avoid tight footwear, socks with seams, or anything that restricts circulation\n'
            '5. Recheck temperature after 30 minutes — if asymmetry persists, reduce activity for the day\n'
            '6. Inform your healthcare provider at your next visit, or sooner if skin changes appear',
        isUrgent: false,
      ),
    ];
  }

  /// PRESSURE recommendations — IWGDF 2023 Offloading Guideline
  /// Peak plantar pressure ≥200 kPa significantly increases diabetic foot ulceration risk
  /// Reference: Bus et al. (2023) IWGDF Offloading Guideline; Cavanagh & Ulbrecht (1994)
  List<RecommendedAction> _getPressureRecommendations(SensorRegion region) {
    return [
      RecommendedAction(
        title: 'Pressure Offloading Required',
        description:
            'Peak plantar pressure in the ${region.displayName} exceeds the safe threshold of 200 kPa. '
            'Sustained high pressure on insensate diabetic feet is a leading cause of foot ulceration, '
            'as stated in the IWGDF 2023 Offloading Guideline.',
        instructions: '1. Stop current activity and rest immediately\n'
            '2. Use therapeutic footwear with cushioned, pressure-redistributing insoles\n'
            '3. Consider walking aids (crutches or walking frame) to reduce foot loading\n'
            '4. Avoid barefoot walking — even short distances indoors\n'
            '5. Avoid flat, hard-soled shoes or sandals without cushioning\n'
            '6. Consult your healthcare provider if elevated pressure readings persist',
        isUrgent: true,
      ),
    ];
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
