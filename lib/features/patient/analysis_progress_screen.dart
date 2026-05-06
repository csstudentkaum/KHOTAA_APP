import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import '../../models/medical_images.dart';
import '../../services/firebase/image_analysis_service.dart';
import 'analysis_result_screen.dart';

// ── Figma palette ───────────────────────────────────────────────────
const _kTeal = Color(0xFF64ADB3);
const _kPink = Color(0xFFF1AAAF);

/// Progress screen — uploads to Firebase, runs analysis, shows animated
/// circular progress that matches the Figma "Image Analysis in Progress" UI.
class AnalysisProgressScreen extends StatefulWidget {
  final File? imageFile;
  final Uint8List? imageBytes;
  const AnalysisProgressScreen({super.key, this.imageFile, this.imageBytes});

  @override
  State<AnalysisProgressScreen> createState() => _AnalysisProgressScreenState();
}

class _AnalysisProgressScreenState extends State<AnalysisProgressScreen>
    with SingleTickerProviderStateMixin {
  final _service = ImageAnalysisService();

  late final AnimationController _breathe;

  double _progress = 0.0;
  int _animToken = 0;
  bool _done = false;
  String? _error;

  // ── Lifecycle ─────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _run();
  }

  @override
  void dispose() {
    _breathe.dispose();
    super.dispose();
  }

  // ── Pipeline ──────────────────────────────────────────────────────

  Future<void> _run() async {
    try {
      // Step 1 – upload
      _animateTo(0.30);
      final MedicalImages image;
      if (kIsWeb || widget.imageFile == null) {
        image = await _service.uploadImageBytes(widget.imageBytes!);
      } else {
        image = await _service.uploadImage(widget.imageFile!);
      }

      if (!mounted) return;
      _animateTo(0.70);

      // Step 2 – analyse (pass bytes to avoid re-fetching from Storage on web)
      final analysis = await _service.analyse(
        image,
        imageBytes: widget.imageBytes,
      );

      if (!mounted) return;
      _animateTo(1.0);
      setState(() => _done = true);

      await Future.delayed(const Duration(milliseconds: 850));
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AnalysisResultScreen(
            imageFile: widget.imageFile,
            imageBytes: widget.imageBytes,
            image: image,
            analysis: analysis,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  /// Smoothly animate [_progress] to [target] over ~800 ms (ease-out).
  void _animateTo(double target) {
    final token = ++_animToken;
    final start = _progress;
    final diff = target - start;
    int frame = 0;
    const totalFrames = 40;

    Timer.periodic(const Duration(milliseconds: 20), (timer) {
      if (!mounted || token != _animToken) {
        timer.cancel();
        return;
      }
      frame++;
      final t = (frame / totalFrames).clamp(0.0, 1.0);
      final eased = 1 - (1 - t) * (1 - t);
      setState(() => _progress = start + diff * eased);
      if (frame >= totalFrames) timer.cancel();
    });
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kTeal,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Robot overlapping white card ──
            Expanded(
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  // White card — pushed down by half the robot
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(
                      left: 28,
                      right: 28,
                      top: 55,
                      bottom: 40,
                    ),
                    padding: const EdgeInsets.only(
                      left: 28,
                      right: 28,
                      top: 80,
                      bottom: 36,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: _error != null ? _errorView() : _progressView(),
                  ),

                  // Robot icon — half in teal, half in white
                  _buildRobotIcon(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sub-widgets ───────────────────────────────────────────────────

  Widget _buildRobotIcon() {
    return ScaleTransition(
      scale: Tween<double>(
        begin: 0.94,
        end: 1.06,
      ).animate(CurvedAnimation(parent: _breathe, curve: Curves.easeInOut)),
      child: Container(
        width: 110,
        height: 110,
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
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3D6A99), Color(0xFF2F4A5F)],
              ),
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              size: 50,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _progressView() {
    final percent = (_progress * 100).toInt();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Image Analysis\nin Progress',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 36),

        // ── Circular progress ──
        SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: CircularProgressIndicator(
                  value: _progress,
                  strokeWidth: 10,
                  backgroundColor: AppColors.divider,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _done ? AppColors.success : _kPink,
                  ),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 36),

        Text(
          _done
              ? 'Analysis complete!'
              : 'Analysis result will be available once\nthe processing is complete.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _errorView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.error.withValues(alpha: 0.1),
          ),
          child: const Icon(
            Icons.error_outline,
            size: 36,
            color: AppColors.error,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Something went wrong',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: () {
              setState(() {
                _error = null;
                _progress = 0.0;
                _done = false;
              });
              _run();
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _kTeal),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Retry'),
          ),
        ),
      ],
    );
  }
}
