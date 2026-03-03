import 'dart:async';
import 'package:flutter/material.dart';

/// Voice call screen — matches the Figma "Dr. Abdullah" call UI.
class CallScreen extends StatefulWidget {
  final String doctorName;
  const CallScreen({super.key, this.doctorName = 'Dr. Abdullah'});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late final Timer _timer;
  int _seconds = 0;
  bool _isMuted = false;
  bool _isCameraOff = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String get _formattedTime {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.88],
            colors: [Color(0xFF73B1B4), Color(0xFFD2EBE7)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),

            // ── Doctor avatar ──
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFA3FBFF), Color(0xFF629699)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFA3FBFF).withValues(alpha: 0.3),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF3D6A99), Color(0xFF2F4A5F)],
                    ),
                  ),
                  child: const Icon(Icons.person,
                      size: 65, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Doctor name ──
            Text(
              widget.doctorName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),

            // ── Timer ──
            Text(
              _formattedTime,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),

            const Spacer(flex: 3),

            // ── Controls ──
            Padding(
              padding: const EdgeInsets.only(bottom: 50),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Camera toggle
                  _buildControlButton(
                    icon: _isCameraOff
                        ? Icons.videocam_off_outlined
                        : Icons.videocam_off_outlined,
                    onTap: () =>
                        setState(() => _isCameraOff = !_isCameraOff),
                    backgroundColor: Colors.white,
                    iconColor: const Color(0xFF1A1A1A),
                  ),
                  const SizedBox(width: 28),

                  // End call
                  _buildControlButton(
                    icon: Icons.phone,
                    onTap: () => Navigator.pop(context),
                    backgroundColor: const Color(0xFFE53935),
                    iconColor: Colors.white,
                    size: 64,
                    iconSize: 30,
                  ),
                  const SizedBox(width: 28),

                  // Mute toggle
                  _buildControlButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic_none_rounded,
                    onTap: () => setState(() => _isMuted = !_isMuted),
                    backgroundColor: Colors.white,
                    iconColor: const Color(0xFF1A1A1A),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color backgroundColor,
    required Color iconColor,
    double size = 56,
    double iconSize = 26,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, size: iconSize, color: iconColor),
      ),
    );
  }
}
