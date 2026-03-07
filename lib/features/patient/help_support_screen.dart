import 'package:flutter/material.dart';
import '../../app/app_theme.dart';

/// Help & Support screen with FAQ and contact information
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Help & Support',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primary.withAlpha(200)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  Icon(Icons.support_agent, size: 48, color: Colors.white),
                  SizedBox(height: 12),
                  Text(
                    'How can we help you?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Find answers below or contact our team',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // FAQ section
            const Text(
              'Frequently Asked Questions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            _buildFAQ(
              'How do I book an appointment?',
              'Go to the Home tab, tap "Book Appointment", choose a doctor, '
                  'select your preferred date and time slot, then confirm your booking.',
            ),
            _buildFAQ(
              'How do I cancel a booked appointment?',
              'Navigate to "My Bookings" from your profile or home screen. '
                  'Find the upcoming appointment you wish to cancel and tap '
                  '"Cancel Appointment". The booking will be permanently removed.',
            ),
            _buildFAQ(
              'When can I start a consultation?',
              'The "Start Consultation" button becomes active 30 minutes '
                  'before your scheduled appointment time. Please make sure '
                  'you are available at that time.',
            ),
            _buildFAQ(
              'How does the DFU monitoring work?',
              'KHOTAA uses sensor data from your foot device to measure '
                  'temperature and pressure. Readings are automatically sent '
                  'to your doctor for real-time monitoring and early risk '
                  'detection.',
            ),
            _buildFAQ(
              'How do I view my medical history?',
              'Go to your Profile tab and tap "Medical History". You can view '
                  'all past DFU readings, treatment plans, and medical images '
                  'uploaded by your doctor.',
            ),
            _buildFAQ(
              'What do risk alerts mean?',
              'Risk alerts are sent when your foot pressure or temperature '
                  'readings exceed normal thresholds. High-risk alerts require '
                  'immediate attention. Your doctor is automatically notified.',
            ),

            const SizedBox(height: 24),

            // Contact section
            const Text(
              'Contact Us',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            _buildContactTile(
              Icons.email_outlined,
              'Email',
              'support@khotaa.app',
            ),
            _buildContactTile(
              Icons.access_time_outlined,
              'Working Hours',
              'Sun – Thu, 8:00 AM – 5:00 PM',
            ),

            const SizedBox(height: 30),

            // App version
            Center(
              child: Text(
                'KHOTAA v1.0.0',
                style: TextStyle(color: AppColors.textHint, fontSize: 13),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQ(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        leading: const Icon(
          Icons.help_outline,
          color: AppColors.primary,
          size: 22,
        ),
        title: Text(
          question,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        children: [
          Text(
            answer,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTile(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: AppColors.textHint),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
