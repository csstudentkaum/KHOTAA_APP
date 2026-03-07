import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import '../../shared/in_app_notification_popup.dart';
import 'patient_home_screen.dart';
import 'booking/all_doctors_screen.dart';
import 'profile_screen.dart';

/// Patient shell - bottom tabs holder for patient app
class PatientShell extends StatefulWidget {
  const PatientShell({super.key});

  @override
  State<PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<PatientShell> {
  int _currentIndex = 0;
  final GlobalKey<AllDoctorsScreenState> _allDoctorsKey = GlobalKey();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const PatientHomeScreen(),
      AllDoctorsScreen(key: _allDoctorsKey),
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return InAppNotificationListener(
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: _screens),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(13),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, Icons.home_outlined, Icons.home, 'Home'),
                  _buildNavItem(
                    1,
                    Icons.calendar_today_outlined,
                    Icons.calendar_today,
                    'appointments',
                  ),
                  _buildNavItem(
                    2,
                    Icons.person_outline,
                    Icons.person,
                    'Profile',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    IconData activeIcon,
    String label,
  ) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
        // Refresh favorites when switching to doctors tab
        if (index == 1) {
          _allDoctorsKey.currentState?.refreshFavorites();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? AppColors.primary : AppColors.textHint,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
