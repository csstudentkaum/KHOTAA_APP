import 'package:flutter/material.dart';
import '../../shared/widgets/bottom_nav_bar.dart';
import 'home_screen.dart';
import 'ai_doctor_screen.dart';
import 'connect_insole_screen.dart';
import 'appointment_screen.dart';
import 'profile_screen.dart';

/// Patient shell — holds bottom navigation and the five tab screens.
class PatientShell extends StatefulWidget {
  const PatientShell({super.key});

  @override
  State<PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<PatientShell> {
  int _tab = 0;

  static const _screens = <Widget>[
    HomeScreen(),
    AiDoctorScreen(),
    ConnectInsoleScreen(),
    AppointmentScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: _screens),
      bottomNavigationBar: KhotaaBottomNav(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}
