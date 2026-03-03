import 'package:flutter/material.dart';
import '../../services/firebase/auth_service.dart';

/// Doctor shell - main screen for doctors
class DoctorShell extends StatelessWidget {
  const DoctorShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Doctor Home',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context, '/login', (_) => false,
                );
              }
            },
            tooltip: 'Sign Out',
            icon: const Icon(
              Icons.logout_rounded,
              color: Color(0xFF9CA3AF),
              size: 24,
            ),
          ),
        ],
      ),
      body: const Center(
        child: Text('Doctor Shell'),
      ),
    );
  }
}
