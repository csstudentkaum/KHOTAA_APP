import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
  factory SmartAlert.fromSensorReading({
    required String id,
    required String patientId,
    required double pressureValue,
    required double temperatureValue,
    required String footSide,
    required String sensorRegion,
  }) {
    RiskLevel riskLevel;
    RiskCategory category;
    String title;
    String shortDescription;
    String detailedExplanation;
    String? recommendationTitle;
    String? recommendationDescription;
    String? instructions;

    final isHighPressure = pressureValue > 250;
    final isMediumPressure = pressureValue > 200;
    final isHighTemp = temperatureValue > 38.0 || temperatureValue < 34.5;
    final isMediumTemp = temperatureValue > 37.5 || temperatureValue < 35.0;

    if (isHighPressure && isHighTemp) {
      riskLevel = RiskLevel.high;
      category = RiskCategory.pressure;
      title = 'Critical Foot Alert';
      shortDescription = 'High pressure and abnormal temperature detected';
      detailedExplanation = 
          'Your smart insole has detected a critical combination of high pressure '
          '(${pressureValue.toStringAsFixed(1)} units) and abnormal temperature '
          '(${temperatureValue.toStringAsFixed(1)}°C) in your $footSide foot, '
          'specifically in the $sensorRegion region.\n\n'
          'This combination can indicate early signs of tissue stress or potential '
          'ulcer formation. Immediate attention is recommended.';
      recommendationTitle = 'Seek Immediate Care';
      recommendationDescription = 'Contact your healthcare provider urgently';
      instructions = 'Rest your foot immediately and contact your podiatrist or visit an urgent care clinic within 24 hours.';
    } else if (isHighPressure) {
      riskLevel = RiskLevel.high;
      category = RiskCategory.pressure;
      title = 'High Pressure Alert';
      shortDescription = 'Excessive pressure on $footSide foot';
      detailedExplanation = 
          'Your smart insole has detected high pressure (${pressureValue.toStringAsFixed(1)} units) '
          'on your $footSide foot in the $sensorRegion region.\n\n'
          'Prolonged high pressure can lead to tissue damage and increase the risk '
          'of diabetic foot ulcers. Taking a break and adjusting your footwear is recommended.';
      recommendationTitle = 'Reduce Standing Time';
      recommendationDescription = 'Rest your feet and redistribute pressure';
      instructions = 'Sit down and elevate your feet for 15-20 minutes. Consider changing to better-cushioned footwear.';
    } else if (isHighTemp) {
      riskLevel = RiskLevel.high;
      category = RiskCategory.temperature;
      title = 'Temperature Alert';
      shortDescription = 'Abnormal foot temperature detected';
      detailedExplanation = 
          'Your smart insole has detected an abnormal temperature '
          '(${temperatureValue.toStringAsFixed(1)}°C) in your $footSide foot.\n\n'
          'Temperature changes can indicate inflammation, infection, or circulation issues. '
          'Monitoring and appropriate action is important.';
      recommendationTitle = 'Temperature Management';
      recommendationDescription = 'Apply appropriate thermal care';
      instructions = temperatureValue > 37.5 
          ? 'Apply a cool compress to your foot for 10-15 minutes. Avoid ice directly on skin.'
          : 'Warm your feet gently and wear warm socks. Check for signs of poor circulation.';
    } else if (isMediumPressure) {
      riskLevel = RiskLevel.medium;
      category = RiskCategory.pressure;
      title = 'Elevated Pressure Notice';
      shortDescription = 'Moderate pressure on $footSide foot';
      detailedExplanation = 
          'Your smart insole has detected moderately elevated pressure '
          '(${pressureValue.toStringAsFixed(1)} units) on your $footSide foot.\n\n'
          'While not immediately critical, continued elevated pressure should be monitored. '
          'Consider taking regular breaks when standing.';
      recommendationTitle = 'Monitor Pressure';
      recommendationDescription = 'Take periodic rest breaks';
      instructions = 'Take a 5-10 minute break every hour if standing. Check shoe fit and consider cushioned insoles.';
    } else if (isMediumTemp) {
      riskLevel = RiskLevel.medium;
      category = RiskCategory.temperature;
      title = 'Temperature Notice';
      shortDescription = 'Slight temperature variation detected';
      detailedExplanation = 
          'Your smart insole has detected a slight temperature variation '
          '(${temperatureValue.toStringAsFixed(1)}°C) in your $footSide foot.\n\n'
          'Minor temperature changes can occur naturally but should be monitored. '
          'Note if the variation persists.';
      recommendationTitle = 'Monitor Temperature';
      recommendationDescription = 'Keep track of temperature changes';
      instructions = 'Monitor your foot temperature over the next few hours. Note any persistent changes or accompanying symptoms.';
    } else {
      riskLevel = RiskLevel.low;
      category = RiskCategory.general;
      title = 'Foot Health Update';
      shortDescription = 'Routine monitoring update';
      detailedExplanation = 
          'Your smart insole has recorded your current foot status:\n'
          '- Pressure: ${pressureValue.toStringAsFixed(1)} units\n'
          '- Temperature: ${temperatureValue.toStringAsFixed(1)}°C\n\n'
          'All readings are within normal ranges. Continue with your regular foot care routine.';
      recommendationTitle = 'Continue Regular Care';
      recommendationDescription = 'Maintain your foot care routine';
      instructions = 'Continue with your daily foot inspections and moisturizing routine.';
    }

    return SmartAlert(
      id: id,
      title: title,
      shortDescription: shortDescription,
      detailedExplanation: detailedExplanation,
      riskLevel: riskLevel,
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
