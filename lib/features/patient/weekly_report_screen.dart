import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../sensor_alerts/alert_service.dart';
import '../../models/alert.dart';
import '../../services/daily_sensor_summary_service.dart';

class WeeklyReportScreen extends StatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  State<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends State<WeeklyReportScreen> {
  final List<String> _weekDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  // Alert counts (from AlertService)
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
    _loadChartData();
    _loadAlertCounts();
    // Re-render whenever daily summaries update (live sensor accumulation)
    DailySensorSummaryService().addListener(_loadChartData);
    // Re-render whenever alert service syncs new data from Firestore
    AlertService().addListener(_loadAlertCounts);
  }

  @override
  void dispose() {
    DailySensorSummaryService().removeListener(_loadChartData);
    AlertService().removeListener(_loadAlertCounts);
    super.dispose();
  }

  void _computeWeekBounds() {
    final now = DateTime.now();
    // Monday of current week
    // Sunday = weekday 7 in Dart, so offset = weekday % 7
    _weekStart = DateTime(now.year, now.month, now.day - (now.weekday % 7));
    _weekEnd = _weekStart.add(const Duration(days: 6));
  }

  /// Trigger rebuild whenever DailySensorSummaryService updates.
  void _loadChartData() => setState(() {});

  /// Alert breakdown counts — still derived from AlertService.
  void _loadAlertCounts() {
    final allAlerts = AlertService().alerts;

    final weekAlerts = allAlerts.where((a) {
      return a.notificationType == NotificationType.health &&
          !a.timestamp.isBefore(_weekStart) &&
          a.timestamp.isBefore(_weekEnd.add(const Duration(days: 1)));
    }).toList();

    int tempAlerts = 0;
    int pressureAlerts = 0;
    int combinedAlerts = 0;

    for (final alert in weekAlerts) {
      switch (alert.category) {
        case RiskCategory.temperature:
          tempAlerts++;
          break;
        case RiskCategory.pressure:
          pressureAlerts++;
          break;
        case RiskCategory.combined:
          combinedAlerts++;
          break;
      }
    }

    setState(() {
      _temperatureAlerts = tempAlerts;
      _pressureAlerts = pressureAlerts;
      _combinedAlerts = combinedAlerts;
    });
  }

  // ── Summary getters ──────────────────────────────────────────────────────

  DailySensorSummaryService get _svc => DailySensorSummaryService();

  double get _peakAsymmetryThisWeek => _svc.weeklyPeakAsymmetry;
  double get _peakPressureThisWeek  => _svc.weeklyPeakPressureKpa;

  int get _totalAlerts => _temperatureAlerts + _pressureAlerts + _combinedAlerts;

  String get _highestRiskDay {
    final levels = _svc.weekDailyRiskLevels;
    int maxIdx = -1;
    int maxVal = 0;
    for (int i = 0; i < levels.length; i++) {
      if (levels[i] > maxVal) { maxVal = levels[i]; maxIdx = i; }
    }
    return maxIdx >= 0 ? _weekDays[maxIdx] : '-';
  }

  String get _overallRiskStatus {
    final p = _peakPressureThisWeek;
    final a = _peakAsymmetryThisWeek;
    if ((p >= 200.0 && a >= 2.2) || _combinedAlerts > 0 || _totalAlerts > 8) return 'High';
    if (p >= 200.0 || a >= 2.2 || _totalAlerts > 4) return 'Medium';
    if (_totalAlerts > 0 || p > 0 || a > 0) return 'Low';
    return 'Normal';
  }

  Color get _overallRiskColor {
    switch (_overallRiskStatus) {
      case 'High':   return const Color(0xFFE53935);
      case 'Medium': return const Color(0xFFFFA726);
      case 'Low':    return const Color(0xFF4CAF50);
      default:       return const Color(0xFF4CAF50);
    }
  }

  Color _asymmetryColor(double v) {
    if (v >= 2.2) return const Color(0xFFE53935); // expert system threshold
    if (v >  0)   return const Color(0xFF4CAF50);
    return Colors.grey;
  }

  Color _pressureColor(double kpa) {
    if (kpa >= 200.0) return const Color(0xFFE53935); // expert system threshold
    if (kpa >  0)     return const Color(0xFF4CAF50);
    return Colors.grey;
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
            _buildDailyRiskCalendar(),
            const SizedBox(height: 24),
            _buildRegionRiskTable(),
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
                  label: 'Peak Asymmetry',
                  value: _peakAsymmetryThisWeek > 0
                      ? '${_peakAsymmetryThisWeek.toStringAsFixed(1)}°C'
                      : '--',
                  color: _asymmetryColor(_peakAsymmetryThisWeek),
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

  // ── 7-Day Risk Calendar ────────────────────────────────────────────────────
  // Each day = a colored box: grey=no data · green=normal · orange=moderate · red=high
  // The patient and doctor can see at a glance which days had risk events.

  Widget _buildDailyRiskCalendar() {
    final riskLevels = _svc.weekDailyRiskLevels;
    final today      = DateTime.now().weekday % 7; // Sun=0…Sat=6

    Color boxColor(int level) {
      switch (level) {
        case 3:  return const Color(0xFFE53935);
        case 2:  return const Color(0xFFFFA726);
        case 1:  return const Color(0xFF4CAF50);
        default: return const Color(0xFFE8ECEF);
      }
    }

    String boxLabel(int level) {
      switch (level) {
        case 3:  return 'High';
        case 2:  return 'Moderate';
        case 1:  return 'OK';
        default: return '–';
      }
    }

    return _cardWrap(
      title: 'Daily Risk Overview',
      icon: Icons.calendar_month_rounded,
      iconColor: const Color(0xFF64ADB3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
        children: List.generate(7, (i) {
          final level   = riskLevels[i];
          final color   = boxColor(level);
          final isToday = i == today;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                children: [
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: color.withOpacity(level == 0 ? 0.4 : 0.85),
                      borderRadius: BorderRadius.circular(12),
                      border: isToday
                          ? Border.all(color: const Color(0xFF1A1A2E), width: 2)
                          : null,
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            boxLabel(level),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: level == 0 ? Colors.grey[500] : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _weekDays[i],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                      color: isToday
                          ? const Color(0xFF1A1A2E)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
          ),
          const SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _legendDot(const Color(0xFF4CAF50), 'Normal – pressure & temperature both within range'),
              const SizedBox(height: 5),
              _legendDot(const Color(0xFFFFA726), 'Moderate – high pressure OR high temperature'),
              const SizedBox(height: 5),
              _legendDot(const Color(0xFFE53935), 'High – both pressure & temperature elevated'),
            ],
          ),
        ],
      ),
    );
  }

  // ── Region Risk Table ──────────────────────────────────────────────────────
  // 8 anatomical rows × (Left kPa | Right kPa | Asymmetry °C)
  // Color coded against IWGDF thresholds. Exactly what a podiatrist needs.

  Widget _buildRegionRiskTable() {
    final leftP   = _svc.weeklyLeftPeakPressure;
    final rightP  = _svc.weeklyRightPeakPressure;
    final asymm   = _svc.weeklyPeakAsymmetryPerRegion;

    final hasAnyData = leftP.any((v) => v > 0) ||
        rightP.any((v) => v > 0) ||
        asymm.any((v) => v > 0);

    Widget headerCell(String text, {Color? color}) => Expanded(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color ?? const Color(0xFF6B7280),
        ),
      ),
    );

    Widget valueCell(double val, Color color, String suffix) => Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: val > 0 ? color.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: val > 0
              ? Border.all(color: color.withOpacity(0.3), width: 1)
              : null,
        ),
        child: Text(
          val > 0 ? '${val.toStringAsFixed(0)}$suffix' : '–',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: val > 0 ? color : Colors.grey[400],
          ),
        ),
      ),
    );

    return _cardWrap(
      title: 'Highest Readings This Week by Region',
      icon: Icons.grid_view_rounded,
      iconColor: const Color(0xFF5C6BC0),
      child: Column(
        children: [
          // Threshold legend
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendDot(const Color(0xFF4CAF50), 'Normal'),
                const SizedBox(width: 12),
                _legendDot(const Color(0xFFE53935), 'High pressure ≥200 kPa or\nasymmetry ≥2.2°C'),
              ],
            ),
          ),
          // Header row
          Row(
            children: [
              const SizedBox(width: 60),
              headerCell('Left Pressure\n(kPa)',  color: const Color(0xFF5C6BC0)),
              headerCell('Right Pressure\n(kPa)', color: const Color(0xFF42A5F5)),
              headerCell('Asymmetry\n(°C)',        color: const Color(0xFFFF7043)),
            ],
          ),
          const Divider(height: 8),
          if (!hasAnyData)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No insole data this week yet',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
              ),
            )
          else
            ...List.generate(8, (r) {
              final lp = leftP[r];
              final rp = rightP[r];
              final as_ = asymm[r];
              return Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(
                      kRegionLabels[r],
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                  ),
                  valueCell(lp,  _pressureColor(lp),  ' kPa'),
                  valueCell(rp,  _pressureColor(rp),  ' kPa'),
                  valueCell(as_, _asymmetryColor(as_), '°C'),
                ],
              );
            }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ── Shared card wrapper ────────────────────────────────────────────────────

  Widget _cardWrap({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
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
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
    ],
  );

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
                        'Peak Pressure',
                        '${_peakPressureThisWeek.toStringAsFixed(0)} kPa',
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

            // Per-Region Peak Pressure & Asymmetry Table
            pw.Text(
              'Peak Values by Region (This Week)',
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
              headers: ['Region', 'Left (kPa)', 'Right (kPa)', 'Asymmetry (°C)'],
              data: List.generate(8, (r) {
                final lp = _svc.weeklyLeftPeakPressure[r];
                final rp = _svc.weeklyRightPeakPressure[r];
                final as_ = _svc.weeklyPeakAsymmetryPerRegion[r];
                return [
                  kRegionLabels[r],
                  lp > 0 ? lp.toStringAsFixed(0) : '–',
                  rp > 0 ? rp.toStringAsFixed(0) : '–',
                  as_ > 0 ? as_.toStringAsFixed(1) : '–',
                ];
              }),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'IWGDF 2023: Risk threshold ≥ 200 kPa · ≥ 2.2°C asymmetry',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
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
    } catch (e, stack) {
      debugPrint('PDF generation error: $e\n$stack');
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

