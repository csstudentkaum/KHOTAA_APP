import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/expert_system/expert_system.dart';
import 'weekly_report_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  // Expert System Integration
  final ExpertSystemIntegration _expertSystem = ExpertSystemIntegration();
  ExpertSystemResult? _lastExpertResult;

  // Connection status
  bool _isConnected = true;
  bool _hasAbnormalReading = false; // Expert system detection
  String _abnormalType = ''; // 'pressure', 'temperature', or 'both'

  // Real-time data
  double _temperature = 32.5;
  double _pressure = 65.0;
  int _stepsToday = 4523;
  Duration _wearingDuration = const Duration(hours: 3, minutes: 45);

  // Foot sensor data (simulated)
  List<double> _leftFootPressure = [0.3, 0.5, 0.7, 0.4, 0.6];
  List<double> _rightFootPressure = [0.4, 0.3, 0.5, 0.8, 0.4];
  List<double> _leftFootTemp = [32.0, 32.5, 33.0, 32.2, 32.8];
  List<double> _rightFootTemp = [32.3, 32.1, 32.8, 33.5, 32.5];

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _dataUpdateController;
  late Animation<double> _pulseAnimation;

  Timer? _dataTimer;
  Timer? _durationTimer;
  Timer? _statusSyncTimer;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startDataSimulation();
    _startDurationTimer();
    _syncMonitoringStatusToFirestore(active: true);
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _dataUpdateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  void _startDataSimulation() {
    _dataTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          final random = Random();
          // Simulate temperature changes
          _temperature = 31.5 + random.nextDouble() * 3.5;
          _pressure = 55 + random.nextDouble() * 30;
          _stepsToday += random.nextInt(15);

          // Update foot sensor data
          _updateFootSensorData(random);

          // Check for abnormal readings (simple threshold check)
          _checkForAbnormalReadings();
        });
        _dataUpdateController.forward().then(
          (_) => _dataUpdateController.reset(),
        );
      }
    });
  }

  void _updateFootSensorData(Random random) {
    for (int i = 0; i < 5; i++) {
      _leftFootPressure[i] = (0.2 + random.nextDouble() * 0.7).clamp(0.0, 1.0);
      _rightFootPressure[i] = (0.2 + random.nextDouble() * 0.7).clamp(0.0, 1.0);
      _leftFootTemp[i] = 31.5 + random.nextDouble() * 3.0;
      _rightFootTemp[i] = 31.5 + random.nextDouble() * 3.0;
    }
  }

  // Expert system threshold-based abnormal detection
  // Uses IWGDF clinical thresholds for accurate risk assessment
  void _checkForAbnormalReadings() async {
    // Get max temperature from each foot for expert system input
    final leftMaxTemp = _leftFootTemp.reduce(max);
    final rightMaxTemp = _rightFootTemp.reduce(max);

    // Get max pressure (convert 0-1 range to kPa for expert system)
    final maxPressure =
        [..._leftFootPressure, ..._rightFootPressure].reduce(max) *
        300; // Scale to approximate kPa

    // Use expert system for evaluation
    try {
      final result = await _expertSystem.processSensorData(
        leftFootTemperature: leftMaxTemp,
        rightFootTemperature: rightMaxTemp,
        plantarPressure: maxPressure,
        pressureBaseline: 150.0, // Default baseline in kPa
        sensorRegion:
            SensorRegion.metatarsal1, // Default to MTK1 for simulation
        footSide: 'left',
      );

      if (mounted) {
        setState(() {
          _lastExpertResult = result;
          _hasAbnormalReading = result.hasRisk;

          // Determine abnormal type from triggered rules
          if (result.hasRisk) {
            final hasTemp = result.triggeredRules.any(
              (r) => r.type == RuleType.temperatureAsymmetry,
            );
            final hasPressure = result.triggeredRules.any(
              (r) =>
                  r.type == RuleType.elevatedPressure ||
                  r.type == RuleType.pressureAboveBaseline,
            );
            final hasCombined = result.triggeredRules.any(
              (r) => r.type == RuleType.combinedRisk,
            );

            if (hasCombined || (hasTemp && hasPressure)) {
              _abnormalType = 'both';
            } else if (hasPressure) {
              _abnormalType = 'pressure';
            } else if (hasTemp) {
              _abnormalType = 'temperature';
            } else {
              _abnormalType = 'both'; // Default for combined risk
            }
          } else {
            _abnormalType = '';
          }
        });
      }
    } catch (e) {
      debugPrint('Expert system error: $e');
      // Fallback to simple threshold check
      _performSimpleThresholdCheck();
    }
  }

  // Fallback simple threshold check
  void _performSimpleThresholdCheck() {
    const double pressureThreshold = 0.75;
    const double tempHighThreshold = 34.0;
    const double tempLowThreshold = 30.5;

    double maxPressure = [
      ..._leftFootPressure,
      ..._rightFootPressure,
    ].reduce(max);
    double maxTemp = [..._leftFootTemp, ..._rightFootTemp].reduce(max);
    double minTemp = [..._leftFootTemp, ..._rightFootTemp].reduce(min);

    final bool abnormalPressure = maxPressure > pressureThreshold;
    final bool abnormalTemp =
        maxTemp > tempHighThreshold || minTemp < tempLowThreshold;

    if (abnormalPressure && abnormalTemp) {
      _hasAbnormalReading = true;
      _abnormalType = 'both';
    } else if (abnormalPressure) {
      _hasAbnormalReading = true;
      _abnormalType = 'pressure';
    } else if (abnormalTemp) {
      _hasAbnormalReading = true;
      _abnormalType = 'temperature';
    } else {
      _hasAbnormalReading = false;
      _abnormalType = '';
    }
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {
          _wearingDuration += const Duration(minutes: 1);
        });
      }
    });
  }

  @override
  void dispose() {
    _statusSyncTimer?.cancel();
    _syncMonitoringStatusToFirestore(active: false);
    _pulseController.dispose();
    _dataUpdateController.dispose();
    _dataTimer?.cancel();
    _durationTimer?.cancel();
    super.dispose();
  }

  /// Sync monitoring status to Firestore so the doctor can see it in real-time.
  /// When `active: true`, also starts a periodic heartbeat every 5 seconds.
  void _syncMonitoringStatusToFirestore({required bool active}) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final ref = FirebaseFirestore.instance.collection('users').doc(uid);

    if (active) {
      // Write "active" immediately
      _writeInsoleHeartbeat(ref);

      // Keep a heartbeat every 5s so the doctor sees real-time data
      _statusSyncTimer?.cancel();
      _statusSyncTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted) return;
        _writeInsoleHeartbeat(ref);
      });
    } else {
      // Dashboard closed — mark monitoring as inactive
      _statusSyncTimer?.cancel();
      ref
          .set({
            'insoleStatus': {
              'monitoring': false,
              'lastActive': FieldValue.serverTimestamp(),
            },
          }, SetOptions(merge: true))
          .catchError((_) {});
    }
  }

  void _writeInsoleHeartbeat(DocumentReference ref) {
    ref
        .set({
          'insoleStatus': {
            'connected': _isConnected,
            'monitoring': true,
            'lastActive': FieldValue.serverTimestamp(),
            'temperature': _temperature,
            'pressure': _pressure,
            'stepsToday': _stepsToday,
            'wearingMinutes': _wearingDuration.inMinutes,
            'leftFootPressure': _leftFootPressure,
            'rightFootPressure': _rightFootPressure,
            'hasAbnormalReading': _hasAbnormalReading,
            'abnormalType': _abnormalType,
          },
        }, SetOptions(merge: true))
        .catchError((_) {});
  }

  // Get status color based on abnormal readings
  Color _getStatusColor() {
    return _hasAbnormalReading
        ? const Color(0xFFF57C00)
        : const Color(0xFF4CAF50);
  }

  // Get abnormal message for alert banner
  String _getAbnormalMessage() {
    switch (_abnormalType) {
      case 'pressure':
        return 'Abnormal pressure detected. Please check your foot or reduce pressure.';
      case 'temperature':
        return 'Abnormal temperature detected. Please check your foot.';
      case 'both':
        return 'Abnormal pressure and temperature detected. Please check your foot.';
      default:
        return '';
    }
  }

  // Simple alert banner - only shows when abnormal (non-intrusive)
  Widget _buildAlertBanner() {
    if (!_hasAbnormalReading) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1), // Light amber - calm alert
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCC02), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFCC02).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.info_outline,
              color: Color(0xFFF57C00),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Attention Needed',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF57C00),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getAbnormalMessage(),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Simple alert banner - only shows when abnormal
              _buildAlertBanner(),
              _buildLiveStatusSection(),
              const SizedBox(height: 24),
              _buildFootVisualization(),
              const SizedBox(height: 24),
              _buildRealTimeMetrics(),
              const SizedBox(height: 24),
              _buildWeeklyReportButton(),
              const SizedBox(height: 20),
            ],
          ),
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
        'Foot Health Status',
        style: TextStyle(
          color: Color(0xFF64ADB3),
          fontWeight: FontWeight.bold,
          fontSize: 24,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildLiveStatusSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.white.withOpacity(0.95)],
        ),
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
        children: [
          Row(
            children: [
              // Connection Status
              Expanded(
                child: _buildStatusItem(
                  icon: _isConnected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  label: 'Connection',
                  value: _isConnected ? 'Connected' : 'Disconnected',
                  valueColor: _isConnected
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFE53935),
                  iconBgColor: _isConnected
                      ? const Color(0xFF4CAF50).withOpacity(0.1)
                      : const Color(0xFFE53935).withOpacity(0.1),
                ),
              ),
              Container(
                height: 50,
                width: 1,
                color: Colors.grey.withOpacity(0.2),
              ),
              // Live Monitoring
              Expanded(child: _buildLiveMonitoringIndicator()),
            ],
          ),
          const SizedBox(height: 20),
          // Foot Status (simplified - no risk levels)
          _buildStatusIndicator(),
        ],
      ),
    );
  }

  Widget _buildStatusItem({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
    required Color iconBgColor,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iconBgColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: valueColor, size: 28),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildLiveMonitoringIndicator() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                boxShadow: _isConnected
                    ? [
                        BoxShadow(
                          color: const Color(
                            0xFF4CAF50,
                          ).withOpacity(0.3 * _pulseAnimation.value),
                          blurRadius: 15 * _pulseAnimation.value,
                          spreadRadius: 2 * _pulseAnimation.value,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                Icons.monitor_heart,
                color: _isConnected ? const Color(0xFF4CAF50) : Colors.grey,
                size: 28,
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Text(
          'Live Monitoring',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isConnected) ...[
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF4CAF50,
                          ).withOpacity(0.5 * _pulseAnimation.value),
                          blurRadius: 6 * _pulseAnimation.value,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 6),
            ],
            Text(
              _isConnected ? 'Active' : 'Inactive',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _isConnected ? const Color(0xFF4CAF50) : Colors.grey,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Simple status indicator - calm and patient-friendly
  Widget _buildStatusIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getStatusColor().withOpacity(0.1),
            _getStatusColor().withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getStatusColor().withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _getStatusColor().withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _hasAbnormalReading
                  ? Icons.info_outline
                  : Icons.check_circle_outline,
              color: _getStatusColor(),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Foot Status',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _hasAbnormalReading ? 'Needs Attention' : 'Normal',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFootVisualization() {
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
              const Text(
                'Foot Visualization',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF64ADB3).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF64ADB3),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Real-time',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64ADB3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Foot diagrams
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSimpleFoot(
                label: 'Left Foot',
                pressureValues: _leftFootPressure,
                isLeft: true,
              ),
              _buildSimpleFoot(
                label: 'Right Foot',
                pressureValues: _rightFootPressure,
                isLeft: false,
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Color legend
          _buildSimpleLegend(),
        ],
      ),
    );
  }

  Widget _buildSimpleFoot({
    required String label,
    required List<double> pressureValues,
    required bool isLeft,
  }) {
    // Calculate average pressure to determine status
    double avgPressure =
        pressureValues.reduce((a, b) => a + b) / pressureValues.length;

    // Determine status and colors
    String status;
    Color mainColor;
    Color heelColor;
    IconData statusIcon;

    if (avgPressure > 0.7) {
      status = 'High Pressure';
      mainColor = const Color(0xFFFFCDD2); // Light red
      heelColor = const Color(0xFFE53935); // Red
      statusIcon = Icons.error_outline;
    } else if (avgPressure > 0.4) {
      status = 'Moderate';
      mainColor = const Color(0xFFFFF9C4); // Light yellow
      heelColor = const Color(0xFFFFA726); // Orange
      statusIcon = Icons.show_chart;
    } else {
      status = 'Normal';
      mainColor = const Color(0xFFC8E6C9); // Light green
      heelColor = const Color(0xFF4CAF50); // Green
      statusIcon = Icons.check_circle_outline;
    }

    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 12),
        // Simple foot shape
        Container(
          width: 90,
          height: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Main foot body (pill shape)
              Container(
                width: 70,
                height: 140,
                decoration: BoxDecoration(
                  color: mainColor,
                  borderRadius: BorderRadius.circular(35),
                ),
              ),
              // Heel circle at bottom
              Positioned(
                bottom: 10,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: heelColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Status indicator
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(statusIcon, size: 16, color: heelColor),
            const SizedBox(width: 4),
            Text(
              status,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: heelColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Simple color legend for foot map
  Widget _buildSimpleLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendDot(const Color(0xFF4CAF50), 'Low'),
        const SizedBox(width: 20),
        _buildLegendDot(const Color(0xFFFFA726), 'Medium'),
        const SizedBox(width: 20),
        _buildLegendDot(const Color(0xFFE53935), 'High'),
      ],
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Color _getPressureColor(double value) {
    if (value > 0.7) return const Color(0xFFE53935);
    if (value > 0.5) return const Color(0xFFFFA726);
    return const Color(0xFF4CAF50);
  }

  Color _getTempColor(double temp) {
    if (temp > 34.0) return const Color(0xFFE53935);
    if (temp > 33.0) return const Color(0xFFFFA726);
    if (temp < 31.0) return const Color(0xFF42A5F5);
    return const Color(0xFF4CAF50);
  }

  Widget _buildRealTimeMetrics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Real-Time Metrics',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.thermostat_rounded,
                label: 'Temperature',
                value: '${_temperature.toStringAsFixed(1)}°C',
                color: _getTempColor(_temperature),
                gradient: [
                  _getTempColor(_temperature).withOpacity(0.15),
                  _getTempColor(_temperature).withOpacity(0.05),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.compress_rounded,
                label: 'Avg Pressure',
                value: '${_pressure.toStringAsFixed(0)} kPa',
                color: _getPressureColor(_pressure / 100),
                gradient: [
                  _getPressureColor(_pressure / 100).withOpacity(0.15),
                  _getPressureColor(_pressure / 100).withOpacity(0.05),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.directions_walk_rounded,
                label: 'Steps Today',
                value: _formatNumber(_stepsToday),
                color: const Color(0xFF5C6BC0),
                gradient: [
                  const Color(0xFF5C6BC0).withOpacity(0.15),
                  const Color(0xFF5C6BC0).withOpacity(0.05),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.timer_rounded,
                label: 'Wearing Time',
                value: _formatDuration(_wearingDuration),
                color: const Color(0xFF26A69A),
                gradient: [
                  const Color(0xFF26A69A).withOpacity(0.15),
                  const Color(0xFF26A69A).withOpacity(0.05),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required List<Color> gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.white],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              value,
              key: ValueKey(value),
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return number.toString();
  }

  String _formatDuration(Duration duration) {
    int hours = duration.inHours;
    int minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  Widget _buildWeeklyReportButton() {
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
          onTap: () {
            // Navigate to Weekly Report Screen
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WeeklyReportScreen()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.assessment_rounded, color: Colors.white, size: 26),
                SizedBox(width: 12),
                Text(
                  'View Weekly Report',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
