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
  // Integration-test flag:
  //  true  → right foot is pinned to a healthy-skin baseline (31°C, 0 pressure)
  //          so any alert is driven ONLY by real Wokwi / insole input.
  //  false → right foot is randomly simulated (legacy demo behaviour).
  // Flip to false once a bilateral insole is available.
  //
  // Baseline chosen to match the left-foot NTC baseline in Wokwi diagram
  // (~30–31.8 °C per region). Normal dorsal foot skin = 29–33 °C.
  // Asymmetry (>=2.2 °C, IWGDF 2023) will fire only when a left NTC is
  // intentionally raised above ~33 °C in Wokwi.
  static const bool kSimulateRightFootConstant = true;
  static const double kRightFootIdleTempC = 31.0;
  static const double kRightFootIdlePressureNorm = 0.0;

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

  // Rolling pressure windows — 40 samples × 3 s ≈ 2-min average to filter step spikes
  static const int _pressureWindowSize = 40;
  final List<List<double>> _leftPressureWindow  = [];
  final List<List<double>> _rightPressureWindow = [];

  // Temperature persistence — require 5 consecutive asymmetric readings before alerting
  static const int _tempStreakRequired = 5;
  int _tempAlertStreak = 0;

  // ── Insole liveness tracking ─────────────────────────────────────────────
  // ESP32 pushes every ~5 s, but Wi-Fi + HTTPS handshakes can delay a window.
  // 45 s gives ~9× the normal cadence before we call it offline, which avoids
  // false "Offline" flashes while the insole is actually still running.
  static const Duration kInsoleStaleAfter = Duration(seconds: 45);
  DateTime? _lastInsoleUpdate;
  Timer? _livenessTimer;

  /// `true` if a real ESP32 snapshot arrived within [kInsoleStaleAfter].
  bool get isLeftFootLive {
    final t = _lastInsoleUpdate;
    if (t == null) return false;
    return DateTime.now().difference(t) < kInsoleStaleAfter;
  }

  /// Seconds since the last real insole push (null if never received).
  int? get secondsSinceLastInsoleUpdate {
    final t = _lastInsoleUpdate;
    if (t == null) return null;
    return DateTime.now().difference(t).inSeconds;
  }

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

    // Liveness ticker — refreshes UI every 5 s so 'offline' state appears
    // automatically when ESP32 stops sending (even without new data).
    _livenessTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      notifyListeners();
    });

    debugPrint('📡 Sensor monitoring started (left=ESP32, right=simulated)');
  }

  /// Stop monitoring
  void stopMonitoring() {
    _sensorTimer?.cancel();
    _livenessTimer?.cancel();
    _insoleSubscription?.cancel();
    _insoleService.stop();
    _isMonitoring = false;
    debugPrint('📡 Sensor monitoring stopped');
  }

  /// Called every time the ESP32 pushes a new window to Firebase (~5 s).
  /// Updates left foot arrays; expert system picks them up on the next timer tick.
  void _onInsoleData(InsoleSnapshot snap) {
    _lastInsoleUpdate = DateTime.now();
    // Normalize kPa → 0–1 for heatmap display.
    // _checkForAbnormalReadings multiplies back by 300 to get kPa.
    _leftFootPressure =
        snap.pressureKpa.map((kpa) => kpa / 300.0).toList();
    _leftFootTemp = List<double>.from(snap.temperatureC);

    debugPrint('✅ ESP32 data received at ${snap.receivedAt.toIso8601String()}');
    debugPrint('   Pressure kPa: ${snap.pressureKpa.map((v) => v.toStringAsFixed(1)).toList()}');
    debugPrint('   Temp °C:      ${snap.temperatureC.map((v) => v.toStringAsFixed(1)).toList()}');

    // Clear stale default values so the rolling average reflects real data immediately.
    if (_leftPressureWindow.isEmpty ||
        _leftPressureWindow.last != _leftFootPressure) {
      _leftPressureWindow.clear();
    }

    // Update headline display values — average across all regions
    _temperature = snap.temperatureC.reduce((a, b) => a + b) / snap.temperatureC.length;
    _pressure = snap.pressureKpa.reduce((a, b) => a + b) / snap.pressureKpa.length;

    notifyListeners();
  }

  /// Timer callback — simulates right foot and runs expert system.
  /// Left foot is updated separately by _onInsoleData() from Firebase.
  void _updateSensorData() async {
    final random = Random();
    _stepsToday += random.nextInt(15);

    // Right foot — either pinned constant (integration test) or randomly simulated.
    if (kSimulateRightFootConstant) {
      for (int i = 0; i < 8; i++) {
        _rightFootPressure[i] = kRightFootIdlePressureNorm;
        _rightFootTemp[i] = kRightFootIdleTempC;
      }
    } else {
      for (int i = 0; i < 8; i++) {
        _rightFootPressure[i] = (0.1 + random.nextDouble() * 0.5).clamp(0.0, 1.0);
        _rightFootTemp[i] = 25.5 + random.nextDouble() * 1.0;
      }
    }

    // Gate the expert system on insole liveness.
    // When the ESP32 is offline, stale left-foot readings would otherwise keep
    // firing HIGH_PRESSURE / TEMP_ASYMMETRY alerts for up to 2 minutes (the
    // rolling-window length). Clearing state here ensures alerts stop within
    // one tick of disconnection and cannot resurrect on reconnect with stale
    // history.
    if (!isLeftFootLive) {
      _leftPressureWindow.clear();
      _rightPressureWindow.clear();
      _tempAlertStreak = 0;
      if (_hasAbnormalReading || _lastResult != null) {
        _hasAbnormalReading = false;
        _abnormalType = '';
        _lastResult = null;
      }
      notifyListeners();
      return;
    }

    await _checkForAbnormalReadings();
    notifyListeners();
  }

  /// Check for abnormal readings using expert system
  Future<void> _checkForAbnormalReadings() async {
    // ── Rolling pressure window — snapshot current readings ───────────────────
    _leftPressureWindow.add(List<double>.from(_leftFootPressure));
    if (_leftPressureWindow.length > _pressureWindowSize) _leftPressureWindow.removeAt(0);
    _rightPressureWindow.add(List<double>.from(_rightFootPressure));
    if (_rightPressureWindow.length > _pressureWindowSize) _rightPressureWindow.removeAt(0);

    // ── Pressure: 2-min rolling average per region (filters single-step spikes) ─
    final avgLeft  = List<double>.filled(8, 0.0);
    final avgRight = List<double>.filled(8, 0.0);
    for (final s in _leftPressureWindow) {
      for (int i = 0; i < 8; i++) avgLeft[i]  += s[i];
    }
    for (final s in _rightPressureWindow) {
      for (int i = 0; i < 8; i++) avgRight[i] += s[i];
    }
    for (int i = 0; i < 8; i++) {
      avgLeft[i]  /= _leftPressureWindow.length;
      avgRight[i] /= _rightPressureWindow.length;
    }
    final leftMaxPressure  = avgLeft.reduce(max);
    final rightMaxPressure = avgRight.reduce(max);
    final footSide = leftMaxPressure > rightMaxPressure ? 'left' : 'right';
    final maxPressure = max(leftMaxPressure, rightMaxPressure) * 300; // → kPa
    final maxPressureIndex = footSide == 'left'
        ? avgLeft.indexOf(leftMaxPressure)
        : avgRight.indexOf(rightMaxPressure);
    final pressureRegion = _indexToRegion(maxPressureIndex);

    // ── Temperature: per-region comparison (IWGDF 2023 / Armstrong 2007) ──────
    final int regionCount = min(_leftFootTemp.length, _rightFootTemp.length);
    double worstTempDiff  = 0.0;
    int    worstTempIndex = 0;
    for (int i = 0; i < regionCount; i++) {
      final diff = (_leftFootTemp[i] - _rightFootTemp[i]).abs();
      if (diff > worstTempDiff) {
        worstTempDiff  = diff;
        worstTempIndex = i;
      }
    }

    // Persistence check — only alert after 5 consecutive asymmetric readings (~15 s)
    if (worstTempDiff >= KnowledgeBase.temperatureDifferenceThreshold) {
      _tempAlertStreak++;
    } else {
      _tempAlertStreak = 0;
    }
    final bool tempPersistent = _tempAlertStreak >= _tempStreakRequired;

    final double leftRegionTemp  = _leftFootTemp[worstTempIndex];
    final double rightRegionTemp = _rightFootTemp[worstTempIndex];
    final SensorRegion tempRegion = _indexToRegion(worstTempIndex);
    // footSide for temperature = whichever foot is hotter at the worst region
    final String tempFootSide = leftRegionTemp >= rightRegionTemp ? 'left' : 'right';
    final dominantRegion = tempPersistent ? tempRegion : pressureRegion;
    final String dominantFootSide = tempPersistent ? tempFootSide : footSide;

    try {
      final result = await _expertSystem.processSensorData(
        // Pass equal temps when asymmetry hasn't persisted — single spike won't alert
        leftFootTemperature: tempPersistent ? leftRegionTemp : rightRegionTemp,
        rightFootTemperature: rightRegionTemp,
        plantarPressure: maxPressure,
        pressureBaseline: 150.0,
        sensorRegion: dominantRegion,
        footSide: dominantFootSide,
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
