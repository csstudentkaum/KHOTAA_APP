import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Notification type for categorizing alerts
enum NotificationType {
  health,      // Health alerts from expert system (temperature/pressure)
  appointment, // Doctor appointments and reminders
}

extension NotificationTypeExtension on NotificationType {
  String get label {
    switch (this) {
      case NotificationType.health:
        return 'Health Alert';
      case NotificationType.appointment:
        return 'Appointment';
    }
  }

  IconData get icon {
    switch (this) {
      case NotificationType.health:
        return Icons.monitor_heart_outlined;
      case NotificationType.appointment:
        return Icons.calendar_month_outlined;
    }
  }

  Color get accentColor {
    switch (this) {
      case NotificationType.health:
        return const Color(0xFFF57C00); // Orange for health
      case NotificationType.appointment:
        return const Color(0xFF5C6BC0); // Blue for appointments
    }
  }

  Color get backgroundColor {
    switch (this) {
      case NotificationType.health:
        return const Color(0xFFFFF3E0); // Light orange
      case NotificationType.appointment:
        return const Color(0xFFE8EAF6); // Light blue
    }
  }
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
  movement,
  general,
}

/// Extension to add helper methods to RiskLevel
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

/// Extension to add helper methods to RiskCategory
extension RiskCategoryExtension on RiskCategory {
  String get label {
    switch (this) {
      case RiskCategory.pressure:
        return 'Pressure';
      case RiskCategory.temperature:
        return 'Temperature';
      case RiskCategory.movement:
        return 'Movement';
      case RiskCategory.general:
        return 'General';
    }
  }

  IconData get icon {
    switch (this) {
      case RiskCategory.pressure:
        return Icons.compress;
      case RiskCategory.temperature:
        return Icons.thermostat;
      case RiskCategory.movement:
        return Icons.directions_walk;
      case RiskCategory.general:
        return Icons.health_and_safety;
    }
  }

  String get illustrationAsset {
    switch (this) {
      case RiskCategory.pressure:
        return 'assets/images/pressure_risk.png';
      case RiskCategory.temperature:
        return 'assets/images/temperature_risk.png';
      case RiskCategory.movement:
        return 'assets/images/movement_risk.png';
      case RiskCategory.general:
        return 'assets/images/general_risk.png';
    }
  }
}

/// Smart Alert model with enhanced risk information
class SmartAlert {
  final String id;
  final String title;
  final String shortDescription;
  final String detailedExplanation;
  final RiskLevel riskLevel;
  final RiskCategory category;
  final NotificationType notificationType; // health or appointment
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
    this.notificationType = NotificationType.health, // default to health
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

  /// Create a copy with updated fields
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

  /// Create from Firestore document
  factory SmartAlert.fromFirestore(DocumentSnapshot doc) {
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
        orElse: () => RiskCategory.general,
      ),
      notificationType: NotificationType.values.firstWhere(
        (e) => e.name == data['notificationType'],
        orElse: () => NotificationType.health,
      ),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
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

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'shortDescription': shortDescription,
      'detailedExplanation': detailedExplanation,
      'riskLevel': riskLevel.name,
      'category': category.name,
      'notificationType': notificationType.name,
      'timestamp': Timestamp.fromDate(timestamp),
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

  /// Format timestamp for display
  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  /// Get full formatted date and time
  String get fullFormattedDateTime {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = timestamp.hour > 12 ? timestamp.hour - 12 : timestamp.hour;
    final period = timestamp.hour >= 12 ? 'PM' : 'AM';
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '${months[timestamp.month - 1]} ${timestamp.day}, ${timestamp.year} at $hour:$minute $period';
  }

  /// Create an alert from sensor reading data
  /// Simplified: Only create meaningful alerts when thresholds are exceeded
  factory SmartAlert.fromSensorReading({
    required String id,
    required String patientId,
    required double pressureValue,
    required double temperatureValue,
    required String footSide,
    required String sensorRegion,
  }) {
    RiskCategory category;
    String title;
    String shortDescription;
    String detailedExplanation;
    String? recommendationTitle;
    String? recommendationDescription;
    String? instructions;

    // Simplified threshold-based detection
    // Pressure threshold: > 250 units is abnormal
    // Temperature threshold: > 38°C or < 34.5°C is abnormal
    final isAbnormalPressure = pressureValue > 250;
    final isAbnormalTemp = temperatureValue > 38.0 || temperatureValue < 34.5;

    if (isAbnormalPressure && isAbnormalTemp) {
      category = RiskCategory.pressure;
      title = 'Pressure & Temperature Alert';
      shortDescription = 'Please check your $footSide foot';
      detailedExplanation = 
          'Your smart insole detected unusual readings on your $footSide foot '
          'in the $sensorRegion area.\n\n'
          '• Pressure: ${pressureValue.toStringAsFixed(1)} units\n'
          '• Temperature: ${temperatureValue.toStringAsFixed(1)}°C\n\n'
          'Consider taking a short break and checking your foot for any discomfort.';
      recommendationTitle = 'Take a Break';
      recommendationDescription = 'Rest your feet and check for discomfort';
      instructions = 'Sit down and rest your feet for 15-20 minutes. Check your foot for any redness or irritation.';
    } else if (isAbnormalPressure) {
      category = RiskCategory.pressure;
      title = 'Pressure Alert';
      shortDescription = 'Elevated pressure on $footSide foot';
      detailedExplanation = 
          'Your smart insole detected elevated pressure '
          '(${pressureValue.toStringAsFixed(1)} units) on your $footSide foot '
          'in the $sensorRegion area.\n\n'
          'Consider taking a short break to reduce pressure on your feet.';
      recommendationTitle = 'Reduce Pressure';
      recommendationDescription = 'Rest your feet';
      instructions = 'Sit down and elevate your feet for 15-20 minutes. Consider changing to more comfortable footwear.';
    } else if (isAbnormalTemp) {
      category = RiskCategory.temperature;
      title = 'Temperature Alert';
      shortDescription = 'Unusual temperature on $footSide foot';
      detailedExplanation = 
          'Your smart insole detected an unusual temperature '
          '(${temperatureValue.toStringAsFixed(1)}°C) on your $footSide foot.\n\n'
          'This may be due to various factors. Check your foot for any discomfort.';
      recommendationTitle = 'Check Your Foot';
      recommendationDescription = 'Inspect for any issues';
      instructions = temperatureValue > 37.5 
          ? 'Check your foot for any redness or swelling. Rest in a cool area.'
          : 'Keep your feet warm and check for any signs of cold or numbness.';
    } else {
      // Normal reading - create a simple status update
      category = RiskCategory.general;
      title = 'Foot Status';
      shortDescription = 'Normal readings recorded';
      detailedExplanation = 
          'Your foot readings are within normal range:\n'
          '• Pressure: ${pressureValue.toStringAsFixed(1)} units\n'
          '• Temperature: ${temperatureValue.toStringAsFixed(1)}°C';
      recommendationTitle = 'Continue as Usual';
      recommendationDescription = 'Keep up your foot care routine';
      instructions = 'Continue with your regular activities and foot care.';
    }

    // Note: riskLevel is kept for backward compatibility but not used in UI
    return SmartAlert(
      id: id,
      title: title,
      shortDescription: shortDescription,
      detailedExplanation: detailedExplanation,
      riskLevel: (isAbnormalPressure || isAbnormalTemp) ? RiskLevel.high : RiskLevel.low,
      category: category,
      timestamp: DateTime.now(),
      patientId: patientId,
      sensorData: {
        'pressureValue': pressureValue,
        'temperatureValue': temperatureValue,
        'footSide': footSide,
        'sensorRegion': sensorRegion,
      },
      recommendationTitle: recommendationTitle,
      recommendationDescription: recommendationDescription,
      instructions: instructions,
    );
  }
}
