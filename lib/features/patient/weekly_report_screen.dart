import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class WeeklyReportScreen extends StatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  State<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends State<WeeklyReportScreen> {
  // Sample data for the week
  final List<String> _weekDays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  // Temperature data for 7 days (°C)
  final List<double> _temperatureData = [
    32.1,
    32.5,
    33.2,
    32.8,
    34.1,
    33.5,
    32.9,
  ];

  // Pressure data for 7 days (kPa)
  final List<double> _pressureData = [62, 68, 75, 70, 82, 73, 65];

  // Alert counts by category (matching RiskCategory from smart_alert.dart)
  final int _temperatureAlerts = 4; // Temperature-related alerts
  final int _pressureAlerts = 6; // Pressure-related alerts

  bool _isDownloading = false;

  // Calculate summary metrics
  double get _avgTemperature =>
      _temperatureData.reduce((a, b) => a + b) / _temperatureData.length;

  String get _highestRiskDay {
    int maxIndex = 0;
    double maxValue = _temperatureData[0];
    for (int i = 1; i < _temperatureData.length; i++) {
      if (_temperatureData[i] > maxValue) {
        maxValue = _temperatureData[i];
        maxIndex = i;
      }
    }
    return _weekDays[maxIndex];
  }

  int get _totalAlerts => _temperatureAlerts + _pressureAlerts;

  String get _overallRiskStatus {
    // Based on total alerts and severity
    if (_totalAlerts > 8) return 'High';
    if (_totalAlerts > 4) return 'Medium';
    return 'Low';
  }

  Color get _overallRiskColor {
    switch (_overallRiskStatus) {
      case 'High':
        return const Color(0xFFE53935);
      case 'Medium':
        return const Color(0xFFFFA726);
      default:
        return const Color(0xFF4CAF50);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWeekHeader(),
            const SizedBox(height: 20),
            _buildSummaryCard(),
            const SizedBox(height: 24),
            _buildTemperatureChart(),
            const SizedBox(height: 24),
            _buildPressureChart(),
            const SizedBox(height: 24),
            _buildRiskBreakdown(),
            const SizedBox(height: 24),
            _buildDownloadButton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1A1A2E)),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text(
        'Weekly Report',
        style: TextStyle(
          color: Color(0xFF64ADB3),
          fontWeight: FontWeight.bold,
          fontSize: 24,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.share_outlined, color: Color(0xFF6B7280)),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Share feature coming soon'),
                backgroundColor: Color(0xFF64ADB3),
              ),
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildWeekHeader() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF64ADB3).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF64ADB3).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF64ADB3).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              color: Color(0xFF64ADB3),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Report Period',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatDate(weekStart)} - ${_formatDate(weekEnd)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.analytics_rounded,
                color: Color(0xFF64ADB3),
                size: 24,
              ),
              const SizedBox(width: 10),
              const Text(
                'Weekly Summary',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Summary metrics in 2x2 grid
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  icon: Icons.thermostat_rounded,
                  label: 'Avg Temperature',
                  value: '${_avgTemperature.toStringAsFixed(1)}°C',
                  color: _getTempColor(_avgTemperature),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryItem(
                  icon: Icons.warning_amber_rounded,
                  label: 'Highest Risk Day',
                  value: _highestRiskDay,
                  color: const Color(0xFFE53935),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  icon: Icons.notifications_rounded,
                  label: 'Total Alerts',
                  value: '$_totalAlerts',
                  color: const Color(0xFF5C6BC0),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryItem(
                  icon: Icons.health_and_safety_rounded,
                  label: 'Overall Status',
                  value: _overallRiskStatus,
                  color: _overallRiskColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemperatureChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF7043).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.thermostat_rounded,
                      color: Color(0xFFFF7043),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Temperature Trend',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '7 Days',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: CustomPaint(
              size: Size.infinite,
              painter: _SimpleChartPainter(
                data: _temperatureData,
                labels: _weekDays,
                lineColor: const Color(0xFFFF7043),
                minValue: 30,
                maxValue: 36,
                unit: '°C',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPressureChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5C6BC0).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.compress_rounded,
                      color: Color(0xFF5C6BC0),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Pressure Trend',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '7 Days',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: CustomPaint(
              size: Size.infinite,
              painter: _SimpleChartPainter(
                data: _pressureData,
                labels: _weekDays,
                lineColor: const Color(0xFF5C6BC0),
                minValue: 50,
                maxValue: 100,
                unit: 'kPa',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskBreakdown() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF64ADB3).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.pie_chart_rounded,
                  color: Color(0xFF64ADB3),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Alert Breakdown',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Alert breakdown by category (matching RiskCategory)
          _buildAlertBreakdownItem(
            label: 'Temperature Alerts',
            count: _temperatureAlerts,
            color: const Color(0xFFFF7043), // Orange for temperature
            icon: Icons.thermostat_rounded,
            total: _totalAlerts,
          ),
          const SizedBox(height: 12),
          _buildAlertBreakdownItem(
            label: 'Pressure Alerts',
            count: _pressureAlerts,
            color: const Color(0xFF5C6BC0), // Indigo for pressure
            icon: Icons.compress_rounded,
            total: _totalAlerts,
          ),
        ],
      ),
    );
  }

  Widget _buildAlertBreakdownItem({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
    required int total,
  }) {
    double percentage = total > 0 ? count / total : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: percentage,
            minHeight: 10,
            backgroundColor: color.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF64ADB3), Color(0xFF4D9DA3)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64ADB3).withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _isDownloading ? null : _handleDownload,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isDownloading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                else
                  const Icon(
                    Icons.download_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                const SizedBox(width: 12),
                Text(
                  _isDownloading
                      ? 'Generating PDF...'
                      : 'Download Weekly Report (PDF)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleDownload() async {
    setState(() => _isDownloading = true);

    try {
      final pdf = pw.Document();

      // Build PDF content
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) => [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: PdfColors.teal,
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Weekly Health Report',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Feb 24 - Mar 2, 2026',
                    style: const pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // Summary Section
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Weekly Summary',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.teal800,
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      _buildPdfMetric(
                        'Avg Temperature',
                        '${_avgTemperature.toStringAsFixed(1)}°C',
                      ),
                      _buildPdfMetric('Total Alerts', '$_totalAlerts'),
                      _buildPdfMetric('Overall Risk', _overallRiskStatus),
                      _buildPdfMetric('Highest Risk Day', _highestRiskDay),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // Temperature Data Table
            pw.Text(
              'Temperature Trend (°C)',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.teal800,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Table.fromTextArray(
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
              cellAlignment: pw.Alignment.center,
              cellHeight: 30,
              headers: _weekDays,
              data: [
                _temperatureData.map((t) => t.toStringAsFixed(1)).toList(),
              ],
            ),
            pw.SizedBox(height: 24),

            // Pressure Data Table
            pw.Text(
              'Pressure Trend (kPa)',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.teal800,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Table.fromTextArray(
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
              cellAlignment: pw.Alignment.center,
              cellHeight: 30,
              headers: _weekDays,
              data: [_pressureData.map((p) => p.toStringAsFixed(1)).toList()],
            ),
            pw.SizedBox(height: 24),

            // Alert Breakdown
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Alert Breakdown',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.teal800,
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  _buildPdfAlertRow(
                    'Temperature Alerts',
                    _temperatureAlerts,
                    PdfColors.orange,
                  ),
                  pw.SizedBox(height: 8),
                  _buildPdfAlertRow(
                    'Pressure Alerts',
                    _pressureAlerts,
                    PdfColors.indigo,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // Footer
            pw.Container(
              alignment: pw.Alignment.center,
              child: pw.Text(
                'Generated by KHOTAA App - ${DateTime.now().toString().substring(0, 19)}',
                style: const pw.TextStyle(
                  color: PdfColors.grey600,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      );

      // Save PDF to device
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'KHOTAA_Weekly_Report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      setState(() => _isDownloading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Report saved successfully!')),
              ],
            ),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () => OpenFile.open(file.path),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isDownloading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 12),
                Text('Failed to generate report'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  pw.Widget _buildPdfMetric(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.teal,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
        ),
      ],
    );
  }

  pw.Widget _buildPdfAlertRow(String label, int count, PdfColor color) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Row(
          children: [
            pw.Container(
              width: 12,
              height: 12,
              decoration: pw.BoxDecoration(
                color: color,
                shape: pw.BoxShape.circle,
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Text(label),
          ],
        ),
        pw.Text(
          count.toString(),
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Color _getTempColor(double temp) {
    if (temp > 34.0) return const Color(0xFFE53935);
    if (temp > 33.0) return const Color(0xFFFFA726);
    return const Color(0xFF4CAF50);
  }

  String _formatDate(DateTime date) {
    final months = [
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
    return '${date.day} ${months[date.month - 1]}';
  }
}

/// Simple and clear chart painter
class _SimpleChartPainter extends CustomPainter {
  final List<double> data;
  final List<String> labels;
  final Color lineColor;
  final double minValue;
  final double maxValue;
  final String unit;

  _SimpleChartPainter({
    required this.data,
    required this.labels,
    required this.lineColor,
    required this.minValue,
    required this.maxValue,
    required this.unit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final chartHeight = height - 40; // Leave space for labels
    final chartWidth = width - 50; // Leave space for Y-axis labels

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Draw grid lines
    _drawGridLines(canvas, size, chartWidth, chartHeight);

    // Draw Y-axis labels
    _drawYAxisLabels(canvas, size, chartHeight);

    // Draw X-axis labels
    _drawXAxisLabels(canvas, size, chartWidth, chartHeight);

    // Draw the line chart
    final path = Path();
    final points = <Offset>[];

    for (int i = 0; i < data.length; i++) {
      final x = 50 + (i * (chartWidth / (data.length - 1)));
      final normalizedValue = (data[i] - minValue) / (maxValue - minValue);
      final y = chartHeight - (normalizedValue * (chartHeight - 20));
      points.add(Offset(x, y));
    }

    // Draw smooth curve
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1] : points[0];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i < points.length - 2
          ? points[i + 2]
          : points[points.length - 1];

      final cp1x = p1.dx + (p2.dx - p0.dx) / 6;
      final cp1y = p1.dy + (p2.dy - p0.dy) / 6;
      final cp2x = p2.dx - (p3.dx - p1.dx) / 6;
      final cp2y = p2.dy - (p3.dy - p1.dy) / 6;

      path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
    }

    canvas.drawPath(path, paint);

    // Draw area under the curve
    final areaPath = Path.from(path);
    areaPath.lineTo(points.last.dx, chartHeight);
    areaPath.lineTo(points.first.dx, chartHeight);
    areaPath.close();

    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [lineColor.withOpacity(0.3), lineColor.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, width, chartHeight));
    canvas.drawPath(areaPath, areaPaint);

    // Draw data points
    for (int i = 0; i < points.length; i++) {
      // Outer circle
      canvas.drawCircle(
        points[i],
        8,
        Paint()..color = lineColor.withOpacity(0.2),
      );
      // Inner circle
      canvas.drawCircle(points[i], 5, Paint()..color = Colors.white);
      // Core circle
      canvas.drawCircle(points[i], 4, Paint()..color = lineColor);

      // Draw value label
      final textPainter = TextPainter(
        text: TextSpan(
          text: data[i].toStringAsFixed(1),
          style: TextStyle(
            color: lineColor,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(points[i].dx - textPainter.width / 2, points[i].dy - 22),
      );
    }
  }

  void _drawGridLines(
    Canvas canvas,
    Size size,
    double chartWidth,
    double chartHeight,
  ) {
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.15)
      ..strokeWidth = 1;

    // Horizontal grid lines
    for (int i = 0; i <= 4; i++) {
      final y = (chartHeight / 4) * i;
      canvas.drawLine(Offset(50, y), Offset(size.width, y), gridPaint);
    }
  }

  void _drawYAxisLabels(Canvas canvas, Size size, double chartHeight) {
    final range = maxValue - minValue;
    final step = range / 4;

    for (int i = 0; i <= 4; i++) {
      final value = maxValue - (step * i);
      final y = (chartHeight / 4) * i;

      final textPainter = TextPainter(
        text: TextSpan(
          text: value.toStringAsFixed(0),
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(45 - textPainter.width, y - textPainter.height / 2),
      );
    }
  }

  void _drawXAxisLabels(
    Canvas canvas,
    Size size,
    double chartWidth,
    double chartHeight,
  ) {
    for (int i = 0; i < labels.length; i++) {
      final x = 50 + (i * (chartWidth / (labels.length - 1)));

      final textPainter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, chartHeight + 12),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
