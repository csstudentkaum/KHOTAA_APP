import 'package:flutter/material.dart';
import '../../app/app_theme.dart';

/// Payment success — congratulations screen with check icon
class PaymentSuccessScreen extends StatelessWidget {
  final String doctorName;
  final String date;
  final String time;

  const PaymentSuccessScreen({
    super.key,
    this.doctorName = '',
    this.date = '',
    this.time = '',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 3),

              // ── Large teal circle with checkmark ──
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 100,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 36),

              // ── Congratulations ──
              Text(
                'Congratulations',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 14),

              const Text(
                'Your Payment Was Successful',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),

              if (doctorName.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      _detailRow(Icons.person, doctorName),
                      if (date.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _detailRow(Icons.calendar_today, date),
                      ],
                      if (time.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _detailRow(Icons.access_time, time),
                      ],
                    ],
                  ),
                ),
              ],

              const Spacer(flex: 3),

              // ── Back to Home Page button ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    // Pop all the way back to the shell / home
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Back to Home Page'),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
