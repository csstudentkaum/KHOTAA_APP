import 'dart:io';
import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import '../../models/image_analysis.dart';
import '../../models/medical_images.dart';

// ── Figma palette ───────────────────────────────────────────────────
const _kDarkBlue = Color(0xFF3D6A99);
const _kLightBlue = Color(0xFF85B1D2);
const _kTeal = Color(0xFF64ADB3);

/// Card-based result screen showing model output only.
class AnalysisResultScreen extends StatelessWidget {
  final File imageFile;
  final MedicalImages image;
  final ImageAnalysis analysis;

  const AnalysisResultScreen({
    super.key,
    required this.imageFile,
    required this.image,
    required this.analysis,
  });

  Color get _gradeColor => _colorForGrade(analysis.wagnerGrade);
  Color get _severityColor => _colorForSeverity(analysis.severityLevel);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F9),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Header with uploaded image ──
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: _kTeal,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.35),
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(imageFile, fit: BoxFit.cover),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 20,
                    right: 20,
                    child: Text(
                      'Analysis Complete',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Body cards ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Wagner Grade card ──
                _buildGradeCard(),
                const SizedBox(height: 16),

                // ── Assessment row ──
                Row(
                  children: [
                    Expanded(child: _buildSeverityCard()),
                    const SizedBox(width: 12),
                    Expanded(child: _buildConfidenceCard()),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Notes ──
                if (analysis.notes.isNotEmpty) ...[
                  _buildNotesCard(),
                  const SizedBox(height: 16),
                ],

                // ── Details ──
                _buildDetailsCard(),
                const SizedBox(height: 24),

                // ── Back button ──
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kTeal,
                      foregroundColor: Colors.white,
                      elevation: 3,
                      shadowColor: _kTeal.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('Back to Home'),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Wagner Grade ──────────────────────────────────────────────────

  Widget _buildGradeCard() {
    final description =
        analysis.wagnerGradeLabel.replaceFirst('Grade ${analysis.wagnerGrade} - ', '');

    return _card(
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _gradeColor.withValues(alpha: 0.1),
              border:
                  Border.all(color: _gradeColor.withValues(alpha: 0.3), width: 2),
            ),
            child: Center(
              child: Text(
                '${analysis.wagnerGrade}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: _gradeColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WAGNER CLASSIFICATION',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textHint,
                        letterSpacing: 1.2)),
                const SizedBox(height: 4),
                Text('Grade ${analysis.wagnerGrade}',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _gradeColor)),
                const SizedBox(height: 2),
                Text(description,
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Severity ──────────────────────────────────────────────────────

  Widget _buildSeverityCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 16, color: AppColors.textHint),
              const SizedBox(width: 6),
              Text('SEVERITY',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textHint,
                      letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _severityColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(analysis.severityLevel,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _severityColor)),
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(3, (i) {
              final filled = switch (analysis.severityLevel) {
                'Low' => i < 1,
                'Medium' => i < 2,
                _ => true,
              };
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: filled ? _severityColor : AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── Confidence ────────────────────────────────────────────────────

  Widget _buildConfidenceCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined,
                  size: 16, color: AppColors.textHint),
              const SizedBox(width: 6),
              Text('CONFIDENCE',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textHint,
                      letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              width: 68,
              height: 68,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 68,
                    height: 68,
                    child: CircularProgressIndicator(
                      value: analysis.confidence,
                      strokeWidth: 6,
                      backgroundColor: AppColors.divider,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(_kTeal),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Text(analysis.confidencePercent,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Notes ─────────────────────────────────────────────────────────

  Widget _buildNotesCard() {
    return _card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _kLightBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.notes_rounded,
                size: 17, color: _kDarkBlue),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Clinical Notes',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kDarkBlue)),
                const SizedBox(height: 6),
                Text(analysis.notes,
                    style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        height: 1.6)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Details ───────────────────────────────────────────────────────

  Widget _buildDetailsCard() {
    return _card(
      child: Column(
        children: [
          _detailRow('Model', analysis.modelName, Icons.science_outlined),
          _divider(),
          _detailRow('Image Ref', _truncate(image.imageID), Icons.image_outlined),
          _divider(),
          _detailRow('Analysis Ref', _truncate(analysis.analysisID), Icons.tag),
          _divider(),
          _detailRow(
            'Date',
            '${image.uploadedAt.day}/${image.uploadedAt.month}/${image.uploadedAt.year}',
            Icons.access_time_outlined,
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _kLightBlue),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500)),
          const Spacer(),
          Flexible(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      Divider(color: AppColors.divider.withValues(alpha: 0.6), height: 12);

  String _truncate(String s) =>
      s.length > 10 ? '${s.substring(0, 10)}…' : s;

  // ── Shared card wrapper ───────────────────────────────────────────

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  // ── Color helpers ─────────────────────────────────────────────────

  static Color _colorForGrade(int g) => switch (g) {
        0 => const Color(0xFF27AE60),
        1 => const Color(0xFFE6A817),
        2 => const Color(0xFFFF9800),
        3 => const Color(0xFFFF5722),
        4 => const Color(0xFFE53935),
        5 => const Color(0xFFB71C1C),
        _ => const Color(0xFF6B7280),
      };

  static Color _colorForSeverity(String s) => switch (s) {
        'Low' => const Color(0xFF27AE60),
        'Medium' => const Color(0xFFFF9800),
        'High' => const Color(0xFFE53935),
        _ => const Color(0xFF6B7280),
      };
}
