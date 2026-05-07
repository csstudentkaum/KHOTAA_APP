// Daily Sensor Summary Service
//
// Tracks PEAK values per anatomical region — not averages.
//
// Why peaks?  Averaging 8 regions kills the clinical signal.
// Example: MTK1 at 350 kPa + 7 regions at 50 kPa → average 87 kPa (looks safe!).
// IWGDF 2023 specifically flags PEAK plantar pressure ≥ 200 kPa per region.
//
// What is stored per day:
//   peakLeftPressureKpa[8]       — highest kPa seen in each left-foot region
//   peakRightPressureKpa[8]      — highest kPa seen in each right-foot region
//   peakTempAsymmetryPerRegion[8]— largest |leftTemp[i]−rightTemp[i]| per region
//
// Weekly aggregates (max across 7 days) give the doctor exactly which region
// and foot were most at risk during the week.
//
// Persists to Firestore: patients/{uid}/dailySummaries/{YYYY-MM-DD}

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../features/patient/services/sensor_data_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Region labels — index matches SensorRegion enum ordinals (0-7)
// ─────────────────────────────────────────────────────────────────────────────

const List<String> kRegionLabels = [
  'MTK1', 'MTK2', 'MTK3', 'MTK4', 'MTK5', 'Hallux', 'Mid', 'Heel',
];

// ─────────────────────────────────────────────────────────────────────────────
// Internal model
// ─────────────────────────────────────────────────────────────────────────────

class _DailySummary {
  final String date; // "YYYY-MM-DD"

  final List<double> peakLeftPressureKpa  = List.filled(8, 0.0);
  final List<double> peakRightPressureKpa = List.filled(8, 0.0);
  final List<double> peakTempAsymmetry    = List.filled(8, 0.0);

  int count = 0;

  _DailySummary({required this.date});

  void initFromStored({
    required List<double> leftPressure,
    required List<double> rightPressure,
    required List<double> asymmetry,
    required int storedCount,
  }) {
    for (int i = 0; i < 8; i++) {
      peakLeftPressureKpa[i]  = leftPressure[i];
      peakRightPressureKpa[i] = rightPressure[i];
      peakTempAsymmetry[i]    = asymmetry[i];
    }
    count = storedCount;
  }

  void addReading({
    required List<double> leftKpa,
    required List<double> rightKpa,
    required List<double> asymmetryC,
  }) {
    for (int i = 0; i < 8; i++) {
      if (leftKpa[i]    > peakLeftPressureKpa[i])  peakLeftPressureKpa[i]  = leftKpa[i];
      if (rightKpa[i]   > peakRightPressureKpa[i]) peakRightPressureKpa[i] = rightKpa[i];
      if (asymmetryC[i] > peakTempAsymmetry[i])    peakTempAsymmetry[i]    = asymmetryC[i];
    }
    count++;
  }

  double get overallPeakPressure =>
      [...peakLeftPressureKpa, ...peakRightPressureKpa].fold(0.0, max);

  double get overallPeakAsymmetry => peakTempAsymmetry.fold(0.0, max);

  /// 0 = no data · 1 = normal · 2 = moderate · 3 = high
  /// Matches KhotaaExpertSystem logic exactly:
  ///   High     = pressure ≥200 kPa AND asymmetry ≥2.2°C (combined)
  ///   Moderate = pressure ≥200 kPa OR  asymmetry ≥2.2°C (single factor)
  ///   Normal   = neither threshold exceeded
  int get riskLevel {
    if (count == 0) return 0;
    final p = overallPeakPressure;
    final a = overallPeakAsymmetry;
    final pressureRisk = p >= 200.0;
    final tempRisk     = a >= 2.2;
    if (pressureRisk && tempRisk) return 3; // combined → High
    if (pressureRisk || tempRisk) return 2; // single factor → Moderate
    return 1;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

class DailySensorSummaryService extends ChangeNotifier {
  static final DailySensorSummaryService _instance =
      DailySensorSummaryService._internal();
  factory DailySensorSummaryService() => _instance;
  DailySensorSummaryService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _patientId;
  final Map<String, _DailySummary> _summaries = {};
  static const int _saveInterval = 10;
  int _ticksSinceLastSave = 0;
  VoidCallback? _sensorListener;

  // ── Initialize ───────────────────────────────────────────────────────────

  Future<void> initialize(String patientId) async {
    if (_patientId == patientId) return;
    _patientId = patientId;
    _summaries.clear();
    _ticksSinceLastSave = 0;
    await _loadWeekFromFirestore();
    _startListening();
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// 7-element list Sun=0…Sat=6.  0=no data · 1=normal · 2=moderate · 3=high
  List<int> get weekDailyRiskLevels {
    final result    = List<int>.filled(7, 0);
    final weekStart = _currentWeekStart();
    for (int i = 0; i < 7; i++) {
      final key  = _dateKey(weekStart.add(Duration(days: i)));
      result[i]  = _summaries[key]?.riskLevel ?? 0;
    }
    return result;
  }

  /// Weekly peak per region for LEFT foot (kPa). 8 values, 0.0 = no data.
  List<double> get weeklyLeftPeakPressure =>
      _buildRegionMax((s) => s.peakLeftPressureKpa);

  /// Weekly peak per region for RIGHT foot (kPa). 8 values, 0.0 = no data.
  List<double> get weeklyRightPeakPressure =>
      _buildRegionMax((s) => s.peakRightPressureKpa);

  /// Weekly peak temperature asymmetry per region (°C). 8 values, 0.0 = no data.
  List<double> get weeklyPeakAsymmetryPerRegion =>
      _buildRegionMax((s) => s.peakTempAsymmetry);

  /// Single worst pressure across all regions/feet this week (kPa).
  double get weeklyPeakPressureKpa =>
      [...weeklyLeftPeakPressure, ...weeklyRightPeakPressure].fold(0.0, max);

  /// Single worst asymmetry across all regions this week (°C).
  double get weeklyPeakAsymmetry =>
      weeklyPeakAsymmetryPerRegion.fold(0.0, max);

  // ── Sensor listener ───────────────────────────────────────────────────────

  void _startListening() {
    if (_sensorListener != null) {
      SensorDataService().removeListener(_sensorListener!);
    }
    _sensorListener = _onSensorTick;
    SensorDataService().addListener(_sensorListener!);
  }

  void _onSensorTick() {
    final sensor = SensorDataService();
    if (!sensor.isLeftFootLive) return;

    final leftKpa  = sensor.leftFootPressure.map((n) => n * 300.0).toList();
    final rightKpa = sensor.rightFootPressure.map((n) => n * 300.0).toList();
    final rCount   = min(sensor.leftFootTemp.length, sensor.rightFootTemp.length);
    final asymmetry = List.generate(
      rCount,
      (i) => (sensor.leftFootTemp[i] - sensor.rightFootTemp[i]).abs(),
    );

    final today = _dateKey(DateTime.now());
    _summaries.putIfAbsent(today, () => _DailySummary(date: today));
    _summaries[today]!.addReading(
      leftKpa:    leftKpa,
      rightKpa:   rightKpa,
      asymmetryC: asymmetry,
    );

    _ticksSinceLastSave++;
    if (_ticksSinceLastSave >= _saveInterval) {
      _ticksSinceLastSave = 0;
      _persistToday();
    }
    notifyListeners();
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  Future<void> _loadWeekFromFirestore() async {
    if (_patientId == null) return;
    try {
      final weekStart = _currentWeekStart();
      final weekEnd   = weekStart.add(const Duration(days: 7));

      final snapshot = await _firestore
          .collection('users')
          .doc(_patientId)
          .collection('dailySummaries')
          .where('date', isGreaterThanOrEqualTo: _dateKey(weekStart))
          .where('date', isLessThan: _dateKey(weekEnd))
          .get();

      for (final doc in snapshot.docs) {
        final d    = doc.data();
        final date = d['date'] as String? ?? doc.id;
        final cnt  = (d['count'] as num?)?.toInt() ?? 0;
        if (cnt == 0) continue;

        List<double> readList(String field) {
          final raw = d[field];
          if (raw is List) return raw.map((e) => (e as num).toDouble()).toList();
          return List.filled(8, 0.0);
        }

        _summaries[date] = _DailySummary(date: date)
          ..initFromStored(
            leftPressure:  readList('peakLeftPressureKpa'),
            rightPressure: readList('peakRightPressureKpa'),
            asymmetry:     readList('peakTempAsymmetryPerRegion'),
            storedCount:   cnt,
          );
      }

      debugPrint(
        'DailySensorSummaryService: loaded ${snapshot.docs.length} day(s)',
      );
      notifyListeners();
    } catch (e) {
      debugPrint('DailySensorSummaryService: Firestore load error: $e');
    }
  }

  Future<void> _persistToday() async {
    if (_patientId == null) return;
    final today   = _dateKey(DateTime.now());
    final summary = _summaries[today];
    if (summary == null || summary.count == 0) return;

    try {
      await _firestore
          .collection('users')
          .doc(_patientId)
          .collection('dailySummaries')
          .doc(today)
          .set(
        {
          'date':                       today,
          'patientId':                  _patientId,
          'peakLeftPressureKpa':        summary.peakLeftPressureKpa,
          'peakRightPressureKpa':       summary.peakRightPressureKpa,
          'peakTempAsymmetryPerRegion': summary.peakTempAsymmetry,
          'count':                      summary.count,
          'updatedAt':                  FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      debugPrint(
        'DailySensorSummaryService: persisted $today → '
        'L-peak=${summary.peakLeftPressureKpa.fold(0.0, max).toStringAsFixed(0)} kPa · '
        'asym=${summary.peakTempAsymmetry.fold(0.0, max).toStringAsFixed(1)}°C '
        '(${summary.count} readings)',
      );
    } catch (e) {
      debugPrint('DailySensorSummaryService: Firestore save error: $e');
    }
  }

  // ── Utilities ─────────────────────────────────────────────────────────────

  /// For each of 8 regions, returns the max value seen across the whole week.
  List<double> _buildRegionMax(List<double> Function(_DailySummary) pick) {
    final result    = List<double>.filled(8, 0.0);
    final weekStart = _currentWeekStart();
    for (int i = 0; i < 7; i++) {
      final key  = _dateKey(weekStart.add(Duration(days: i)));
      final s    = _summaries[key];
      if (s == null || s.count == 0) continue;
      final vals = pick(s);
      for (int r = 0; r < 8 && r < vals.length; r++) {
        if (vals[r] > result[r]) result[r] = vals[r];
      }
    }
    return result;
  }

  static DateTime _currentWeekStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day - (now.weekday % 7));
  }

  static String _dateKey(DateTime date) =>
      '${date.year}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
