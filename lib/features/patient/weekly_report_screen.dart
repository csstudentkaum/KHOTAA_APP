import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../sensor_alerts/alert_service.dart';
import '../../models/alert.dart';

class WeeklyReportScreen extends StatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  State<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends State<WeeklyReportScreen> {
  final List<String> _weekDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  // Computed from real AlertService data
  List<double> _temperatureData = List.filled(7, 0.0);
  List<double> _pressureData = List.filled(7, 0.0);

  int _temperatureAlerts = 0;
  int _pressureAlerts = 0;
  int _combinedAlerts = 0;

  late DateTime _weekStart;
  late DateTime _weekEnd;

  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _computeWeekBounds();
    _loadReportData();
    // Re-render whenever AlertService syncs new data from Firestore
    AlertService().addListener(_loadReportData);
  }

  @override
  void dispose() {
    AlertService().removeListener(_loadReportData);
    super.dispose();
  }

  void _computeWeekBounds() {
    final now = DateTime.now();
    // Monday of current week
    // Sunday = weekday 7 in Dart, so offset = weekday % 7
    _weekStart = DateTime(now.year, now.month, now.day - (now.weekday % 7));
    _weekEnd = _weekStart.add(const Duration(days: 6));
  }

  void _loadReportData() {
    final allAlerts = AlertService().alerts;

    // Filter: health alerts within this week only
    final weekAlerts = allAlerts.where((a) {
      return a.notificationType == NotificationType.health &&
          !a.timestamp.isBefore(_weekStart) &&
          a.timestamp.isBefore(_weekEnd.add(const Duration(days: 1)));
    }).toList();

    // Daily accumulators
    final tempSums = List<double>.filled(7, 0.0);
    final tempCounts = List<int>.filled(7, 0);
    final pressureSums = List<double>.filled(7, 0.0);
    final pressureCounts = List<int>.filled(7, 0);

    int tempAlerts = 0;
    int pressureAlerts = 0;
    int combinedAlerts = 0;

    for (final alert in weekAlerts) {
      // weekday in Dart: 1=Mon...7=Sun. We want Sun=0, Mon=1...Sat=6
      final dayIndex = alert.timestamp.weekday % 7;

      switch (alert.category) {
        case RiskCategory.temperature:
          tempAlerts++;
          break;
        case RiskCategory.pressure:
          pressureAlerts++;
          break;
        case RiskCategory.combined:
          // Combined counts as BOTH temperature and pressure for breakdown
          combinedAlerts++;
          break;
      }

      // Accumulate real sensor readings from sensorData
      final sensor = alert.sensorData;
      if (sensor != null) {
        final t = (sensor['temperatureValue'] as num?)?.toDouble();
        final p = (sensor['pressureValue'] as num?)?.toDouble();
        if (t != null && t > 0) {
          tempSums[dayIndex] += t;
          tempCounts[dayIndex]++;
        }
        if (p != null && p > 0) {
          pressureSums[dayIndex] += p;
          pressureCounts[dayIndex]++;
        }
      }
    }

    setState(() {
      // Daily average — 0.0 means no reading for that day
      _temperatureData = List.generate(
        7, (i) => tempCounts[i] > 0 ? tempSums[i] / tempCounts[i] : 0.0);
      _pressureData = List.generate(
        7, (i) => pressureCounts[i] > 0 ? pressureSums[i] / pressureCounts[i] : 0.0);
      _temperatureAlerts = tempAlerts;
      _pressureAlerts = pressureAlerts;
      _combinedAlerts = combinedAlerts;
    });
  }

  // ── Summary metrics ──

  double get _avgTemperature {
    final nonZero = _temperatureData.where((v) => v > 0).toList();
    if (nonZero.isEmpty) return 0.0;
    return nonZero.reduce((a, b) => a + b) / nonZero.length;
  }

  String get _highestRiskDay {
    // Day with highest average temperature reading (most inflammation risk)
    int maxIndex = -1;
    double maxValue = 0.0;
    for (int i = 0; i < _temperatureData.length; i++) {
      if (_temperatureData[i] > maxValue) {
        maxValue = _temperatureData[i];
        maxIndex = i;
      }
    }
    return maxIndex >= 0 ? _weekDays[maxIndex] : '-';
  }

  /// Total health alerts this week (combined counts once)
  int get _totalAlerts => _temperatureAlerts + _pressureAlerts + _combinedAlerts;

  String get _overallRiskStatus {
    if (_combinedAlerts > 0 || _totalAlerts > 8) return 'High';
    if (_totalAlerts > 4) return 'Medium';
    if (_totalAlerts > 0) return 'Low';
    return 'Normal';
  }

  Color get _overallRiskColor {
    switch (_overallRiskStatus) {
      case 'High':
        return const Color(0xFFE53935);
      case 'Medium':
        return const Color(0xFFFFA726);
      case 'Low':
        return const Color(0xFF4CAF50);
      default:
        return const Color(0xFF4CAF50);
    }
  }

  // Dynamic chart bounds based on real data
  double get _tempMin {
    final nonZero = _temperatureData.where((v) => v > 0);
    return nonZero.isEmpty ? 28.0 : (nonZero.reduce(min) - 2).floorToDouble();
  }

  double get _tempMax {
    final nonZero = _temperatureData.where((v) => v > 0);
    return nonZero.isEmpty ? 38.0 : (nonZero.reduce(max) + 2).ceilToDouble();
  }

  double get _pressureMin {
    final nonZero = _pressureData.where((v) => v > 0);
    return nonZero.isEmpty ? 50.0 : (nonZero.reduce(min) - 20).floorToDouble().clamp(0, double.infinity);
  }

  double get _pressureMax {
    final nonZero = _pressureData.where((v) => v > 0);
    return nonZero.isEmpty ? 250.0 : (nonZero.reduce(max) + 20).ceilToDouble();
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
                  '${_formatDate(_weekStart)} - ${_formatDate(_weekEnd)}',
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
                minValue: _tempMin,
                maxValue: _tempMax,
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
                minValue: _pressureMin,
                maxValue: _pressureMax,
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
          if (_totalAlerts == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No alerts recorded this week',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 15),
                ),
              ),
            )
          else ...[
            _buildAlertBreakdownItem(
              label: 'Temperature Alerts',
              count: _temperatureAlerts,
              color: const Color(0xFFFF7043),
              icon: Icons.thermostat_rounded,
              total: _totalAlerts,
            ),
            const SizedBox(height: 12),
            _buildAlertBreakdownItem(
              label: 'Pressure Alerts',
              count: _pressureAlerts,
              color: const Color(0xFF5C6BC0),
              icon: Icons.compress_rounded,
              total: _totalAlerts,
            ),
            if (_combinedAlerts > 0) ...[
              const SizedBox(height: 12),
              _buildAlertBreakdownItem(
                label: 'Combined Alerts (Temp + Pressure)',
                count: _combinedAlerts,
                color: const Color(0xFFE53935),
                icon: Icons.warning_rounded,
                total: _totalAlerts,
              ),
            ],
          ],
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
                    '${_formatDate(_weekStart)} - ${_formatDate(_weekEnd)}',
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
                  _buildPdfAlertRow('Temperature Alerts', _temperatureAlerts, PdfColors.orange),
                  pw.SizedBox(height: 8),
                  _buildPdfAlertRow('Pressure Alerts', _pressureAlerts, PdfColors.indigo),
                  if (_combinedAlerts > 0) ...[
                    pw.SizedBox(height: 8),
                    _buildPdfAlertRow('Combined Alerts (Temp + Pressure)', _combinedAlerts, PdfColors.red),
                  ],
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
    const double topPad    = 30;   // space for value labels above dots
    const double bottomPad = 40;   // space for X-axis labels
    const double leftPad   = 50;   // space for Y-axis labels
    final double chartH    = height - topPad - bottomPad;
    final double chartW    = width  - leftPad;
    final double range     = (maxValue - minValue).clamp(0.001, double.infinity);

    // ── coordinate helpers ──────────────────────────────────────────
    double toY(double v) =>
        topPad + chartH - ((v - minValue) / range) * chartH;
    double toX(int i)    =>
        leftPad + i * (chartW / (data.length - 1));

    // ── trend color per segment ──────────────────────────────────────
    // Rising  → red   (higher pressure / temperature = worse)
    // Falling → green (getting better)
    // Stable  → lineColor
    Color trendColor(double from, double to) {
      final pct = (to - from) / from;
      if (pct > 0.03)  return const Color(0xFFE53935); // ↑ worse
      if (pct < -0.03) return const Color(0xFF43A047); // ↓ better
      return lineColor;                                 // → stable
    }

    // ── 1. Grid lines ────────────────────────────────────────────────
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.15)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = topPad + (chartH / 4) * i;
      canvas.drawLine(Offset(leftPad, y), Offset(width, y), gridPaint);
    }

    // ── 2. Y-axis labels ─────────────────────────────────────────────
    final yStep = range / 4;
    for (int i = 0; i <= 4; i++) {
      final value = maxValue - yStep * i;
      final y     = topPad + (chartH / 4) * i;
      final tp = TextPainter(
        text: TextSpan(
          text: value.toStringAsFixed(0),
          style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w500),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPad - tp.width - 4, y - tp.height / 2));
    }

    // ── 3. X-axis labels + empty-day markers ────────────────────────
    for (int i = 0; i < labels.length; i++) {
      final hasData = data[i] > 0;
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: hasData ? Colors.grey[700] : Colors.grey[400],
            fontSize: 12,
            fontWeight: hasData ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(toX(i) - tp.width / 2, topPad + chartH + 10));

      if (!hasData) {
        // hollow circle at mid-chart height for empty days
        final emptyY = topPad + chartH * 0.5;
        canvas.drawCircle(
          Offset(toX(i), emptyY), 4,
          Paint()
            ..color = Colors.grey[300]!
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        final dash = TextPainter(
          text: TextSpan(
            text: 'No data',
            style: TextStyle(color: Colors.grey[400], fontSize: 9),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        dash.paint(canvas, Offset(toX(i) - dash.width / 2, emptyY - 16));
      }
    }

    // ── 4. Collect non-zero points (preserving x position = day slot) ─
    final nonZeroEntries = <MapEntry<int, double>>[];
    for (int i = 0; i < data.length; i++) {
      if (data[i] > 0) nonZeroEntries.add(MapEntry(i, data[i]));
    }

    if (nonZeroEntries.isEmpty) return;

    final pts = nonZeroEntries
        .map((e) => Offset(toX(e.key), toY(e.value)))
        .toList();

    // ── 5. Colored trend segments ────────────────────────────────────
    for (int i = 0; i < pts.length - 1; i++) {
      final fromVal = nonZeroEntries[i].value;
      final toVal   = nonZeroEntries[i + 1].value;
      final segColor = trendColor(fromVal, toVal);

      // Smooth bezier between consecutive non-zero points
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final cpX = (p1.dx + p2.dx) / 2;
      final segPath = Path()
        ..moveTo(p1.dx, p1.dy)
        ..cubicTo(cpX, p1.dy, cpX, p2.dy, p2.dx, p2.dy);

      canvas.drawPath(
        segPath,
        Paint()
          ..color = segColor
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );

      // Subtle area fill under segment
      final areaPath = Path()
        ..moveTo(p1.dx, p1.dy)
        ..cubicTo(cpX, p1.dy, cpX, p2.dy, p2.dx, p2.dy)
        ..lineTo(p2.dx, topPad + chartH)
        ..lineTo(p1.dx, topPad + chartH)
        ..close();
      canvas.drawPath(
        areaPath,
        Paint()
          ..color = segColor.withOpacity(0.10),
      );

      // Mid-segment trend arrow label
      final midX = (p1.dx + p2.dx) / 2;
      final midY = (p1.dy + p2.dy) / 2 - 14;
      final arrow = toVal > fromVal * 1.03 ? '↑'
                  : toVal < fromVal * 0.97 ? '↓'
                  : '→';
      final arrowTp = TextPainter(
        text: TextSpan(
          text: arrow,
          style: TextStyle(color: segColor, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      arrowTp.paint(canvas, Offset(midX - arrowTp.width / 2, midY.clamp(topPad, topPad + chartH - 14)));
    }

    // ── 6. Dots + value labels on each non-zero point ────────────────
    for (int i = 0; i < pts.length; i++) {
      final pt  = pts[i];
      final val = nonZeroEntries[i].value;

      // Dot
      canvas.drawCircle(pt, 9,  Paint()..color = lineColor.withOpacity(0.18));
      canvas.drawCircle(pt, 5,  Paint()..color = Colors.white);
      canvas.drawCircle(pt, 4,  Paint()..color = lineColor);

      // Value label above dot — always inside bounds
      final valTp = TextPainter(
        text: TextSpan(
          text: val.toStringAsFixed(1),
          style: TextStyle(color: lineColor, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelY = (pt.dy - 22).clamp(2.0, topPad + chartH - valTp.height - 2);
      valTp.paint(canvas, Offset(pt.dx - valTp.width / 2, labelY));
    }

    // ── 7. Overall trend badge (top-right corner) ────────────────────
    if (nonZeroEntries.length >= 2) {
      final first = nonZeroEntries.first.value;
      final last  = nonZeroEntries.last.value;
      final pct   = (last - first) / first;
      final badgeText = pct >  0.03 ? '↑ Rising'
                      : pct < -0.03 ? '↓ Improving'
                      : '→ Stable';
      final badgeColor = pct >  0.03 ? const Color(0xFFE53935)
                       : pct < -0.03 ? const Color(0xFF43A047)
                       : Colors.grey[600]!;

      final badgeTp = TextPainter(
        text: TextSpan(
          text: badgeText,
          style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final badgeRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          width - badgeTp.width - 18,
          2,
          badgeTp.width + 14,
          badgeTp.height + 8,
        ),
        const Radius.circular(20),
      );
      canvas.drawRRect(badgeRect, Paint()..color = badgeColor.withOpacity(0.12));
      badgeTp.paint(canvas, Offset(width - badgeTp.width - 11, 6));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
