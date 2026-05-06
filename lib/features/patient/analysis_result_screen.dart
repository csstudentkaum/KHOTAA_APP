import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../app/app_theme.dart';
import '../../models/image_analysis.dart';
import '../../models/medical_images.dart';
import 'booking/all_doctors_screen.dart';
import 'medical_faq_chatbot_screen.dart';

// ── Palette ─────────────────────────────────────────────────────────
const _kTeal = Color(0xFF64ADB3);

/// Patient-focused analysis result screen.
///
/// Shows: classification, risk level, what it means for the patient,
/// actionable recommendations, and whether they should see a doctor.
/// Includes a "Download Report" button.
class AnalysisResultScreen extends StatelessWidget {
  final File? imageFile;
  final Uint8List? imageBytes;
  final MedicalImages image;
  final ImageAnalysis analysis;

  const AnalysisResultScreen({
    super.key,
    this.imageFile,
    this.imageBytes,
    required this.image,
    required this.analysis,
  });

  // ── Colour helpers ────────────────────────────────────────────────

  Color get _riskColor => switch (analysis.riskLevel) {
    'Low' => const Color(0xFF27AE60),
    'High' => const Color(0xFFE67E22),
    'Critical' => const Color(0xFFE53935),
    _ => const Color(0xFF6B7280),
  };

  IconData get _riskIcon => switch (analysis.riskLevel) {
    'Low' => Icons.check_circle_rounded,
    'High' => Icons.warning_amber_rounded,
    'Critical' => Icons.error_rounded,
    _ => Icons.info_outline_rounded,
  };

  String get _formattedDate {
    final d = image.uploadedAt;
    const months = [
      '',
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
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildRiskBanner(),
                const SizedBox(height: 16),
                _buildClassificationCard(),
                const SizedBox(height: 14),
                _buildSummaryCard(),
                const SizedBox(height: 14),
                _buildRecommendationsCard(),
                const SizedBox(height: 14),
                if (analysis.shouldConsultDoctor) ...[
                  _buildDoctorAlertCard(context),
                  const SizedBox(height: 14),
                ],
                _buildInfoRow(),
                const SizedBox(height: 18),
                _buildDisclaimer(),
                const SizedBox(height: 20),
                _buildDownloadButton(context),
                const SizedBox(height: 12),
                _buildHomeButton(context),
                const SizedBox(height: 16),
                _buildFaqCard(context),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── SliverAppBar ──────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: _kTeal,
      toolbarHeight: 64,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
        child: GestureDetector(
          onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.3),
            ),
            child: const Icon(
              Icons.close_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
      title: const Text(
        'Analysis Result',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            (kIsWeb || imageFile == null)
                ? Image.memory(imageBytes!, fit: BoxFit.cover)
                : Image.file(imageFile!, fit: BoxFit.cover),
            Container(
              decoration: const BoxDecoration(
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
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Analysis Complete',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formattedDate,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Risk Banner ───────────────────────────────────────────────────

  Widget _buildRiskBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: _riskColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _riskColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(_riskIcon, color: _riskColor, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Risk Level: ${analysis.riskLevel}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _riskColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  analysis.shouldConsultDoctor
                      ? 'Medical consultation is recommended'
                      : 'Continue regular monitoring',
                  style: TextStyle(
                    fontSize: 13,
                    color: _riskColor.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Classification Card ───────────────────────────────────────────

  Widget _buildClassificationCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _kTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.biotech_rounded,
                  color: _kTeal,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Classification Result',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              // Confidence badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _kTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.speed_rounded, size: 14, color: _kTeal),
                    const SizedBox(width: 4),
                    Text(
                      analysis.confidencePercent,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kTeal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Big classification label
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: _riskColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _riskColor.withValues(alpha: 0.15)),
            ),
            child: Center(
              child: Text(
                analysis.classificationLabel,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: _riskColor,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Confidence: ${analysis.confidencePercent}',
              style: const TextStyle(fontSize: 12, color: AppColors.textHint),
            ),
          ),
        ],
      ),
    );
  }

  // ── What This Means ───────────────────────────────────────────────

  Widget _buildSummaryCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF3498DB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF3498DB),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'What This Means',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            analysis.patientSummary,
            textAlign: TextAlign.justify,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }

  // ── Recommendations ───────────────────────────────────────────────

  Widget _buildRecommendationsCard() {
    final bullets = analysis.recommendation
        .split('\n')
        .map((b) => b.replaceFirst(RegExp(r'^[•\-]\s*'), '').trim())
        .where((b) => b.isNotEmpty)
        .toList();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF27AE60).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.checklist_rounded,
                  color: Color(0xFF27AE60),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'What You Should Do',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(bullets.length, (i) {
            final isLast = i == bullets.length - 1;
            final isConsult = bullets[i].toLowerCase().contains('consultation');

            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12, left: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isConsult ? _kTeal : const Color(0xFF9CA3AF),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      bullets[i],
                      style: TextStyle(
                        fontSize: 14,
                        color: isConsult ? _kTeal : AppColors.textPrimary,
                        fontWeight: isConsult
                            ? FontWeight.w600
                            : FontWeight.w400,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Doctor Alert ──────────────────────────────────────────────────

  Widget _buildDoctorAlertCard(BuildContext context) {
    final isCritical = analysis.isCritical;
    final alertColor = isCritical
        ? const Color(0xFFE53935)
        : const Color(0xFFE67E22);

    return GestureDetector(
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AllDoctorsScreen()));
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: alertColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: alertColor.withValues(alpha: 0.25),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: alertColor.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: alertColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCritical
                        ? Icons.local_hospital_rounded
                        : Icons.medical_services_outlined,
                    color: alertColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCritical
                            ? 'Urgent: See a Doctor Immediately'
                            : 'Please Consult Your Doctor',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: alertColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isCritical
                            ? 'This result indicates a serious condition that needs immediate professional medical care. Do not delay seeking help.'
                            : 'Based on this analysis, we recommend scheduling an appointment with your healthcare provider for a thorough examination.',
                        style: TextStyle(
                          fontSize: 13,
                          color: alertColor.withValues(alpha: 0.85),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Subtle tap hint — not a button, just a label row
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: alertColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isCritical ? Icons.video_call_rounded : Icons.chat_outlined,
                    size: 18,
                    color: alertColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isCritical
                        ? 'Tap to request urgent consultation'
                        : 'Tap to consult a doctor',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: alertColor,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: alertColor.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Info row (date + model) ───────────────────────────────────────

  Widget _buildInfoRow() {
    return Row(
      children: [
        Expanded(
          child: _miniInfo(
            Icons.calendar_today_rounded,
            'Date',
            _formattedDate,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _miniInfo(Icons.science_outlined, 'Model', analysis.modelName),
        ),
      ],
    );
  }

  Widget _miniInfo(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textHint),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textHint,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── AI Disclaimer ─────────────────────────────────────────────────

  Widget _buildDisclaimer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD5DDE5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: Color(0xFF7B8D9E),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This analysis is generated by artificial intelligence for '
              'informational purposes only. It is not a medical diagnosis. '
              'Always consult a qualified healthcare professional before '
              'making any decisions about your health.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Download Report Button ────────────────────────────────────────

  Widget _buildDownloadButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: () => _generateAndSharePdf(context),
        icon: const Icon(Icons.download_rounded, size: 20),
        label: const Text('Download Report'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _kTeal,
          foregroundColor: Colors.white,
          elevation: 3,
          shadowColor: _kTeal.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // ── Back to Home Button ───────────────────────────────────────────

  Widget _buildHomeButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
        style: OutlinedButton.styleFrom(
          foregroundColor: _kTeal,
          side: const BorderSide(color: _kTeal, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        child: const Text('Back to Home'),
      ),
    );
  }

  // ── FAQ Chatbot Card ───────────────────────────────────────────────

  Widget _buildFaqCard(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MedicalFaqChatbotScreen()),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _kTeal.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kTeal.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _kTeal.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                color: _kTeal,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Have questions?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Ask our FAQ chatbot about foot care',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: _kTeal,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // ── Card wrapper ──────────────────────────────────────────────────

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

  // ── PDF Generation ────────────────────────────────────────────────

  Future<void> _generateAndSharePdf(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Preparing your report…'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final pdf = pw.Document();

      // Read image bytes for the PDF
      final Uint8List pdfImageBytes =
          imageBytes ?? await imageFile!.readAsBytes();
      final pdfImage = pw.MemoryImage(pdfImageBytes);

      final riskPdfColor = switch (analysis.riskLevel) {
        'Low' => PdfColors.green,
        'High' => PdfColors.orange,
        'Critical' => PdfColors.red,
        _ => PdfColors.grey,
      };

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          header: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'KHOTAA',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#64ADB3'),
                    ),
                  ),
                  pw.Text(
                    'Ulcer Analysis Report',
                    style: pw.TextStyle(fontSize: 14, color: PdfColors.grey600),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Divider(color: PdfColor.fromHex('#64ADB3'), thickness: 2),
              pw.SizedBox(height: 8),
            ],
          ),
          footer: (ctx) => pw.Column(
            children: [
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'AI-generated report for informational purposes only. Not a medical diagnosis.',
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                  ),
                  pw.Text(
                    'Page ${ctx.pageNumber}/${ctx.pagesCount}',
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                  ),
                ],
              ),
            ],
          ),
          build: (ctx) => [
            // Date
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Date: $_formattedDate',
                  style: const pw.TextStyle(fontSize: 11),
                ),
                pw.Text(
                  'Model: ${analysis.modelName}',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // Image
            pw.Center(
              child: pw.ClipRRect(
                horizontalRadius: 8,
                verticalRadius: 8,
                child: pw.Image(
                  pdfImage,
                  width: 220,
                  height: 180,
                  fit: pw.BoxFit.cover,
                ),
              ),
            ),
            pw.SizedBox(height: 20),

            // Risk + Classification
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: riskPdfColor, width: 1.5),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    'Classification: ${analysis.classificationLabel}',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: riskPdfColor,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Risk Level: ${analysis.riskLevel}   |   Confidence: ${analysis.confidencePercent}',
                    style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // What This Means
            pw.Text(
              'What This Means',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              analysis.patientSummary
                  .replaceAll('\u2014', '-')
                  .replaceAll('\u2013', '-'),
              style: const pw.TextStyle(fontSize: 11, lineSpacing: 4),
            ),
            pw.SizedBox(height: 16),

            // Recommendations
            pw.Text(
              'Recommendations',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              analysis.recommendation
                  .replaceAll('• ', '- ')
                  .replaceAll('\u2014', '-')
                  .replaceAll('\u2013', '-'),
              style: const pw.TextStyle(fontSize: 11, lineSpacing: 4),
            ),
            pw.SizedBox(height: 16),

            // Doctor alert
            if (analysis.shouldConsultDoctor) ...[
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#FFF3E0'),
                  border: pw.Border.all(color: riskPdfColor),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  analysis.isCritical
                      ? 'URGENT: Please see a doctor immediately. This result indicates a serious condition.'
                      : 'Please consult your healthcare provider for professional evaluation.',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: riskPdfColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      );

      final bytes = await pdf.save();

      // Save the PDF to the device so the user has it locally.
      // Try the public Downloads folder on Android first, fall back to the
      // app's documents directory on iOS / when Downloads is unavailable.
      final filename =
          'KHOTAA_Report_${analysis.classificationLabel}_${image.uploadedAt.millisecondsSinceEpoch}.pdf';

      Directory? targetDir;
      if (Platform.isAndroid) {
        targetDir = Directory('/storage/emulated/0/Download');
        if (!await targetDir.exists()) {
          targetDir = await getExternalStorageDirectory();
        }
      }
      targetDir ??= await getApplicationDocumentsDirectory();

      final filePath = '${targetDir.path}/$filename';
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Report saved to your Downloads folder',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () => OpenFile.open(file.path),
          ),
        ),
      );
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.white, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Could not save the report. Please try again.',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}
