import 'dart:async';
import 'package:flutter/material.dart';
import '../../shared/in_app_notification_popup.dart';
import '../../shared/widgets/bottom_nav_bar.dart';
import '../../services/local_notification_service.dart';
import 'patient_home_page.dart';
import 'ai_doctor_screen.dart';
import 'connect_insole_screen.dart';
import 'booking/all_doctors_screen.dart';
import 'profile_screen.dart';
import 'medical_faq_chatbot_screen.dart';
import 'preventive_recommendations_screen.dart';
import 'services/sensor_data_service.dart';

/// Patient shell - bottom tabs holder for patient app
/// Also starts global sensor monitoring for alerts/notifications
class PatientShell extends StatefulWidget {
  const PatientShell({super.key});

  @override
  State<PatientShell> createState() => PatientShellState();
}

class PatientShellState extends State<PatientShell> {
  int _tab = 0;
  final GlobalKey<AllDoctorsScreenState> _allDoctorsKey = GlobalKey();
  final SensorDataService _sensorService = SensorDataService();
  StreamSubscription<String>? _notificationTapSub;

  /// Allows child widgets to switch the active tab.
  void switchToTab(int index) {
    setState(() => _tab = index);
  }

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const PatientHomePage(),
      const AiDoctorScreen(),
      const ConnectInsoleScreen(),
      AllDoctorsScreen(key: _allDoctorsKey),
      const ProfileScreen(),
    ];

    // Set global dialog context and start sensor monitoring
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _sensorService.setDialogContext(context);
        _sensorService.startMonitoring();
      }
    });

    // Listen for notification taps to navigate to appropriate screen
    _notificationTapSub = LocalNotificationService().onNotificationTap.listen(
      _handleNotificationTap,
    );
  }

  void _handleNotificationTap(String payload) {
    debugPrint('📱 Notification tapped with payload: $payload');
    // Navigate to Preventive Tips screen when notification is tapped
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const PreventiveRecommendationsScreen(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _notificationTapSub?.cancel();
    // Don't stop monitoring here — SensorDataService is a singleton that
    // outlives PatientShell. Stopping it on every dispose (e.g. Chrome
    // re-renders) kills the demo cycle. Monitoring is stopped explicitly
    // on logout via profile screen.
    _sensorService.clearDialogContext();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InAppNotificationListener(
      child: PopScope(
        canPop: _tab == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            setState(() => _tab = 0);
          }
        },
        child: Scaffold(
          body: IndexedStack(index: _tab, children: _screens),
          floatingActionButton: _tab == 1
              ? Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: FloatingActionButton(
                    mini: true,
                    backgroundColor: const Color(0xFF64ADB3),
                    elevation: 4,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MedicalFaqChatbotScreen(),
                      ),
                    ),
                    child: const Icon(
                      Icons.smart_toy_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                )
              : null,
          bottomNavigationBar: KhotaaBottomNav(
            currentIndex: _tab,
            onTap: (i) {
              setState(() => _tab = i);
            },
          ),
        ),
      ),
    );
  }
}
