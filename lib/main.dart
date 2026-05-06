import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'app/app_theme.dart';
import 'app/routes.dart';
import 'services/notification_service.dart';
import 'services/local_notification_service.dart';
import 'features/sensor_alerts/alert_service.dart';
import 'services/bluetooth_service.dart';
import 'features/patient/risk_explanation_screen.dart';

/// Handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint(' Background message: ${message.notification?.title}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env file so dotenv.env[...] works throughout the app
  await dotenv.load(fileName: 'assets/env.txt');

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Set up FCM background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // On iOS simulator APNs is not available, so Firebase Phone Auth
    // must fall back to reCAPTCHA. Setting appVerificationDisabledForTesting
    // to true in DEBUG mode bypasses both APNs and reCAPTCHA so phone
    // verification works on the simulator with Firebase test phone numbers.
    if (kDebugMode) {
      await FirebaseAuth.instance.setSettings(
        appVerificationDisabledForTesting: true,
      );
      debugPrint(
        '⚠️  Phone auth verification disabled for testing (debug mode)',
      );
    }

    // Save FCM token if user is already signed in
    if (FirebaseAuth.instance.currentUser != null) {
      await NotificationService().saveFCMToken();
    }

    // Initialize native local notifications
    await LocalNotificationService().initialize();

    // Show native notification for FCM messages received while app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        LocalNotificationService().show(
          title: notification.title ?? '',
          body: notification.body ?? '',
          type: message.data['type'] as String?,
        );
      }
    });

    // Handle notification tap when app was in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('🔔 Notification tapped (background): ${message.data}');
      _navigateToLatestAlert(message.data['type'] as String?);
    });

    // Check if app was opened from a terminated state via notification
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      debugPrint(
        '🔔 App opened from notification (terminated): ${initialMessage.data}',
      );
      _navigateToLatestAlert(initialMessage.data['type'] as String?);
    }

    // Handle local notification taps (risk alerts sent while app was in background)
    LocalNotificationService().onNotificationTap.listen((payload) {
      debugPrint('🔔 Local notification tapped: $payload');
      _navigateToLatestAlert(payload);
    });

    runApp(const KhotaaApp());
  } catch (e, stackTrace) {
    debugPrint('Firebase initialization error: $e');
    debugPrint('Stack trace: $stackTrace');
    runApp(ErrorApp(error: e.toString()));
  }
}

/// Navigate to the latest risk alert screen when a notification is tapped.
/// Works for both local notifications and FCM background notifications.
void _navigateToLatestAlert(String? type) {
  if (!LocalNotificationService.riskAlertTypes.contains(type)) return;

  // Wait briefly to ensure the navigator is ready (for terminated state)
  Future.delayed(const Duration(milliseconds: 500), () {
    final nav = AppRoutes.navigatorKey.currentState;
    if (nav == null) return;

    // Get the most recent health alert from AlertService
    final alerts = AlertService().alerts;
    if (alerts.isEmpty) return;

    final latestAlert = alerts.first; // Already sorted newest-first
    nav.push(
      MaterialPageRoute(
        builder: (_) => RiskExplanationScreen(alert: latestAlert),
      ),
    );
  });
}

class ErrorApp extends StatelessWidget {
  final String error;
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.red[100],
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Error: $error',
              style: const TextStyle(color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class KhotaaApp extends StatelessWidget {
  const KhotaaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<BluetoothService>(
      create: (_) => BluetoothService(),
      child: MaterialApp(
        title: 'KHOTAA',
        debugShowCheckedModeBanner: false,
        navigatorKey: AppRoutes.navigatorKey,
        theme: AppTheme.lightTheme,
        initialRoute: AppRoutes.splash,
        routes: AppRoutes.routes,
      ),
    );
  }
}
