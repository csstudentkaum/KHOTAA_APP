import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import '../../models/consultation.dart';
import '../../services/firebase/consultation_chat_service.dart';
import '../shared/consultation_session_screen.dart';

class AppointmentScreen extends StatelessWidget {
  const AppointmentScreen({super.key});

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
          'My Consultations',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
            fontSize: 18,
          ),
        ),
      ),
      body: StreamBuilder<List<Consultation>>(
        stream: service.streamConsultationsForPatient(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          final consultations = snap.data ?? [];
          if (consultations.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.medical_services_outlined,
                        size: 64,
                        color: AppColors.primary.withValues(alpha: 0.35)),
                    const SizedBox(height: 16),
                    const Text(
                      'No consultations yet.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Book a session with a doctor to get started.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: consultations.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              return _ConsultationCard(consultation: consultations[i]);
            },
          );
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────

class _ConsultationCard extends StatelessWidget {
  final Consultation consultation;

  const _ConsultationCard({required this.consultation});

  @override
  Widget build(BuildContext context) {
    final status = consultation.status;
    final canTap = status != ConsultationStatus.rejected;

    return GestureDetector(
      onTap: canTap
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ConsultationSessionScreen(
                    consultationId: consultation.consultationID,
                    isDoctor: false,
                  ),
                ),
              )
          : null,
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
            // Status indicator stripe
            Container(
              width: 4,
              height: 64,
              decoration: BoxDecoration(
                color: _statusColor(status),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          consultation.doctorName ?? 'Doctor',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                      _StatusBadge(status: status),
                    ],
                  ),
                  if (consultation.reason != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        consultation.reason!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  if (consultation.timeSlot != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule_rounded,
                              size: 13,
                              color: AppColors.textHint),
                          const SizedBox(width: 4),
                          Text(
                            consultation.timeSlot!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textHint,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (canTap)
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  Color _statusColor(ConsultationStatus s) {
    switch (s) {
      case ConsultationStatus.pending: return AppColors.warning;
      case ConsultationStatus.accepted: return AppColors.primary;
      case ConsultationStatus.active: return AppColors.success;
      case ConsultationStatus.followUp: return AppColors.primaryLight;
      case ConsultationStatus.completed: return AppColors.textHint;
      case ConsultationStatus.rejected: return AppColors.error;
    }
  }
}

// ────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final ConsultationStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = _info();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }

  (String, Color, Color) _info() {
    switch (status) {
      case ConsultationStatus.pending:
        return ('Pending', const Color(0xFFFFF3CD), const Color(0xFF856404));
      case ConsultationStatus.accepted:
        return ('Accepted', const Color(0xFFD1F0EC), AppColors.primaryDark);
      case ConsultationStatus.active:
        return ('Active', const Color(0xFFD4EDDA), const Color(0xFF155724));
      case ConsultationStatus.followUp:
        return ('Follow-up', const Color(0xFFCCE5FF), const Color(0xFF004085));
      case ConsultationStatus.completed:
        return ('Completed', const Color(0xFFF8F9FA), AppColors.textSecondary);
      case ConsultationStatus.rejected:
        return ('Rejected', const Color(0xFFF8D7DA), const Color(0xFF721C24));
    }
  }
}

