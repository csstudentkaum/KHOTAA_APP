import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../services/expert_system/expert_system.dart';
import '../../../services/firebase/insole_realtime_service.dart';
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
  final InsoleRealtimeService _insoleService = InsoleRealtimeService();

  Timer? _sensorTimer;
  StreamSubscription<InsoleSnapshot>? _insoleSubscription;
  bool _isMonitoring = false;
  BuildContext? _dialogContext;

  // Current sensor readings
  double _temperature = 32.5;
  double _pressure = 65.0;
  int _stepsToday = 4523;
  Duration _wearingDuration = const Duration(hours: 3, minutes: 45);

  // Foot sensor data — 8 regions
  // Left  = real ESP32 data via Firebase (updated by _onInsoleData)
  // Right = simulated, kept in matching temperature range
  List<double> _leftFootPressure = [0.185, 0.258, 0.252, 0.235, 0.242, 0.155, 0.110, 0.146];
  List<double> _rightFootPressure = [0.18, 0.25, 0.24, 0.22, 0.23, 0.15, 0.11, 0.14];
  List<double> _leftFootTemp = [26.6, 26.98, 26.98, 26.93, 26.62, 24.95, 27.12, 27.81];
  List<double> _rightFootTemp = [26.5, 26.8, 27.0, 26.7, 26.9, 25.1, 27.0, 27.6];

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

    // Start Firebase insole listener — updates left foot with real ESP32 data
    _insoleService.start();
    _insoleSubscription = _insoleService.stream.listen(_onInsoleData);

    // Timer drives right-foot simulation + expert system every 3 s
    _sensorTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _updateSensorData();
    });

    debugPrint('📡 Sensor monitoring started (left=ESP32, right=simulated)');
  }

  /// Stop monitoring
  void stopMonitoring() {
    _sensorTimer?.cancel();
    _insoleSubscription?.cancel();
    _insoleService.stop();
    _isMonitoring = false;
    debugPrint('📡 Sensor monitoring stopped');
  }

  /// Called every time the ESP32 pushes a new window to Firebase (~5 s).
  /// Updates left foot arrays; expert system picks them up on the next timer tick.
  void _onInsoleData(InsoleSnapshot snap) {
    // Normalize kPa → 0–1 for heatmap display.
    // _checkForAbnormalReadings multiplies back by 300 to get kPa.
    _leftFootPressure =
        snap.pressureKpa.map((kpa) => kpa / 300.0).toList();
    _leftFootTemp = List<double>.from(snap.temperatureC);

    // Update headline display values
    _temperature = snap.temperatureC.reduce(max);
    _pressure = snap.pressureKpa.reduce(max);

    notifyListeners();
  }

  /// Timer callback — simulates right foot and runs expert system.
  /// Left foot is updated separately by _onInsoleData() from Firebase.
  void _updateSensorData() async {
    final random = Random();
    _stepsToday += random.nextInt(15);

    // Right foot — simulated in realistic diabetic range (25–28°C, normal pressure)
    for (int i = 0; i < 8; i++) {
      _rightFootPressure[i] = (0.1 + random.nextDouble() * 0.5).clamp(0.0, 1.0);
      _rightFootTemp[i] = 25.0 + random.nextDouble() * 3.0;
    }

    await _checkForAbnormalReadings();
    notifyListeners();
  }

  /// Check for abnormal readings using expert system
  Future<void> _checkForAbnormalReadings() async {
    // ── Pressure: find peak region across both feet ──────────────────
    final leftMaxPressure  = _leftFootPressure.reduce(max);
    final rightMaxPressure = _rightFootPressure.reduce(max);
    final footSide = leftMaxPressure > rightMaxPressure ? 'left' : 'right';
    final maxPressure = max(leftMaxPressure, rightMaxPressure) * 300; // → kPa
    final maxPressureIndex = footSide == 'left'
        ? _leftFootPressure.indexOf(leftMaxPressure)
        : _rightFootPressure.indexOf(rightMaxPressure);
    final pressureRegion = _indexToRegion(maxPressureIndex);

    final leftMaxTemp  = _leftFootTemp.reduce(max);
    final rightMaxTemp = _rightFootTemp.reduce(max);
    final sensorRegion = pressureRegion;

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
      case 0: return SensorRegion.metatarsal1;
      case 1: return SensorRegion.metatarsal2;
      case 2: return SensorRegion.metatarsal3;
      case 3: return SensorRegion.metatarsal4;
      case 4: return SensorRegion.metatarsal5;
      case 5: return SensorRegion.hallux;
      case 6: return SensorRegion.lateralMidfoot;
      case 7: return SensorRegion.heel;
      default: return SensorRegion.metatarsal1;
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
