import 'package:flutter/material.dart';

// ── Figma palette ───────────────────────────────────────────────────
const _kTeal = Color(0xFF64ADB3);

/// Payment success — congratulations screen with check icon
class PaymentSuccessScreen extends StatelessWidget {
  const PaymentSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                decoration: const BoxDecoration(
                  color: _kTeal,
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
                  fontStyle: FontStyle.italic,
                  color: _kTeal,
                ),
              ),
              const SizedBox(height: 14),

              const Text(
                'Your Payment Was Successful',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A1A),
                ),
              ),

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
                    backgroundColor: _kTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
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
}
