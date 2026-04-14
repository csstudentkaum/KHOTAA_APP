import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../services/expert_system/expert_system.dart';
import '../../sensor_alerts/sensor_alert_handler.dart';

/// Shared sensor data service - Single source of truth for all sensor readings
/// Used by both Dashboard (for UI) and Alert system (for notifications)
/// TODO: Replace simulation with real sensor data from your platform
class SensorDataService extends ChangeNotifier {
  static final SensorDataService _instance = SensorDataService._internal();
  factory SensorDataService() => _instance;
  SensorDataService._internal();

  final ExpertSystemIntegration _expertSystem = ExpertSystemIntegration();
  final SensorAlertHandler _notificationService = SensorAlertHandler();
  
  Timer? _sensorTimer;
  bool _isMonitoring = false;
  BuildContext? _dialogContext;

  // Current sensor readings
  double _temperature = 32.5;
  double _pressure = 65.0;
  int _stepsToday = 4523;
  Duration _wearingDuration = const Duration(hours: 3, minutes: 45);

  // Foot sensor data
  List<double> _leftFootPressure = [0.3, 0.5, 0.7, 0.4, 0.6];
  List<double> _rightFootPressure = [0.4, 0.3, 0.5, 0.8, 0.4];
  List<double> _leftFootTemp = [32.0, 32.5, 33.0, 32.2, 32.8];
  List<double> _rightFootTemp = [32.3, 32.1, 32.8, 33.5, 32.5];

  // Risk status
  bool _hasAbnormalReading = false;
  String _abnormalType = '';
  ExpertSystemResult? _lastResult;

  // Getters
  double get temperature => _temperature;
  double get pressure => _pressure;
  int get stepsToday => _stepsToday;
  Duration get wearingDuration => _wearingDuration;
  List<double> get leftFootPressure => _leftFootPressure;
  List<double> get rightFootPressure => _rightFootPressure;
  List<double> get leftFootTemp => _leftFootTemp;
  List<double> get rightFootTemp => _rightFootTemp;
  bool get hasAbnormalReading => _hasAbnormalReading;
  String get abnormalType => _abnormalType;
  ExpertSystemResult? get lastResult => _lastResult;
  bool get isMonitoring => _isMonitoring;

  /// Set dialog context for showing alerts
  void setDialogContext(BuildContext context) {
    _dialogContext = context;
    _notificationService.setDialogContext(context);
  }

  /// Clear dialog context
  void clearDialogContext() {
    _dialogContext = null;
    _notificationService.clearDialogContext();
  }

  /// Start monitoring sensors - call this when patient enters the app
  void startMonitoring() {
    if (_isMonitoring) return;
    _isMonitoring = true;
    
    _sensorTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _updateSensorData();
    });
    
    debugPrint('📡 Sensor monitoring started');
  }

  /// Stop monitoring
  void stopMonitoring() {
    _sensorTimer?.cancel();
    _isMonitoring = false;
    debugPrint('📡 Sensor monitoring stopped');
  }

  /// Update sensor data and check for risks
  /// TODO: Replace this simulation with real sensor data from your platform
  void _updateSensorData() async {
    final random = Random();
    
    // Simulate sensor values
    _temperature = 34.0 + random.nextDouble() * 2.0;
    _pressure = 200 + random.nextDouble() * 100;
    _stepsToday += random.nextInt(15);

    // ────────────────────────────────────────────────────────────────────
    // TESTING MODES - Change these to test different scenarios:
    // ────────────────────────────────────────────────────────────────────
    // Mode 1: NOTIFICATION (MODERATE) - High pressure ONLY
    //         Pressure: ≥200 kPa, Temp difference: <2.2°C
    //
    // Mode 2: ALERT (HIGH) - Both high pressure AND temp asymmetry
    //         Pressure: ≥200 kPa, Temp difference: ≥2.2°C
    //
    // Mode 3: NORMAL - No notifications
    //         Pressure: <200 kPa, Temp difference: <2.2°C
    // ────────────────────────────────────────────────────────────────────
    
    // Current mode: NOTIFICATION (high pressure only, no temp asymmetry)
    for (int i = 0; i < 5; i++) {
      // High pressure to trigger notification
      _leftFootPressure[i] = (0.7 + random.nextDouble() * 0.3).clamp(0.0, 1.0);
      _rightFootPressure[i] = (0.7 + random.nextDouble() * 0.3).clamp(0.0, 1.0);
      
      // Similar temperatures (difference < 2.2°C) - NO temp asymmetry
      _leftFootTemp[i] = 33.0 + random.nextDouble() * 0.5;
      _rightFootTemp[i] = 33.5 + random.nextDouble() * 0.5;
    }

    // Process through expert system
    await _checkForAbnormalReadings();
    
    notifyListeners();
  }

  /// Check for abnormal readings using expert system
  Future<void> _checkForAbnormalReadings() async {
    final leftMaxTemp = _leftFootTemp.reduce(max);
    final rightMaxTemp = _rightFootTemp.reduce(max);
    final maxPressureIndex = _leftFootPressure.indexOf(_leftFootPressure.reduce(max));
    final maxPressure = [..._leftFootPressure, ..._rightFootPressure].reduce(max) * 300;
    
    // Determine which foot has higher pressure
    final leftMaxPressure = _leftFootPressure.reduce(max);
    final rightMaxPressure = _rightFootPressure.reduce(max);
    final footSide = leftMaxPressure > rightMaxPressure ? 'left' : 'right';
    
    // Map pressure index to sensor region
    final sensorRegion = _indexToRegion(maxPressureIndex);

    try {
      final result = await _expertSystem.processSensorData(
        leftFootTemperature: leftMaxTemp,
        rightFootTemperature: rightMaxTemp,
        plantarPressure: maxPressure,
        pressureBaseline: 150.0,
        sensorRegion: sensorRegion,
        footSide: footSide,
      );

      _lastResult = result;
      _hasAbnormalReading = result.hasRisk;

      if (result.hasRisk) {
        final hasTemp = result.triggeredRules.any(
          (r) => r.type == RuleType.temperatureAsymmetry,
        );
        final hasPressure = result.triggeredRules.any(
          (r) => r.type == RuleType.elevatedPressure || 
                 r.type == RuleType.pressureAboveBaseline,
        );
        final hasCombined = result.triggeredRules.any(
          (r) => r.type == RuleType.combinedRisk,
        );

        if (hasCombined || (hasTemp && hasPressure)) {
          _abnormalType = 'both';
        } else if (hasPressure) {
          _abnormalType = 'pressure';
        } else if (hasTemp) {
          _abnormalType = 'temperature';
        } else {
          _abnormalType = 'both';
        }

        // Trigger alert/notification
        await _notificationService.handleExpertResult(result);
      } else {
        _abnormalType = '';
      }
    } catch (e) {
      debugPrint('Expert system error: $e');
    }
  }

  /// Map pressure array index to anatomical sensor region
  SensorRegion _indexToRegion(int index) {
    switch (index) {
      case 0:
        return SensorRegion.metatarsal1;
      case 1:
        return SensorRegion.metatarsal2;
      case 2:
        return SensorRegion.metatarsal3;
      case 3:
        return SensorRegion.metatarsal4;
      case 4:
        return SensorRegion.heel;
      default:
        return SensorRegion.metatarsal1;
    }
  }

  /// Increment wearing duration (call from timer)
  void incrementWearingDuration() {
    _wearingDuration += const Duration(minutes: 1);
    notifyListeners();
  }

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}
