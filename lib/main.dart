import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'app/app_theme.dart';
import 'app/routes.dart';
import 'services/notification_service.dart';
import 'services/local_notification_service.dart';

/// Handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint(' Background message: ${message.notification?.title}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

    runApp(const KhotaaApp());
  } catch (e, stackTrace) {
    debugPrint('Firebase initialization error: $e');
    debugPrint('Stack trace: $stackTrace');
    runApp(ErrorApp(error: e.toString()));
  }
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
    return MaterialApp(
      title: 'KHOTAA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.splash,
      routes: AppRoutes.routes,
    );
  }
}
