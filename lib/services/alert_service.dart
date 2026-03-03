import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/smart_alert.dart';

/// Service for managing smart alerts across the app
/// Handles alert creation, storage, and notification triggers
class AlertService extends ChangeNotifier {
  static final AlertService _instance = AlertService._internal();
  factory AlertService() => _instance;
  AlertService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Alert storage
  final List<SmartAlert> _alerts = [];
  List<SmartAlert> get alerts => List.unmodifiable(_alerts);
  
  // Unread count
  int get unreadCount => _alerts.where((a) => !a.isViewed).length;
  
  // Stream controller for new alerts
  final StreamController<SmartAlert> _newAlertController = 
      StreamController<SmartAlert>.broadcast();
  Stream<SmartAlert> get onNewAlert => _newAlertController.stream;

  // Bell animation trigger
  final StreamController<void> _bellAnimationController = 
      StreamController<void>.broadcast();
  Stream<void> get onBellAnimation => _bellAnimationController.stream;

  // Current patient ID
  String? _currentPatientId;

  /// Initialize the service for a patient
  Future<void> initialize(String patientId) async {
    _currentPatientId = patientId;
    await _loadLocalAlerts();
    _listenToFirestoreAlerts();
  }

  /// Load alerts from local storage
  Future<void> _loadLocalAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alertsJson = prefs.getString('smart_alerts_$_currentPatientId');
      if (alertsJson != null) {
        final List<dynamic> alertsList = json.decode(alertsJson);
        _alerts.clear();
        _alerts.addAll(alertsList.map((a) => _alertFromJson(a)));
        _alerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading local alerts: $e');
    }
  }

  /// Save alerts to local storage
  Future<void> _saveLocalAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alertsJson = json.encode(_alerts.map((a) => _alertToJson(a)).toList());
      await prefs.setString('smart_alerts_$_currentPatientId', alertsJson);
    } catch (e) {
      debugPrint('Error saving local alerts: $e');
    }
  }

  /// Listen to Firestore for real-time alerts
  void _listenToFirestoreAlerts() {
    if (_currentPatientId == null) return;

    _firestore
        .collection('alerts')
        .where('patientId', isEqualTo: _currentPatientId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final alert = SmartAlert.fromFirestore(change.doc);
          if (!_alerts.any((a) => a.id == alert.id)) {
            _addAlert(alert);
          }
        }
      }
    });
  }

  /// Add a new alert
  void _addAlert(SmartAlert alert) {
    _alerts.insert(0, alert);
    _alerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    _saveLocalAlerts();
    _newAlertController.add(alert);
    _bellAnimationController.add(null);
    notifyListeners();
  }

  /// Trigger a new alert from sensor reading
  Future<SmartAlert> triggerAlert({
    required double pressureValue,
    required double temperatureValue,
    required String footSide,
    required String sensorRegion,
  }) async {
    if (_currentPatientId == null) {
      throw Exception('Alert service not initialized');
    }

    final alert = SmartAlert.fromSensorReading(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      patientId: _currentPatientId!,
      pressureValue: pressureValue,
      temperatureValue: temperatureValue,
      footSide: footSide,
      sensorRegion: sensorRegion,
    );

    // Save to Firestore
    try {
      await _firestore.collection('alerts').doc(alert.id).set(alert.toFirestore());
    } catch (e) {
      debugPrint('Error saving alert to Firestore: $e');
    }

    // Add locally
    _addAlert(alert);

    return alert;
  }

  /// Create a custom alert
  Future<SmartAlert> createCustomAlert({
    required String title,
    required String shortDescription,
    required String detailedExplanation,
    required RiskLevel riskLevel,
    required RiskCategory category,
    String? recommendationTitle,
    String? recommendationDescription,
    String? instructions,
  }) async {
    if (_currentPatientId == null) {
      throw Exception('Alert service not initialized');
    }

    final alert = SmartAlert(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      shortDescription: shortDescription,
      detailedExplanation: detailedExplanation,
      riskLevel: riskLevel,
      category: category,
      timestamp: DateTime.now(),
      patientId: _currentPatientId!,
      recommendationTitle: recommendationTitle,
      recommendationDescription: recommendationDescription,
      instructions: instructions,
    );

    // Save to Firestore
    try {
      await _firestore.collection('alerts').doc(alert.id).set(alert.toFirestore());
    } catch (e) {
      debugPrint('Error saving alert to Firestore: $e');
    }

    // Add locally
    _addAlert(alert);

    return alert;
  }

  /// Mark an alert as viewed
  Future<void> markAsViewed(String alertId) async {
    final index = _alerts.indexWhere((a) => a.id == alertId);
    if (index != -1) {
      _alerts[index] = _alerts[index].copyWith(isViewed: true);
      _saveLocalAlerts();
      notifyListeners();

      // Update Firestore
      try {
        await _firestore.collection('alerts').doc(alertId).update({'isViewed': true});
      } catch (e) {
        debugPrint('Error updating alert in Firestore: $e');
      }
    }
  }

  /// Mark all alerts as viewed
  Future<void> markAllAsViewed() async {
    for (int i = 0; i < _alerts.length; i++) {
      if (!_alerts[i].isViewed) {
        _alerts[i] = _alerts[i].copyWith(isViewed: true);
      }
    }
    _saveLocalAlerts();
    notifyListeners();
  }

  /// Mark an alert as resolved
  Future<void> markAsResolved(String alertId) async {
    final index = _alerts.indexWhere((a) => a.id == alertId);
    if (index != -1) {
      _alerts[index] = _alerts[index].copyWith(isResolved: true);
      _saveLocalAlerts();
      notifyListeners();

      // Update Firestore
      try {
        await _firestore.collection('alerts').doc(alertId).update({'isResolved': true});
      } catch (e) {
        debugPrint('Error updating alert in Firestore: $e');
      }
    }
  }

  /// Get alert by ID
  SmartAlert? getAlertById(String alertId) {
    try {
      return _alerts.firstWhere((a) => a.id == alertId);
    } catch (e) {
      return null;
    }
  }

  /// Get alerts filtered by risk level
  List<SmartAlert> getAlertsByRiskLevel(RiskLevel level) {
    return _alerts.where((a) => a.riskLevel == level).toList();
  }

  /// Get alerts filtered by category
  List<SmartAlert> getAlertsByCategory(RiskCategory category) {
    return _alerts.where((a) => a.category == category).toList();
  }

  /// Get unresolved alerts
  List<SmartAlert> get unresolvedAlerts {
    return _alerts.where((a) => !a.isResolved).toList();
  }

  /// Clear all alerts (for testing)
  Future<void> clearAllAlerts() async {
    _alerts.clear();
    _saveLocalAlerts();
    notifyListeners();
  }

  /// Add sample alerts for testing/demo
  Future<void> addSampleAlerts() async {
    if (_currentPatientId == null) return;

    final samples = [
      SmartAlert(
        id: '${DateTime.now().millisecondsSinceEpoch}1',
        title: 'High Pressure Alert',
        shortDescription: 'Excessive pressure on left foot heel',
        detailedExplanation: 
            'Your smart insole has detected high pressure (265 units) on your left foot '
            'in the heel region.\n\n'
            'Prolonged high pressure can lead to tissue damage and increase the risk '
            'of diabetic foot ulcers. Taking a break and adjusting your footwear is recommended.',
        riskLevel: RiskLevel.high,
        category: RiskCategory.pressure,
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        patientId: _currentPatientId!,
        recommendationTitle: 'Reduce Standing Time',
        recommendationDescription: 'Rest your feet for 15-20 minutes',
        instructions: 'Sit down and elevate your feet above heart level. This helps reduce swelling and pressure.',
      ),
      SmartAlert(
        id: '${DateTime.now().millisecondsSinceEpoch}2',
        title: 'Temperature Alert',
        shortDescription: 'Elevated temperature on right foot',
        detailedExplanation: 
            'Your smart insole has detected elevated temperature (38.2°C) in your right foot.\n\n'
            'Elevated temperature can indicate inflammation or infection. '
            'Applying a cool compress and monitoring is recommended.',
        riskLevel: RiskLevel.high,
        category: RiskCategory.temperature,
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        patientId: _currentPatientId!,
        isViewed: true,
        recommendationTitle: 'Cool Down Your Feet',
        recommendationDescription: 'Apply cool compress for 10-15 minutes',
        instructions: 'Use a cool (not cold) compress on your foot. Avoid ice directly on skin. Monitor for changes.',
      ),
      SmartAlert(
        id: '${DateTime.now().millisecondsSinceEpoch}3',
        title: 'Movement Pattern Change',
        shortDescription: 'Unusual gait pattern detected',
        detailedExplanation: 
            'Your smart insole has detected changes in your walking pattern.\n\n'
            'This could indicate discomfort, fatigue, or compensation for pain. '
            'Gentle stretching exercises are recommended.',
        riskLevel: RiskLevel.medium,
        category: RiskCategory.movement,
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        patientId: _currentPatientId!,
        recommendationTitle: 'Gentle Stretching',
        recommendationDescription: 'Try ankle rotation exercises',
        instructions: 'Rotate your ankles clockwise 10 times, then counterclockwise 10 times. Repeat 3 sets.',
      ),
      SmartAlert(
        id: '${DateTime.now().millisecondsSinceEpoch}4',
        title: 'Pressure Distribution Notice',
        shortDescription: 'Uneven pressure distribution detected',
        detailedExplanation: 
            'Your smart insole has detected uneven pressure distribution across your feet.\n\n'
            'This may be due to shoe wear or walking habits. Consider checking your footwear.',
        riskLevel: RiskLevel.medium,
        category: RiskCategory.pressure,
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        patientId: _currentPatientId!,
        isViewed: true,
        recommendationTitle: 'Check Footwear',
        recommendationDescription: 'Inspect shoes for uneven wear',
        instructions: 'Inspect your shoes for wear. Consider diabetic-friendly footwear with proper cushioning.',
      ),
      SmartAlert(
        id: '${DateTime.now().millisecondsSinceEpoch}5',
        title: 'Daily Foot Care Reminder',
        shortDescription: 'Time for your daily foot inspection',
        detailedExplanation: 
            'Regular daily foot inspections are essential for diabetic foot health.\n\n'
            'Check for cuts, blisters, redness, or swelling. Keep feet clean and moisturized.',
        riskLevel: RiskLevel.low,
        category: RiskCategory.general,
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        patientId: _currentPatientId!,
        isViewed: true,
        isResolved: true,
        recommendationTitle: 'Daily Inspection',
        recommendationDescription: 'Review your feet for any changes',
        instructions: 'Examine all areas of your feet including between toes. Use a mirror for hard-to-see areas.',
      ),
    ];

    for (var alert in samples) {
      if (!_alerts.any((a) => a.id == alert.id)) {
        _alerts.add(alert);
      }
    }
    _alerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    _saveLocalAlerts();
    notifyListeners();
  }

  /// Convert alert to JSON for local storage
  Map<String, dynamic> _alertToJson(SmartAlert alert) {
    return {
      'id': alert.id,
      'title': alert.title,
      'shortDescription': alert.shortDescription,
      'detailedExplanation': alert.detailedExplanation,
      'riskLevel': alert.riskLevel.name,
      'category': alert.category.name,
      'timestamp': alert.timestamp.toIso8601String(),
      'isViewed': alert.isViewed,
      'isResolved': alert.isResolved,
      'patientId': alert.patientId,
      'sensorReadingId': alert.sensorReadingId,
      'sensorData': alert.sensorData,
      'recommendationTitle': alert.recommendationTitle,
      'recommendationDescription': alert.recommendationDescription,
      'instructions': alert.instructions,
    };
  }

  /// Convert JSON to alert from local storage
  SmartAlert _alertFromJson(Map<String, dynamic> json) {
    return SmartAlert(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      shortDescription: json['shortDescription'] ?? '',
      detailedExplanation: json['detailedExplanation'] ?? '',
      riskLevel: RiskLevel.values.firstWhere(
        (e) => e.name == json['riskLevel'],
        orElse: () => RiskLevel.medium,
      ),
      category: RiskCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => RiskCategory.general,
      ),
      timestamp: DateTime.parse(json['timestamp']),
      isViewed: json['isViewed'] ?? false,
      isResolved: json['isResolved'] ?? false,
      patientId: json['patientId'] ?? '',
      sensorReadingId: json['sensorReadingId'],
      sensorData: json['sensorData'] != null 
          ? Map<String, dynamic>.from(json['sensorData'])
          : null,
      recommendationTitle: json['recommendationTitle'],
      recommendationDescription: json['recommendationDescription'],
      instructions: json['instructions'],
    );
  }

  @override
  void dispose() {
    _newAlertController.close();
    _bellAnimationController.close();
    super.dispose();
  }
}
