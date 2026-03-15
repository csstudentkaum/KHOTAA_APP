import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../app/app_theme.dart';
import '../../models/consultation.dart';
import '../../services/consultation_service.dart';

// Consultation Requests Screen
class ConsultationRequestsScreen extends StatelessWidget {
  const ConsultationRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Consultation Requests',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
      ),
      body: user == null
          ? const Center(child: Text('Not logged in'))
          : StreamBuilder<List<Consultation>>(
              stream: ConsultationService().streamDoctorConsultations(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                // Filter: only show upcoming (today or future) non-completed requests
                final now = DateTime.now();
                final startOfToday = DateTime(now.year, now.month, now.day);
                final requests = (snapshot.data ?? [])
                    .where(
                      (c) =>
                          (c.status == 'accepted' || c.status == 'pending') &&
                          c.consultationDate != null &&
                          !c.consultationDate!.isBefore(startOfToday),
                    )
                    .toList();

                // Sort by date + time slot (soonest first)
                requests.sort((a, b) {
                  final dateA = a.consultationDate ?? DateTime(2099);
                  final dateB = b.consultationDate ?? DateTime(2099);
                  final dateCmp = dateA.compareTo(dateB);
                  if (dateCmp != 0) return dateCmp;
                  final timeA = _parseTimeSlot(a.timeSlot ?? '');
                  final timeB = _parseTimeSlot(b.timeSlot ?? '');
                  final minutesA = timeA != null
                      ? timeA.hour * 60 + timeA.minute
                      : 9999;
                  final minutesB = timeB != null
                      ? timeB.hour * 60 + timeB.minute
                      : 9999;
                  return minutesA.compareTo(minutesB);
                });

                if (requests.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 64,
                            color: AppColors.textHint.withAlpha(120),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No consultation requests',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Patient consultation requests will appear here',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: requests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    return _buildRequestCard(context, requests[index]);
                  },
                );
              },
            ),
    );
  }

  Widget _buildRequestCard(BuildContext context, Consultation request) {
    final displayName = request.patientName ?? 'Unknown';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inputBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    displayName[0].toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'General Consultation',
                      style: TextStyle(color: AppColors.textHint, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Date and time row
          Row(
            children: [
              _buildInfoChip(
                Icons.calendar_today_outlined,
                request.consultationDate != null
                    ? request.formattedDate
                    : 'No date',
              ),
              const SizedBox(width: 16),
              if (request.timeSlot != null)
                _buildInfoChip(Icons.access_time, request.timeSlot!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ],
    );
  }

  static TimeOfDay? _parseTimeSlot(String slot) {
    try {
      final parts = slot.trim().split(' ');
      if (parts.length != 2) return null;
      final timeParts = parts[0].split(':');
      if (timeParts.length != 2) return null;

      int hour = int.parse(timeParts[0]);
      final int minute = int.parse(timeParts[1]);
      final period = parts[1].toUpperCase();

      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;

      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return null;
    }
  }
}
