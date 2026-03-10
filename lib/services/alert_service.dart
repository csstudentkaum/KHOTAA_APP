import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/smart_alert.dart';

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
  
  // Unread count - Only count health alerts (matching Smart Insole notifications)
  int get unreadCount => _alerts
      .where((a) => !a.isViewed && a.notificationType == NotificationType.health)
      .length;
  
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
  
  // Flag to use sample data only (no Firestore)
  bool _useSampleDataOnly = false;
  
  // Firestore subscription
  StreamSubscription? _firestoreSubscription;

  /// Initialize the service for a patient
  Future<void> initialize(String patientId) async {
    _currentPatientId = patientId;
    await _clearOldCacheIfNeeded();
    await _loadLocalAlerts();
    _listenToFirestoreAlerts();
  }

  /// Clear old cache when version changes (to fix corrupted data)
  Future<void> _clearOldCacheIfNeeded() async {
    const currentVersion = 3; // Increment this when changing alert structure
    final prefs = await SharedPreferences.getInstance();
    final savedVersion = prefs.getInt('alerts_cache_version_$_currentPatientId') ?? 0;
    
    if (savedVersion < currentVersion) {
      // Clear old cache completely
      await prefs.remove('smart_alerts_$_currentPatientId');
      await prefs.setInt('alerts_cache_version_$_currentPatientId', currentVersion);
      debugPrint('Cleared old alerts cache (version $savedVersion -> $currentVersion)');
    }
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

    try {
      _firestoreSubscription = _firestore
          .collection('alerts')
          .where('patientId', isEqualTo: _currentPatientId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots()
          .listen(
        (snapshot) {
          // Skip if using sample data only
          if (_useSampleDataOnly) return;
          
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final alert = SmartAlert.fromFirestore(change.doc);
              if (!_alerts.any((a) => a.id == alert.id)) {
                _addAlert(alert);
              }
            }
          }
        },
        onError: (error) {
          // Handle Firestore errors gracefully (e.g., missing index)
          debugPrint('Firestore listener error: $error');
        },
      );
    } catch (e) {
      debugPrint('Error setting up Firestore listener: $e');
    }
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
    debugPrint('AlertService: markAsViewed called for alert: $alertId');
    final index = _alerts.indexWhere((a) => a.id == alertId);
    debugPrint('AlertService: Found alert at index: $index');
    if (index != -1) {
      _alerts[index] = _alerts[index].copyWith(isViewed: true);
      _saveLocalAlerts();
      debugPrint('AlertService: Alert marked as viewed, calling notifyListeners. Unread count now: $unreadCount');
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

  /// Add sample alerts for testing/demo (only once, preserves viewed state)
  Future<void> addSampleAlerts() async {
    if (_currentPatientId == null) return;

    // Enable sample data mode - ignore Firestore updates
    _useSampleDataOnly = true;
    
    // Check if sample alerts were already added (don't reset if they exist)
    final hasExistingSamples = _alerts.any((a) => a.id.startsWith('sample_'));
    if (hasExistingSamples) {
      debugPrint('AlertService: Sample alerts already exist, skipping (preserving viewed state)');
      return;
    }

    // Define sample alerts with proper notificationType
    // 2 unread health alerts, 1 read health alert
    // 2 read appointment alerts
    final samples = [
      SmartAlert(
        id: 'sample_health_pressure_001',
        title: 'High Pressure Alert',
        shortDescription: 'Excessive pressure on left foot heel',
        detailedExplanation: 
            'Your smart insole has detected high pressure (265 kPa) on your left foot '
            'in the heel region.\n\n'
            'Prolonged high pressure can lead to tissue damage and increase the risk '
            'of diabetic foot ulcers. Taking a break and adjusting your footwear is recommended.',
        riskLevel: RiskLevel.high,
        category: RiskCategory.pressure,
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        patientId: _currentPatientId!,
        notificationType: NotificationType.health,
        recommendationTitle: 'Reduce Standing Time',
        recommendationDescription: 'Rest your feet for 15-20 minutes',
        instructions: 'Sit down and elevate your feet above heart level. This helps reduce swelling and pressure.',
      ),
      SmartAlert(
        id: 'sample_health_temp_001',
        title: 'Temperature Alert',
        shortDescription: 'Elevated temperature difference detected',
        detailedExplanation: 
            'Your smart insole has detected a temperature difference of 3.1°C between feet.\n\n'
            'Temperature asymmetry >2.2°C can indicate inflammation or early ulcer risk. '
            'Applying a cool compress and monitoring is recommended.',
        riskLevel: RiskLevel.high,
        category: RiskCategory.temperature,
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        patientId: _currentPatientId!,
        notificationType: NotificationType.health,
        isViewed: true,
        recommendationTitle: 'Cool Down Your Feet',
        recommendationDescription: 'Apply cool compress for 10-15 minutes',
        instructions: 'Use a cool (not cold) compress on your foot. Avoid ice directly on skin. Monitor for changes.',
      ),
      SmartAlert(
        id: 'sample_health_pressure_002',
        title: 'Pressure Distribution Notice',
        shortDescription: 'Uneven pressure distribution detected',
        detailedExplanation: 
            'Your smart insole has detected pressure above baseline (195 kPa) on metatarsal region.\n\n'
            'This may be due to shoe wear or walking habits. Consider checking your footwear.',
        riskLevel: RiskLevel.medium,
        category: RiskCategory.pressure,
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        patientId: _currentPatientId!,
        notificationType: NotificationType.health,
        recommendationTitle: 'Check Footwear',
        recommendationDescription: 'Inspect shoes for uneven wear',
        instructions: 'Inspect your shoes for wear. Consider diabetic-friendly footwear with proper cushioning.',
      ),
      SmartAlert(
        id: 'sample_appt_001',
        title: 'Dr. Abdullah Appointment',
        shortDescription: 'Upcoming checkup on Tuesday at 09:30 AM',
        detailedExplanation: 
            'You have an appointment scheduled with Dr. Abdullah for your regular foot checkup.',
        riskLevel: RiskLevel.low,
        category: RiskCategory.general,
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        patientId: _currentPatientId!,
        notificationType: NotificationType.appointment,
        isViewed: true,
      ),
      SmartAlert(
        id: 'sample_appt_002',
        title: 'Follow-up Reminder',
        shortDescription: 'Schedule your monthly follow-up',
        detailedExplanation: 
            'Its been 4 weeks since your last checkup. Please schedule your monthly follow-up appointment.',
        riskLevel: RiskLevel.low,
        category: RiskCategory.general,
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        patientId: _currentPatientId!,
        notificationType: NotificationType.appointment,
        isViewed: true,
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
      'notificationType': alert.notificationType.name,
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
      notificationType: json['notificationType'] != null
          ? NotificationType.values.firstWhere(
              (e) => e.name == json['notificationType'],
              orElse: () => NotificationType.health,
            )
          : NotificationType.health,
    );
  }

  @override
  void dispose() {
    _firestoreSubscription?.cancel();
    _newAlertController.close();
    _bellAnimationController.close();
    super.dispose();
  }
}
