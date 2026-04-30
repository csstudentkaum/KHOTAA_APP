import 'package:flutter/material.dart';

/// Notification type for categorizing alerts
enum NotificationType {
  health, // Health alerts from expert system (temperature/pressure)
}

extension NotificationTypeExtension on NotificationType {
  String get label => 'Health Alert';
  IconData get icon => Icons.monitor_heart_outlined;
  Color get accentColor => const Color(0xFFF57C00); // Orange for health
  Color get backgroundColor => const Color(0xFFFFF3E0); // Light orange
}

/// Risk level enumeration for alerts
enum RiskLevel {
  high,
  medium,
  low,
}

/// Risk category types
enum RiskCategory {
  pressure,
  temperature,
  combined, // Both pressure AND temperature abnormal
}

extension RiskLevelExtension on RiskLevel {
  String get label {
    switch (this) {
      case RiskLevel.high:
        return 'High';
      case RiskLevel.medium:
        return 'Medium';
      case RiskLevel.low:
        return 'Low';
    }
  }

  Color get color {
    switch (this) {
      case RiskLevel.high:
        return const Color(0xFFE53935);
      case RiskLevel.medium:
        return const Color(0xFFF39C12);
      case RiskLevel.low:
        return const Color(0xFF27AE60);
    }
  }

  Color get backgroundColor {
    switch (this) {
      case RiskLevel.high:
        return const Color(0xFFFFEBEE);
      case RiskLevel.medium:
        return const Color(0xFFFFF8E1);
      case RiskLevel.low:
        return const Color(0xFFE8F5E9);
    }
  }

  IconData get icon {
    switch (this) {
      case RiskLevel.high:
        return Icons.warning_rounded;
      case RiskLevel.medium:
        return Icons.info_rounded;
      case RiskLevel.low:
        return Icons.check_circle_rounded;
    }
  }
}

extension RiskCategoryExtension on RiskCategory {
  String get label {
    switch (this) {
      case RiskCategory.pressure:
        return 'Pressure';
      case RiskCategory.temperature:
        return 'Temperature';
      case RiskCategory.combined:
        return 'Combined';
    }
  }

  IconData get icon {
    switch (this) {
      case RiskCategory.pressure:
        return Icons.compress;
      case RiskCategory.temperature:
        return Icons.thermostat;
      case RiskCategory.combined:
        return Icons.warning_amber_rounded;
    }
  }

  String get illustrationAsset {
    switch (this) {
      case RiskCategory.pressure:
        return 'assets/images/pressure_risk.png';
      case RiskCategory.temperature:
        return 'assets/images/temperature_risk.png';
      case RiskCategory.combined:
        return 'assets/images/pressure_risk.png';
    }
  }
}

/// Smart Alert model with enhanced risk information
class SmartAlert {
  /// Returns a full formatted date and time string (e.g., 30/04/2026 14:30)
  String get fullFormattedDateTime {
    return "[0m${timestamp.day.toString().padLeft(2, '0')}/"
        "${timestamp.month.toString().padLeft(2, '0')}/"
        "${timestamp.year} "
        "${timestamp.hour.toString().padLeft(2, '0')}:"
        "${timestamp.minute.toString().padLeft(2, '0')}";
  }

  /// Create SmartAlert from Firestore document
  static SmartAlert fromFirestore(dynamic doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SmartAlert(
      id: doc.id,
      title: data['title'] ?? '',
      shortDescription: data['shortDescription'] ?? '',
      detailedExplanation: data['detailedExplanation'] ?? '',
      riskLevel: RiskLevel.values.firstWhere(
        (e) => e.name == data['riskLevel'],
        orElse: () => RiskLevel.medium,
      ),
      category: RiskCategory.values.firstWhere(
        (e) => e.name == data['category'],
        orElse: () => RiskCategory.pressure,
      ),
      notificationType: data['notificationType'] != null
          ? NotificationType.values.firstWhere(
              (e) => e.name == data['notificationType'],
              orElse: () => NotificationType.health,
            )
          : NotificationType.health,
      timestamp: DateTime.parse(data['timestamp']),
      isViewed: data['isViewed'] ?? false,
      isResolved: data['isResolved'] ?? false,
      patientId: data['patientId'] ?? '',
      sensorReadingId: data['sensorReadingId'],
      sensorData: data['sensorData'],
      recommendationTitle: data['recommendationTitle'],
      recommendationDescription: data['recommendationDescription'],
      instructions: data['instructions'],
    );
  }


  /// Convert SmartAlert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'shortDescription': shortDescription,
      'detailedExplanation': detailedExplanation,
      'riskLevel': riskLevel.name,
      'category': category.name,
      'notificationType': notificationType.name,
      'timestamp': timestamp.toIso8601String(),
      'isViewed': isViewed,
      'isResolved': isResolved,
      'patientId': patientId,
      'sensorReadingId': sensorReadingId,
      'sensorData': sensorData,
      'recommendationTitle': recommendationTitle,
      'recommendationDescription': recommendationDescription,
      'instructions': instructions,
    };
  }

      /// Returns a human-readable time string for notifications UI
      String get formattedTime {
        final now = DateTime.now();
        final diff = now.difference(timestamp);
        if (diff.inMinutes < 1) return 'Just now';
        if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
        if (diff.inHours < 24) return '${diff.inHours}h ago';
        if (diff.inDays < 7) return '${diff.inDays}d ago';
        return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
      }
    SmartAlert copyWith({
      String? id,
      String? title,
      String? shortDescription,
      String? detailedExplanation,
      RiskLevel? riskLevel,
      RiskCategory? category,
      NotificationType? notificationType,
      DateTime? timestamp,
      bool? isViewed,
      bool? isResolved,
      String? patientId,
      String? sensorReadingId,
      Map<String, dynamic>? sensorData,
      String? recommendationTitle,
      String? recommendationDescription,
      IconData? recommendationIcon,
      String? instructions,
    }) {
      return SmartAlert(
        id: id ?? this.id,
        title: title ?? this.title,
        shortDescription: shortDescription ?? this.shortDescription,
        detailedExplanation: detailedExplanation ?? this.detailedExplanation,
        riskLevel: riskLevel ?? this.riskLevel,
        category: category ?? this.category,
        notificationType: notificationType ?? this.notificationType,
        timestamp: timestamp ?? this.timestamp,
        isViewed: isViewed ?? this.isViewed,
        isResolved: isResolved ?? this.isResolved,
        patientId: patientId ?? this.patientId,
        sensorReadingId: sensorReadingId ?? this.sensorReadingId,
        sensorData: sensorData ?? this.sensorData,
        recommendationTitle: recommendationTitle ?? this.recommendationTitle,
        recommendationDescription: recommendationDescription ?? this.recommendationDescription,
        recommendationIcon: recommendationIcon ?? this.recommendationIcon,
        instructions: instructions ?? this.instructions,
      );
    }
  final String id;
  final String title;
  final String shortDescription;
  final String detailedExplanation;
  final RiskLevel riskLevel;
  final RiskCategory category;
  final NotificationType notificationType; // health only
  final DateTime timestamp;
  final bool isViewed;
  final bool isResolved;
  final String patientId;
  final String? sensorReadingId;
  final Map<String, dynamic>? sensorData;
  // Recommendation data
  final String? recommendationTitle;
  final String? recommendationDescription;
  final IconData? recommendationIcon;
  final String? instructions;

  SmartAlert({
    required this.id,
    required this.title,
    required this.shortDescription,
    required this.detailedExplanation,
    required this.riskLevel,
    required this.category,
    this.notificationType = NotificationType.health,
    required this.timestamp,
    this.isViewed = false,
    this.isResolved = false,
    required this.patientId,
    this.sensorReadingId,
    this.sensorData,
    this.recommendationTitle,
    this.recommendationDescription,
    this.recommendationIcon,
    this.instructions,
  });
}