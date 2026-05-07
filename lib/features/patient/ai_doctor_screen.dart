import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import '../../app/app_theme.dart';
import 'analysis_progress_screen.dart';

// ── Figma palette ───────────────────────────────────────────────────
const _kDarkBlue = Color(0xFF3D6A99);
const _kTeal = Color(0xFF64ADB3);

/// Upload / capture screen — matches the "Your AI Doctor" Figma design.
class AiDoctorScreen extends StatefulWidget {
  const AiDoctorScreen({super.key});

  @override
  State<AiDoctorScreen> createState() => _AiDoctorScreenState();
}

class _AiDoctorScreenState extends State<AiDoctorScreen>
    with SingleTickerProviderStateMixin {
  final _picker = ImagePicker();
  File? _image;
  Uint8List? _imageBytes;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ── Image picking ─────────────────────────────────────────────────

  Future<void> _pick(ImageSource source) async {
    final xfile = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (xfile != null && mounted) {
      final bytes = await xfile.readAsBytes();
      setState(() {
        _image = kIsWeb ? null : File(xfile.path);
        _imageBytes = bytes;
      });
    }
  }

  void _submit() {
    if (_imageBytes == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnalysisProgressScreen(
          imageFile: kIsWeb ? null : _image,
          imageBytes: _imageBytes,
        ),
      ),
    );
  }

  void _showSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Upload Image',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose how you want to add your image',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
              const SizedBox(height: 20),
              _sheetTile(
                icon: Icons.camera_alt_rounded,
                color: _kTeal,
                title: 'Take a Photo',
                subtitle: 'Use your camera',
                onTap: () {
                  Navigator.pop(context);
                  _pick(ImageSource.camera);
                },
              ),
              Divider(height: 1, color: Colors.grey[200]),
              _sheetTile(
                icon: Icons.photo_library_rounded,
                color: _kDarkBlue,
                title: 'Choose from Gallery',
                subtitle: 'Browse your device',
                onTap: () {
                  Navigator.pop(context);
                  _pick(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: AppColors.textHint,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Curved teal header ──
            _buildHeader(mq.size),

            // ── Body – overlaps header by 75 px for robot icon ──
            Transform.translate(
              offset: const Offset(0, -75),
              child: Column(
                children: [
                  _buildRobotAvatar(),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Text(
                      'Upload your image to get AI-powered health analysis',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: GestureDetector(
                      onTap: _showSourcePicker,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _imageBytes != null
                            ? _imagePreview()
                            : _uploadZone(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: _analyzeButton(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────

  Widget _buildHeader(Size size) {
    return ClipPath(
      clipper: _CurvedClipper(),
      child: Container(
        height: size.height * 0.28,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_kTeal, Color(0xFF4D9DA3)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
            child: Column(
              children: [
                const SizedBox(height: 10),
                const Center(
                  child: Text(
                    'Your AI Doctor',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Robot avatar ──────────────────────────────────────────────────

  Widget _buildRobotAvatar() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
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
                  color: const Color(
                    0xFFA3FBFF,
                  ).withValues(alpha: 0.3 * _pulseAnimation.value),
                  blurRadius: 24 * _pulseAnimation.value,
                  spreadRadius: 4 * _pulseAnimation.value,
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
                child: const Icon(
                  Icons.smart_toy_rounded,
                  size: 65,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Upload zone (dashed border) ───────────────────────────────────

  Widget _uploadZone() {
    return CustomPaint(
      key: const ValueKey('zone'),
      painter: _DashedBorderPainter(
        color: AppColors.inputBorder,
        strokeWidth: 1.5,
        dashLen: 7,
        gapLen: 5,
        radius: 16,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 52),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            SvgPicture.asset(
              'assets/icons/Upload.svg',
              width: 60,
              height: 60,
              colorFilter: const ColorFilter.mode(
                Color(0xFF5A5A5A),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Tap to upload a photo',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Image preview ─────────────────────────────────────────────────

  Widget _imagePreview() {
    return Stack(
      key: const ValueKey('preview'),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: (kIsWeb || _image == null)
              ? Image.memory(
                  _imageBytes!,
                  width: double.infinity,
                  height: 260,
                  fit: BoxFit.cover,
                )
              : Image.file(
                  _image!,
                  width: double.infinity,
                  height: 260,
                  fit: BoxFit.cover,
                ),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: GestureDetector(
            onTap: () => setState(() {
              _image = null;
              _imageBytes = null;
            }),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.55),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Analyze button ────────────────────────────────────────────────

  Widget _analyzeButton() {
    final enabled = _imageBytes != null;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: enabled ? _submit : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kTeal,
          disabledBackgroundColor: _kTeal.withValues(alpha: 0.35),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white70,
          elevation: enabled ? 4 : 0,
          shadowColor: _kTeal.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        child: const Text('Analyze Image'),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Custom painters & clippers
// ═════════════════════════════════════════════════════════════════════

class _CurvedClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..lineTo(0, size.height - 50)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height + 25,
        size.width,
        size.height - 50,
      )
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLen;
  final double gapLen;
  final double radius;

  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashLen,
    required this.gapLen,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    final dashed = Path();
    for (final m in path.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        final end = (d + dashLen).clamp(0.0, m.length);
        dashed.addPath(m.extractPath(d, end), Offset.zero);
        d = end + gapLen;
      }
    }
    canvas.drawPath(dashed, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
