import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import '../../models/consultation.dart';
import '../../services/firebase/auth_service.dart';
import '../../services/firebase/consultation_chat_service.dart';
import '../shared/consultation_session_screen.dart';

class DoctorShell extends StatefulWidget {
  const DoctorShell({super.key});

  @override
  State<DoctorShell> createState() => _DoctorShellState();
}

class _DoctorShellState extends State<DoctorShell> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    _ConsultationsTab(),
    _PatientsPlaceholderTab(),
    _DoctorProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primary.withValues(alpha: 0.15),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon:
                Icon(Icons.chat_bubble_rounded, color: AppColors.primary),
            label: 'Consultations',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon:
                Icon(Icons.people_rounded, color: AppColors.primary),
            label: 'Patients',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon:
                Icon(Icons.person_rounded, color: AppColors.primary),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Consultations tab

class _ConsultationsTab extends StatelessWidget {
  const _ConsultationsTab();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final service = ConsultationChatService();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Consultations',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
            fontSize: 18,
          ),
        ),
      ),
      body: StreamBuilder<List<Consultation>>(
        stream: service.streamConsultationsForDoctor(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          final consultations = snap.data ?? [];
          if (consultations.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No consultations yet.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontFamily: 'Poppins',
                    fontSize: 15,
                  ),
                ),
              ),
            );
          }

          // Group by status for clarity
          final active = consultations
              .where((c) =>
                  c.status == ConsultationStatus.active ||
                  c.status == ConsultationStatus.accepted)
              .toList();
          final pending = consultations
              .where((c) => c.status == ConsultationStatus.pending)
              .toList();
          final followUp = consultations
              .where((c) => c.status == ConsultationStatus.followUp)
              .toList();
          final done = consultations
              .where((c) =>
                  c.status == ConsultationStatus.completed ||
                  c.status == ConsultationStatus.rejected)
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (active.isNotEmpty) ...[
                _sectionHeader('Active / Accepted'),
                ...active.map((c) => _DoctorConsultCard(consultation: c)),
                const SizedBox(height: 8),
              ],
              if (pending.isNotEmpty) ...[
                _sectionHeader('Pending'),
                ...pending.map((c) => _DoctorConsultCard(consultation: c)),
                const SizedBox(height: 8),
              ],
              if (followUp.isNotEmpty) ...[
                _sectionHeader('Follow-up'),
                ...followUp.map((c) => _DoctorConsultCard(consultation: c)),
                const SizedBox(height: 8),
              ],
              if (done.isNotEmpty) ...[
                _sectionHeader('Completed / Rejected'),
                ...done.map((c) => _DoctorConsultCard(consultation: c)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          fontFamily: 'Poppins',
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────

class _DoctorConsultCard extends StatelessWidget {
  final Consultation consultation;

  const _DoctorConsultCard({required this.consultation});

  @override
  Widget build(BuildContext context) {
    final status = consultation.status;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConsultationSessionScreen(
              consultationId: consultation.consultationID,
              isDoctor: true,
            ),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  (consultation.patientName ?? 'P')[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      consultation.patientName ?? 'Patient',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    if (consultation.reason != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          consultation.reason!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _StatusDot(status: status),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final ConsultationStatus status;
  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case ConsultationStatus.pending: color = AppColors.warning; break;
      case ConsultationStatus.accepted: color = AppColors.primary; break;
      case ConsultationStatus.active: color = AppColors.success; break;
      case ConsultationStatus.followUp: color = AppColors.primaryLight; break;
      case ConsultationStatus.completed: color = AppColors.textHint; break;
      case ConsultationStatus.rejected: color = AppColors.error; break;
    }
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Patients placeholder tab

class _PatientsPlaceholderTab extends StatelessWidget {
  const _PatientsPlaceholderTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Patients',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
            fontSize: 18,
          ),
        ),
      ),
      body: const Center(
        child: Text(
          'Patient list coming soon.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontFamily: 'Poppins',
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Doctor profile tab

class _DoctorProfileTab extends StatelessWidget {
  const _DoctorProfileTab();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                    context, '/login', (_) => false);
              }
            },
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(
                  (user?.displayName ?? 'D')[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                user?.displayName ?? 'Doctor',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user?.email ?? '',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

