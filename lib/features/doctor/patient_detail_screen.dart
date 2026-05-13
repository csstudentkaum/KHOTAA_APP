import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../app/app_theme.dart';
import '../patient/weekly_report_screen.dart';
import 'patient_medical_records_screen.dart';

class PatientDetailScreen extends StatefulWidget {
  final String patientId;
  final String patientName;

  const PatientDetailScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen>
    with TickerProviderStateMixin {
  bool _hasRecentData = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Patient Dashboard',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.patientId)
            .snapshots(),
        builder: (context, userSnap) {
          if (userSnap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final userData = userSnap.data?.data() as Map<String, dynamic>? ?? {};
          final firstName = userData['firstName'] ?? '';
          final lastName = userData['lastName'] ?? '';
          final fullName = '$firstName $lastName'.trim();
          final initials =
              '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'
                  .toUpperCase();
          final age = userData['age'] ?? '--';
          final gender = userData['gender'] ?? 'N/A';
          // ── Insole monitoring status (written by patient dashboard) ──
          final insoleStatus =
              userData['insoleStatus'] as Map<String, dynamic>? ?? {};
          final bool insoleConnected = insoleStatus['connected'] == true;
          final bool insoleMonitoring = insoleStatus['monitoring'] == true;
          // Check if the last heartbeat was recent (within 2 minutes)
          DateTime? insoleLastActive;
          if (insoleStatus['lastActive'] != null) {
            insoleLastActive = (insoleStatus['lastActive'] as Timestamp)
                .toDate();
          }
          final bool isRecentHeartbeat =
              insoleLastActive != null &&
              DateTime.now().difference(insoleLastActive).inMinutes < 2;
          final bool isPatientMonitoringActive =
              insoleMonitoring && isRecentHeartbeat;

          // Live values from patient dashboard heartbeat
          final double liveTemperature = (insoleStatus['temperature'] ?? 0)
              .toDouble();
          final double livePressure = (insoleStatus['pressure'] ?? 0)
              .toDouble();
          final int liveSteps = (insoleStatus['stepsToday'] ?? 0) is int
              ? (insoleStatus['stepsToday'] ?? 0) as int
              : (insoleStatus['stepsToday'] ?? 0).toInt();
          final int liveWearingMinutes =
              (insoleStatus['wearingMinutes'] ?? 0) is int
              ? (insoleStatus['wearingMinutes'] ?? 0) as int
              : (insoleStatus['wearingMinutes'] ?? 0).toInt();

          // Live foot pressure data from patient dashboard
          List<double> liveLeftFootPressure = [];
          List<double> liveRightFootPressure = [];
          if (insoleStatus['leftFootPressure'] != null) {
            liveLeftFootPressure = List<double>.from(
              (insoleStatus['leftFootPressure'] as List).map(
                (e) => (e as num).toDouble(),
              ),
            );
          }
          if (insoleStatus['rightFootPressure'] != null) {
            liveRightFootPressure = List<double>.from(
              (insoleStatus['rightFootPressure'] as List).map(
                (e) => (e as num).toDouble(),
              ),
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('dfu_readings')
                .where('patientId', isEqualTo: widget.patientId)
                .orderBy('timestamp', descending: true)
                .limit(1)
                .snapshots(),
            builder: (context, readingSnap) {
              // Defaults
              double pressure = 0;
              double temperature = 0;
              int stepsToday = 0;
              int wearingMinutes = 0;
              String lastReadingTime = 'No readings yet';
              List<double> leftPressurePoints = List.filled(6, 0);
              List<double> rightPressurePoints = List.filled(6, 0);

              if (readingSnap.hasData && readingSnap.data!.docs.isNotEmpty) {
                final rData =
                    readingSnap.data!.docs.first.data() as Map<String, dynamic>;
                pressure = (rData['pressure'] ?? 0).toDouble();
                temperature = (rData['temperature'] ?? 0).toDouble();

                if (rData['timestamp'] != null) {
                  final ts = (rData['timestamp'] as dynamic).toDate();
                  final diff = DateTime.now().difference(ts);
                  if (diff.inMinutes < 60) {
                    lastReadingTime = '${diff.inMinutes} min ago';
                    _hasRecentData = true;
                  } else if (diff.inHours < 24) {
                    lastReadingTime = '${diff.inHours}h ago';
                    _hasRecentData = diff.inHours < 2;
                  } else {
                    lastReadingTime = '${diff.inDays}d ago';
                    _hasRecentData = false;
                  }
                }

                if (rData['leftPressurePoints'] != null) {
                  leftPressurePoints = List<double>.from(
                    (rData['leftPressurePoints'] as List).map(
                      (e) => (e as num).toDouble(),
                    ),
                  );
                }
                if (rData['rightPressurePoints'] != null) {
                  rightPressurePoints = List<double>.from(
                    (rData['rightPressurePoints'] as List).map(
                      (e) => (e as num).toDouble(),
                    ),
                  );
                }

                stepsToday = (rData['stepsToday'] ?? 0) is int
                    ? (rData['stepsToday'] ?? 0) as int
                    : (rData['stepsToday'] ?? 0).toInt();
                wearingMinutes = (rData['wearingMinutes'] ?? 0) is int
                    ? (rData['wearingMinutes'] ?? 0) as int
                    : (rData['wearingMinutes'] ?? 0).toInt();
              }

              // Use live insole data if patient is actively monitoring,
              // otherwise fall back to last Firestore reading.
              final double displayTemperature =
                  isPatientMonitoringActive && liveTemperature > 0
                  ? liveTemperature
                  : temperature;
              final double displayPressure =
                  isPatientMonitoringActive && livePressure > 0
                  ? livePressure
                  : pressure;
              final int displaySteps =
                  isPatientMonitoringActive && liveSteps > 0
                  ? liveSteps
                  : stepsToday;
              final int displayWearing =
                  isPatientMonitoringActive && liveWearingMinutes > 0
                  ? liveWearingMinutes
                  : wearingMinutes;

              // Use live foot pressure data when monitoring is active
              final List<double> displayLeftPoints =
                  isPatientMonitoringActive && liveLeftFootPressure.isNotEmpty
                  ? liveLeftFootPressure
                  : leftPressurePoints;
              final List<double> displayRightPoints =
                  isPatientMonitoringActive && liveRightFootPressure.isNotEmpty
                  ? liveRightFootPressure
                  : rightPressurePoints;

              // Override last reading time if live monitoring is active
              final String displayLastReading = isPatientMonitoringActive
                  ? 'Live now'
                  : lastReadingTime;

              return Column(
                children: [
                  // ── Patient Info Card (always visible above tabs) ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: _buildPatientInfoCard(
                      fullName: fullName,
                      initials: initials,
                      age: age,
                      gender: gender,
                      lastReadingTime: displayLastReading,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Tab Bar ──
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: Colors.white,
                      unselectedLabelColor: AppColors.textSecondary,
                      labelStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(text: 'Monitoring'),
                        Tab(text: 'Patient Info'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Tab Content ──
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // ═══ TAB 1: Monitoring ═══
                        SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Alert Banner
                              _buildAlertBanner(
                                pressure: displayPressure,
                                temperature: displayTemperature,
                              ),

                              // Live Status
                              _buildLiveStatusSection(
                                isPatientMonitoringActive:
                                    isPatientMonitoringActive,
                                insoleConnected: insoleConnected,
                              ),
                              const SizedBox(height: 24),

                              // Real-Time Metrics
                              _buildRealTimeMetrics(
                                pressure: displayPressure,
                                temperature: displayTemperature,
                                stepsToday: displaySteps,
                                wearingMinutes: displayWearing,
                              ),
                              const SizedBox(height: 24),

                              // Foot Visualization
                              _buildFootVisualization(
                                leftPoints: displayLeftPoints,
                                rightPoints: displayRightPoints,
                              ),
                              const SizedBox(height: 24),

                              // Weekly Report
                              _buildWeeklyReportButton(),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),

                        // ═══ TAB 2: Patient Info ═══
                        SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Medical Information
                              _buildMedicalInfoSection(userData),
                              const SizedBox(height: 16),

                              // Medical Records Button
                              _buildMedicalRecordsButton(fullName),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ── Patient Info Card ──
  Widget _buildPatientInfoCard({
    required String fullName,
    required String initials,
    required dynamic age,
    required String gender,
    required String lastReadingTime,
  }) {

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary.withAlpha(30),
                child: Text(
                  initials.isNotEmpty ? initials : '?',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName.isNotEmpty ? fullName : 'Unknown',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Age: $age  •  $gender',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          _infoRow(Icons.access_time_outlined, 'Last Reading', lastReadingTime),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textHint),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  Weekly Report Button (same as patient dashboard_screen)
  // ══════════════════════════════════════════════════════════════════
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
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WeeklyReportScreen(patientId: widget.patientId),
              ),
            );
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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

  // ── Medical Information Section ──
  Widget _buildMedicalInfoSection(Map<String, dynamic> userData) {
    final diabetesType = (userData['diabetesType'] ?? '').toString().trim();
    final diagnosisYear = (userData['diagnosisYear'] ?? '').toString().trim();
    final insulinUsage = (userData['insulinUsage'] ?? '').toString().trim();
    final hba1cLevel = (userData['hba1cLevel'] ?? '').toString().trim();
    final additionalNotes = (userData['additionalMedicalNotes'] ?? '')
        .toString()
        .trim();

    final conditions = _toStringList(userData['medicalHistory']);
    final allergies = _toStringList(userData['allergies']);
    final medications = _toStringList(userData['currentMedications']);

    final hasDiabetesInfo =
        diabetesType.isNotEmpty ||
        diagnosisYear.isNotEmpty ||
        insulinUsage.isNotEmpty ||
        hba1cLevel.isNotEmpty;
    final hasAnyData =
        hasDiabetesInfo ||
        conditions.isNotEmpty ||
        allergies.isNotEmpty ||
        medications.isNotEmpty ||
        additionalNotes.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.medical_information_outlined,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Text(
                'Medical Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          if (!hasAnyData)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: const Text(
                'No medical information provided by the patient yet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textHint,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else ...[
            // Diabetes details
            if (hasDiabetesInfo) ...[
              _medicalDetailLabel(Icons.bloodtype_outlined, 'Diabetes History'),
              if (diabetesType.isNotEmpty)
                _medicalDetailRow('Type', diabetesType),
              if (diagnosisYear.isNotEmpty)
                _medicalDetailRow('Diagnosed', diagnosisYear),
              if (insulinUsage.isNotEmpty)
                _medicalDetailRow('Insulin', insulinUsage),
              if (hba1cLevel.isNotEmpty) _medicalDetailRow('HbA1c', hba1cLevel),
              const SizedBox(height: 12),
            ],

            // Medical conditions as chips
            if (conditions.isNotEmpty) ...[
              _medicalDetailLabel(Icons.history_outlined, 'Medical Conditions'),
              const SizedBox(height: 6),
              _buildReadOnlyChips(conditions, const Color(0xFF6366F1)),
              const SizedBox(height: 12),
            ],

            // Allergies as chips (red-tinted)
            if (allergies.isNotEmpty) ...[
              _medicalDetailLabel(Icons.warning_amber_outlined, 'Allergies'),
              const SizedBox(height: 6),
              _buildReadOnlyChips(allergies, const Color(0xFFEF4444)),
              const SizedBox(height: 12),
            ],

            // Medications as chips
            if (medications.isNotEmpty) ...[
              _medicalDetailLabel(
                Icons.medication_outlined,
                'Current Medications',
              ),
              const SizedBox(height: 6),
              _buildReadOnlyChips(medications, AppColors.primary),
              const SizedBox(height: 12),
            ],

            // Additional notes
            if (additionalNotes.isNotEmpty) ...[
              _medicalDetailLabel(Icons.note_alt_outlined, 'Additional Notes'),
              Padding(
                padding: const EdgeInsets.only(left: 22, top: 4),
                child: Text(
                  additionalNotes,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ],
        ],
      ),
    );
  }

  List<String> _toStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    if (value is String && value.isNotEmpty) {
      return value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }

  Widget _medicalDetailLabel(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary.withAlpha(180)),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _medicalDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(left: 22, bottom: 3),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyChips(List<String> items, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 22),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: items
            .map(
              (item) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: color.withAlpha(15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withAlpha(50)),
                ),
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  Alert Banner — matches patient dashboard_screen
  // ══════════════════════════════════════════════════════════════════
  Widget _buildAlertBanner({
    required double pressure,
    required double temperature,
  }) {
    final bool abnormalPressure = pressure > 80;
    final bool abnormalTemp =
        temperature > 35 || (temperature > 0 && temperature < 30.5);
    final bool hasAbnormal = abnormalPressure || abnormalTemp;

    if (!hasAbnormal) return const SizedBox.shrink();

    String message;
    if (abnormalPressure && abnormalTemp) {
      message =
          'Abnormal pressure and temperature detected. Please check the patient\'s foot.';
    } else if (abnormalPressure) {
      message =
          'Abnormal pressure detected. Please check the patient\'s foot or reduce pressure.';
    } else {
      message =
          'Abnormal temperature detected. Please check the patient\'s foot.';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
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
                  message,
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

  // ══════════════════════════════════════════════════════════════════
  //  Live Status Section (dashboard_screen style)
  // ══════════════════════════════════════════════════════════════════
  Widget _buildLiveStatusSection({
    required bool isPatientMonitoringActive,
    required bool insoleConnected,
  }) {
    // Use real-time insole status from patient's Firestore heartbeat.
    // Fall back to _hasRecentData only when patient hasn't written status yet.
    final bool isConnected = isPatientMonitoringActive || _hasRecentData;
    final bool isMonitoring = isPatientMonitoringActive;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isPatientMonitoringActive) {
      statusColor = const Color(0xFF4CAF50);
      statusText = 'Monitoring Active';
      statusIcon = Icons.monitor_heart;
    } else {
      statusColor = Colors.grey;
      statusText = 'No Live Data';
      statusIcon = Icons.hourglass_empty_outlined;
    }

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
              Expanded(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            (isConnected
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFFE53935))
                                .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        isConnected
                            ? Icons.bluetooth_connected
                            : Icons.bluetooth_disabled,
                        color: isConnected
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFE53935),
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Insole',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isConnected ? 'Connected' : 'Offline',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isConnected
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFE53935),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 50,
                width: 1,
                color: Colors.grey.withOpacity(0.2),
              ),
              Expanded(
                child: Column(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: isMonitoring
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF4CAF50)
                                          .withOpacity(
                                            0.3 * _pulseAnimation.value,
                                          ),
                                      blurRadius: 15 * _pulseAnimation.value,
                                      spreadRadius: 2 * _pulseAnimation.value,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            Icons.monitor_heart,
                            color: isMonitoring
                                ? const Color(0xFF4CAF50)
                                : Colors.grey,
                            size: 28,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Monitoring',
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
                        if (isMonitoring) ...[
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
                                      color: const Color(0xFF4CAF50)
                                          .withOpacity(
                                            0.5 * _pulseAnimation.value,
                                          ),
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
                          isMonitoring ? 'Active' : 'Inactive',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isMonitoring
                                ? const Color(0xFF4CAF50)
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Status Indicator
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  statusColor.withOpacity(0.1),
                  statusColor.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: statusColor.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 28),
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
                        statusText,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  Real-Time Metrics (dashboard_screen style — 4 cards)
  // ══════════════════════════════════════════════════════════════════
  Widget _buildRealTimeMetrics({
    required double pressure,
    required double temperature,
    required int stepsToday,
    required int wearingMinutes,
  }) {
    final pColor = _getPressureColor(pressure);
    final tColor = _getTemperatureColor(temperature);

    // Format steps
    String stepsValue;
    if (stepsToday > 0) {
      if (stepsToday >= 1000) {
        stepsValue = '${(stepsToday / 1000).toStringAsFixed(1)}k';
      } else {
        stepsValue = stepsToday.toString();
      }
    } else {
      stepsValue = '--';
    }

    // Format wearing time
    String wearingValue;
    if (wearingMinutes > 0) {
      final hours = wearingMinutes ~/ 60;
      final mins = wearingMinutes % 60;
      if (hours > 0) {
        wearingValue = '${hours}h ${mins}m';
      } else {
        wearingValue = '${mins}m';
      }
    } else {
      wearingValue = '--';
    }

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
                label: 'Avg Temperature',
                value: temperature > 0
                    ? '${temperature.toStringAsFixed(1)}°C'
                    : '-- °C',
                color: tColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.compress_rounded,
                label: 'Avg Pressure',
                value: pressure > 0
                    ? '${pressure.toStringAsFixed(0)} kPa'
                    : '-- kPa',
                color: pColor,
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
                value: stepsValue,
                color: const Color(0xFF5C6BC0),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.timer_rounded,
                label: 'Wearing Time',
                value: wearingValue,
                color: const Color(0xFF26A69A),
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
              gradient: LinearGradient(
                colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
              ),
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

  // ══════════════════════════════════════════════════════════════════
  //  Foot Visualization (same design as patient dashboard_screen)
  // ══════════════════════════════════════════════════════════════════
  Widget _buildFootVisualization({
    required List<double> leftPoints,
    required List<double> rightPoints,
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
          // Both feet side by side
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSimpleFoot(label: 'Left Foot', pressureValues: leftPoints),
              _buildSimpleFoot(
                label: 'Right Foot',
                pressureValues: rightPoints,
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(const Color(0xFF4CAF50), 'Normal'),
              const SizedBox(width: 20),
              _legendDot(const Color(0xFFFFA726), 'Medium'),
              const SizedBox(width: 20),
              _legendDot(const Color(0xFFE53935), 'High'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleFoot({
    required String label,
    required List<double> pressureValues,
  }) {
    // Calculate average pressure to determine status
    final nonZero = pressureValues.where((v) => v > 0).toList();
    final avgPressure = nonZero.isNotEmpty
        ? nonZero.reduce((a, b) => a + b) / nonZero.length
        : 0.0;

    // Detect scale: if max value <= 1.0 it's 0–1 normalized (from patient dashboard),
    // otherwise it's in kPa (from dfu_readings).
    final maxVal = pressureValues.isNotEmpty
        ? pressureValues.reduce((a, b) => a > b ? a : b)
        : 0.0;
    final bool isNormalized = maxVal > 0 && maxVal <= 1.0;

    // Determine status & colors using the appropriate thresholds
    String status;
    Color mainColor;
    Color heelColor;
    IconData statusIcon;

    if (avgPressure <= 0) {
      status = 'No Data';
      mainColor = const Color(0xFFF3F4F6);
      heelColor = const Color(0xFF9CA3AF);
      statusIcon = Icons.remove_circle_outline;
    } else if (isNormalized ? avgPressure > 0.7 : avgPressure > 80) {
      status = 'High Pressure';
      mainColor = const Color(0xFFFFCDD2);
      heelColor = const Color(0xFFE53935);
      statusIcon = Icons.error_outline;
    } else if (isNormalized ? avgPressure > 0.4 : avgPressure > 60) {
      status = 'Moderate';
      mainColor = const Color(0xFFFFF9C4);
      heelColor = const Color(0xFFFFA726);
      statusIcon = Icons.show_chart;
    } else {
      status = 'Normal';
      mainColor = const Color(0xFFC8E6C9);
      heelColor = const Color(0xFF4CAF50);
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
        // Simple foot shape (pill with heel circle)
        SizedBox(
          width: 90,
          height: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Main foot body
              Container(
                width: 70,
                height: 140,
                decoration: BoxDecoration(
                  color: mainColor,
                  borderRadius: BorderRadius.circular(35),
                ),
              ),
              // Heel circle
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
        // Status label
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

  Widget _legendDot(Color color, String label) {
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

  // ══════════════════════════════════════════════════════════════════
  //  Medical Records Button (dashboard_screen weekly report style)
  // ══════════════════════════════════════════════════════════════════
  Widget _buildMedicalRecordsButton(String fullName) {
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
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PatientMedicalRecordsScreen(
                  patientId: widget.patientId,
                  patientName: fullName,
                ),
              ),
            );
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open_outlined, color: Colors.white, size: 24),
                SizedBox(width: 12),
                Text(
                  'View Medical Records',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Status helpers ──

  Color _getPressureColor(double kPa) {
    if (kPa <= 0) return AppColors.textHint;
    if (kPa < 60) return const Color(0xFF22C55E);
    if (kPa < 80) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Color _getTemperatureColor(double c) {
    if (c <= 0) return AppColors.textHint;
    if (c < 33) return const Color(0xFF22C55E);
    if (c < 35) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
}
