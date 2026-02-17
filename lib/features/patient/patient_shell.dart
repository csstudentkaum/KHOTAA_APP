import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import '../../services/firebase/auth_service.dart';

/// Patient shell - bottom tabs holder
/// TODO: Implement patient shell with bottom navigation
class PatientShell extends StatelessWidget {
  const PatientShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                    context, '/login', (route) => false);
              }
            },
          ),
        ],
      ),
      body: const Center(
        child: Text(
          'Welcome, Patient!',
          style: TextStyle(fontSize: 20, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
