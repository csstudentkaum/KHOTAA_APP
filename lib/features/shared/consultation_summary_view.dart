import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import '../../models/consultation.dart';
import '../../services/firebase/consultation_chat_service.dart';

/// Read-only professional view of a consultation summary (diagnosis, notes, prescription).
/// Accessible from the three-dot menu in chat.
class ConsultationSummaryView extends StatelessWidget {
  final String consultationId;

  const ConsultationSummaryView({super.key, required this.consultationId});

  @override
  Widget build(BuildContext context) {
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
          'Consultation Summary',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: AppColors.primary,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<Consultation?>(
        stream: ConsultationChatService().streamConsultation(consultationId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          final c = snapshot.data;
          if (c == null) {
            return const Center(
              child: Text(
                'Consultation not found',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
            );
          }

          final hasSummary =
              c.diagnosis != null || c.notes != null || c.prescription != null;

          if (!hasSummary) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.medical_information_outlined,
                    size: 56,
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No summary available yet',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'The doctor will add a summary after the session.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Patient & Doctor header
                _buildHeader(c),
                const SizedBox(height: 20),

                // Status
                Row(
                  children: [
                    _statusBadge(c.status),
                    const Spacer(),
                    if (c.consultationDate != null)
                      Text(
                        c.formattedDate,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppColors.textHint,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Diagnosis
                if (c.diagnosis != null && c.diagnosis!.isNotEmpty)
                  _buildDetailCard(
                    icon: Icons.local_hospital_outlined,
                    title: 'Diagnosis',
                    content: c.diagnosis!,
                  ),
                if (c.diagnosis != null && c.diagnosis!.isNotEmpty)
                  const SizedBox(height: 16),

                // Clinical Notes
                if (c.notes != null && c.notes!.isNotEmpty)
                  _buildDetailCard(
                    icon: Icons.note_alt_outlined,
                    title: 'Clinical Notes',
                    content: c.notes!,
                  ),
                if (c.notes != null && c.notes!.isNotEmpty)
                  const SizedBox(height: 16),

                // Prescription
                if (c.prescription != null && c.prescription!.isNotEmpty)
                  _buildDetailCard(
                    icon: Icons.receipt_long_outlined,
                    title: 'Prescription',
                    content: c.prescription!,
                  ),
                if (c.prescription != null && c.prescription!.isNotEmpty)
                  const SizedBox(height: 16),

                // Follow-up info
                if (c.status == 'followUp') ...[
                  _buildFollowUpCard(c),
                  const SizedBox(height: 16),
                ],

                // Reason
                if (c.reason != null && c.reason!.isNotEmpty)
                  _buildDetailCard(
                    icon: Icons.help_outline_rounded,
                    title: 'Reason for Visit',
                    content: c.reason!,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(Consultation c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        children: [
          _infoRow(
            Icons.person_outline_rounded,
            'Patient',
            c.patientName ?? 'Unknown',
          ),
          const Divider(height: 20, color: AppColors.divider),
          _infoRow(
            Icons.medical_services_outlined,
            'Doctor',
            c.doctorName ?? 'Unknown',
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                color: AppColors.textHint,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'completed':
        color = AppColors.success;
        label = 'Completed';
        break;
      case 'followUp':
        color = AppColors.primary;
        label = 'Follow-up';
        break;
      case 'active':
        color = AppColors.info;
        label = 'Active';
        break;
      default:
        color = AppColors.textHint;
        label = status[0].toUpperCase() + status.substring(1);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowUpCard(Consultation c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.event_repeat_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Text(
                'Follow-up Care',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          if (c.followUpDueDate != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: AppColors.textHint,
                ),
                const SizedBox(width: 6),
                Text(
                  'Due: ${_formatDate(c.followUpDueDate!)}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
          if (c.followUpInstructions != null &&
              c.followUpInstructions!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              c.followUpInstructions!,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ],
          if (c.followUpTasks.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...c.followUpTasks.map(
              (task) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      (task['completed'] == true)
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 18,
                      color: (task['completed'] == true)
                          ? AppColors.success
                          : AppColors.textHint,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        task['label'] as String? ?? '',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}
