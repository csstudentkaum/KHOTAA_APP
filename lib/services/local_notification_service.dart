import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Service for showing native OS notifications (banners, lock screen, etc.)
/// using flutter_local_notifications.
class LocalNotificationService {
  static final LocalNotificationService _instance =
      LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Initialize the plugin. Call once at app startup.
  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone data
    tz.initializeTimeZones();

    // Android settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS / macOS settings
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions on iOS
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    // Request permissions on Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    _initialized = true;
    debugPrint('✅ Local notifications initialized');
  }

  /// Show a native notification.
  Future<void> show({
    required String title,
    required String body,
    String? type,
    Map<String, dynamic>? payload,
  }) async {
    if (!_initialized) {
      debugPrint('⚠️ Local notifications not initialized, skipping');
      return;
    }

    // Pick channel based on type
    final isRiskAlert =
        type == 'high_pressure' ||
        type == 'elevated_pressure' ||
        type == 'abnormal_temperature' ||
        type == 'elevated_temperature';

    final androidDetails = AndroidNotificationDetails(
      isRiskAlert ? 'risk_alerts' : 'general',
      isRiskAlert ? 'Risk Alerts' : 'General Notifications',
      channelDescription: isRiskAlert
          ? 'Alerts for abnormal temperature and pressure readings'
          : 'Booking updates and general notifications',
      importance: isRiskAlert ? Importance.high : Importance.defaultImportance,
      priority: isRiskAlert ? Priority.high : Priority.defaultPriority,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(
        isRiskAlert ? 'alert_sound' : 'notification_sound',
      ),
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    final darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: isRiskAlert ? 'alert_sound.wav' : 'notification_sound.wav',
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    // Generate a unique ID from the current timestamp
    final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);

    await _plugin.show(id, title, body, details, payload: type ?? '');

    // Play sound directly (iOS simulator doesn't play notification sounds)
    try {
      final player = AudioPlayer();
      final soundFile = isRiskAlert
          ? 'assets/sounds/alert_sound.wav'
          : 'assets/sounds/notification_sound.wav';
      await player.play(AssetSource(soundFile.replaceFirst('assets/', '')));
      // Dispose after playback
      player.onPlayerComplete.listen((_) => player.dispose());
    } catch (e) {
      debugPrint('⚠️ Could not play notification sound: $e');
    }

    debugPrint('📱 Native notification shown: $title');
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 Notification tapped: ${response.payload}');
    // Navigation is handled by the in-app listener already
  }

  /// Play the notification sound directly (works even on iOS simulator).
  /// Call this when an in-app notification arrives.
  Future<void> playSound({bool isAlert = false}) async {
    try {
      final player = AudioPlayer();
      final soundFile = isAlert
          ? 'sounds/alert_sound.wav'
          : 'sounds/notification_sound.wav';
      await player.play(AssetSource(soundFile));
      player.onPlayerComplete.listen((_) => player.dispose());
    } catch (e) {
      debugPrint('⚠️ Could not play notification sound: $e');
    }
  }

  /// Schedule a native notification at a specific time.
  /// Used for booking reminders (30 min before session).
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    if (!_initialized) {
      debugPrint('⚠️ Local notifications not initialized, skipping schedule');
      return;
    }

    // Don't schedule if the time is already in the past
    if (scheduledTime.isBefore(DateTime.now())) {
      debugPrint('⏭️ Skipping reminder — scheduled time is in the past');
      return;
    }

    final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'booking_reminders',
      'Booking Reminders',
      channelDescription: 'Reminders before your consultation sessions',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification_sound'),
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'notification_sound.wav',
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: null,
    );

    debugPrint('⏰ Reminder scheduled for $scheduledTime: $title');
  }

  /// Cancel a scheduled notification by ID.
  Future<void> cancelReminder(int id) async {
    await _plugin.cancel(id);
    debugPrint('🚫 Reminder cancelled: $id');
  }
}
