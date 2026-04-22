import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

// ── Insole snapshot ───────────────────────────────────────────────────────────
/// Holds one averaged window from the ESP32 insole.
/// pressureKpa  — 8 values in kPa (already converted by Wokwi toKpa())
/// temperatureC — 8 values in °C
/// Regions order matches ESP32 REGIONS[] array (Niemann 2016):
///   0=MTK1  1=MTK2  2=MTK3  3=MTK4  4=MTK5  5=D1  6=L  7=C
class InsoleSnapshot {
  final List<double> pressureKpa;
  final List<double> temperatureC;
  final DateTime receivedAt;

  const InsoleSnapshot({
    required this.pressureKpa,
    required this.temperatureC,
    required this.receivedAt,
  });
}

// ── Service ───────────────────────────────────────────────────────────────────
/// Listens to Firebase Realtime Database path:
///   /readings/{uid}/latest
/// and emits [InsoleSnapshot] every time the ESP32 pushes a new window (≈5 s).
///
/// Usage:
///   InsoleRealtimeService().start();
///   InsoleRealtimeService().stream.listen((snap) { ... });
///   InsoleRealtimeService().stop();
class InsoleRealtimeService {
  // Singleton
  static final InsoleRealtimeService _instance =
      InsoleRealtimeService._internal();
  factory InsoleRealtimeService() => _instance;
  InsoleRealtimeService._internal();

  StreamSubscription<DatabaseEvent>? _subscription;
  final StreamController<InsoleSnapshot> _controller =
      StreamController<InsoleSnapshot>.broadcast();

  /// Latest snapshot received — null until first Firebase push arrives.
  InsoleSnapshot? _latest;
  InsoleSnapshot? get latest => _latest;

  /// Broadcast stream of insole snapshots.
  Stream<InsoleSnapshot> get stream => _controller.stream;

  // ESP32 JSON key order — must match REGIONS[] in the sketch
  static const List<String> _keys = [
    'MTK1_metatarsal1',
    'MTK2_metatarsal2',
    'MTK3_metatarsal3',
    'MTK4_metatarsal4',
    'MTK5_metatarsal5',
    'D1_hallux',
    'L_lateral',
    'C_calcaneus',
  ];

  /// Start listening. Requires a logged-in Firebase user.
  void start() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('InsoleRealtimeService: no authenticated user — skipping');
      return;
    }

    final ref = FirebaseDatabase.instance.ref('readings/$uid/latest');

    _subscription = ref.onValue.listen(
      (DatabaseEvent event) {
        final raw = event.snapshot.value;
        if (raw == null) return;

        try {
          final map = Map<String, dynamic>.from(raw as Map);
          final pressureRaw =
              Map<String, dynamic>.from(map['pressure'] as Map);
          final tempRaw =
              Map<String, dynamic>.from(map['temperature'] as Map);

          // Parse in fixed region order
          final pressures = _keys
              .map((k) => (pressureRaw[k] as num?)?.toDouble() ?? 0.0)
              .toList();
          final temps = _keys
              .map((k) => (tempRaw[k] as num?)?.toDouble() ?? 26.0)
              .toList();

          final snap = InsoleSnapshot(
            pressureKpa: pressures,
            temperatureC: temps,
            receivedAt: DateTime.now(),
          );

          _latest = snap;
          _controller.add(snap);

          debugPrint(
            'InsoleRealtimeService: received window — '
            'peak ${pressures.reduce((a, b) => a > b ? a : b).toStringAsFixed(1)} kPa  '
            'hot ${temps.reduce((a, b) => a > b ? a : b).toStringAsFixed(1)}°C',
          );
        } catch (e) {
          debugPrint('InsoleRealtimeService: parse error — $e');
        }
      },
      onError: (Object e) {
        debugPrint('InsoleRealtimeService: stream error — $e');
      },
    );

    debugPrint('InsoleRealtimeService: listening to /readings/$uid/latest');
  }

  /// Stop listening and release resources.
  void stop() {
    _subscription?.cancel();
    _subscription = null;
    debugPrint('InsoleRealtimeService: stopped');
  }
}
