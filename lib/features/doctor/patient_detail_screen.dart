import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../app/app_theme.dart';
import 'image_review_screen.dart';
import 'treatment_plan_screen.dart';
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

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  int _selectedFoot = 0; // 0 = Left, 1 = Right

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F8),
      appBar: AppBar(
        title: const Text('Patient Dashboard'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
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
          final riskLevel = userData['riskLevel'] ?? 'Moderate';

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
              String pressureStatus = 'No data';
              String temperatureStatus = 'No data';
              String lastReadingTime = 'No readings yet';
              List<double> leftPressurePoints = List.filled(6, 0);
              List<double> rightPressurePoints = List.filled(6, 0);

              if (readingSnap.hasData && readingSnap.data!.docs.isNotEmpty) {
                final rData =
                    readingSnap.data!.docs.first.data() as Map<String, dynamic>;
                pressure = (rData['pressure'] ?? 0).toDouble();
                temperature = (rData['temperature'] ?? 0).toDouble();
                pressureStatus = _getPressureStatus(pressure);
                temperatureStatus = _getTemperatureStatus(temperature);

                if (rData['timestamp'] != null) {
                  final ts = (rData['timestamp'] as dynamic).toDate();
                  final diff = DateTime.now().difference(ts);
                  if (diff.inMinutes < 60) {
                    lastReadingTime = '${diff.inMinutes} min ago';
                  } else if (diff.inHours < 24) {
                    lastReadingTime = '${diff.inHours}h ago';
                  } else {
                    lastReadingTime = '${diff.inDays}d ago';
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
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Patient Info Card ──
                    _buildPatientInfoCard(
                      fullName: fullName,
                      initials: initials,
                      age: age,
                      gender: gender,
                      riskLevel: riskLevel,
                      lastReadingTime: lastReadingTime,
                    ),
                    const SizedBox(height: 12),

                    // ── Medical Information Section ──
                    _buildMedicalInfoSection(userData),
                    const SizedBox(height: 12),

                    // ── View Complete Medical Records ──
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
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
                        icon: const Icon(Icons.folder_open_outlined, size: 18),
                        label: const Text('View Complete Medical Records'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Chat & Call Buttons ──
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Chat feature coming soon'),
                                  backgroundColor: AppColors.primary,
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.chat_bubble_outline,
                              size: 18,
                            ),
                            label: const Text('Chat'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Call feature coming soon'),
                                  backgroundColor: AppColors.primary,
                                ),
                              );
                            },
                            icon: const Icon(Icons.phone_outlined, size: 18),
                            label: const Text('Call'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Section Title: Recent Readings ──
                    const Text(
                      'Recent Readings',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Pressure & Temperature Cards ──
                    Row(
                      children: [
                        Expanded(
                          child: _buildReadingCard(
                            title: 'Pressure',
                            value: pressure > 0
                                ? '${pressure.toStringAsFixed(0)} kPa'
                                : '-- kPa',
                            status: pressureStatus,
                            statusColor: _getPressureColor(pressure),
                            icon: Icons.speed_outlined,
                            iconBg: const Color(0xFFEBF5FF),
                            iconColor: const Color(0xFF3B82F6),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildReadingCard(
                            title: 'Temperature',
                            value: temperature > 0
                                ? '${temperature.toStringAsFixed(1)} °C'
                                : '-- °C',
                            status: temperatureStatus,
                            statusColor: _getTemperatureColor(temperature),
                            icon: Icons.thermostat_outlined,
                            iconBg: const Color(0xFFFFF7ED),
                            iconColor: const Color(0xFFF97316),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Foot Pressure Map ──
                    const Text(
                      'Foot Pressure Map',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildFootPressureMap(
                      leftPoints: leftPressurePoints,
                      rightPoints: rightPressurePoints,
                    ),
                    const SizedBox(height: 20),

                    // ── Quick Actions ──
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildQuickActionTile(
                      icon: Icons.image_search_outlined,
                      title: 'Foot Images',
                      subtitle: 'Review uploaded foot images',
                      color: const Color(0xFF22C55E),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ImageReviewScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildQuickActionTile(
                      icon: Icons.medical_information_outlined,
                      title: 'Treatment Plan',
                      subtitle: 'Manage treatment plan',
                      color: const Color(0xFF6366F1),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TreatmentPlanScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildQuickActionTile(
                      icon: Icons.history_outlined,
                      title: 'Appointment History',
                      subtitle: 'View past appointments',
                      color: AppColors.primary,
                      onTap: () {},
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
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
    required String riskLevel,
    required String lastReadingTime,
  }) {
    Color riskColor;
    switch (riskLevel.toLowerCase()) {
      case 'high':
        riskColor = const Color(0xFFEF4444);
        break;
      case 'moderate':
        riskColor = const Color(0xFFF59E0B);
        break;
      case 'low':
        riskColor = const Color(0xFF22C55E);
        break;
      default:
        riskColor = AppColors.textSecondary;
    }

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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: riskColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: riskColor.withAlpha(80)),
                ),
                child: Text(
                  riskLevel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: riskColor,
                  ),
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withAlpha(50)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadingCard({
    required String title,
    required String value,
    required String status,
    required Color statusColor,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFootPressureMap({
    required List<double> leftPoints,
    required List<double> rightPoints,
  }) {
    final points = _selectedFoot == 0 ? leftPoints : rightPoints;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _footToggle('Left Foot', 0),
              const SizedBox(width: 8),
              _footToggle('Right Foot', 1),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 260,
            child: CustomPaint(
              size: const Size(160, 260),
              painter: FootPressurePainter(points: points),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(const Color(0xFF22C55E), 'Normal'),
              const SizedBox(width: 16),
              _legendDot(const Color(0xFFF59E0B), 'Elevated'),
              const SizedBox(width: 16),
              _legendDot(const Color(0xFFEF4444), 'High'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _footToggle(String label, int index) {
    final selected = _selectedFoot == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFoot = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.inputBorder,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildQuickActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.inputBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textHint,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  String _getPressureStatus(double kPa) {
    if (kPa <= 0) return 'No data';
    if (kPa < 60) return 'Normal';
    if (kPa < 80) return 'Above normal';
    return 'High risk';
  }

  Color _getPressureColor(double kPa) {
    if (kPa <= 0) return AppColors.textHint;
    if (kPa < 60) return const Color(0xFF22C55E);
    if (kPa < 80) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String _getTemperatureStatus(double c) {
    if (c <= 0) return 'No data';
    if (c < 33) return 'Normal';
    if (c < 35) return 'Elevated';
    return 'High';
  }

  Color _getTemperatureColor(double c) {
    if (c <= 0) return AppColors.textHint;
    if (c < 33) return const Color(0xFF22C55E);
    if (c < 35) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
}

// ── Foot Pressure Custom Painter ──
class FootPressurePainter extends CustomPainter {
  final List<double> points;

  FootPressurePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;

    final outlinePaint = Paint()
      ..color = const Color(0xFFD1D5DB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final footPath = Path();
    footPath.moveTo(cx - 25, 20);
    footPath.quadraticBezierTo(cx - 35, 0, cx - 15, 0);
    footPath.quadraticBezierTo(cx, 5, cx + 15, 0);
    footPath.quadraticBezierTo(cx + 35, 0, cx + 25, 20);
    footPath.quadraticBezierTo(cx + 40, 50, cx + 38, 80);
    footPath.quadraticBezierTo(cx + 35, 120, cx + 20, 160);
    footPath.quadraticBezierTo(cx + 15, 200, cx + 25, 230);
    footPath.quadraticBezierTo(cx + 28, 250, cx, 255);
    footPath.quadraticBezierTo(cx - 28, 250, cx - 25, 230);
    footPath.quadraticBezierTo(cx - 15, 200, cx - 20, 160);
    footPath.quadraticBezierTo(cx - 35, 120, cx - 38, 80);
    footPath.quadraticBezierTo(cx - 40, 50, cx - 25, 20);
    footPath.close();

    final footFill = Paint()
      ..color = const Color(0xFFF3F4F6)
      ..style = PaintingStyle.fill;
    canvas.drawPath(footPath, footFill);
    canvas.drawPath(footPath, outlinePaint);

    final zones = [
      Offset(cx, 15),
      Offset(cx - 18, 65),
      Offset(cx + 18, 65),
      Offset(cx, 140),
      Offset(cx - 12, 230),
      Offset(cx + 12, 230),
    ];

    for (int i = 0; i < zones.length && i < points.length; i++) {
      final p = points[i];
      Color color;
      if (p <= 0) {
        color = const Color(0xFFD1D5DB);
      } else if (p < 60) {
        color = const Color(0xFF22C55E);
      } else if (p < 80) {
        color = const Color(0xFFF59E0B);
      } else {
        color = const Color(0xFFEF4444);
      }

      final zonePaint = Paint()
        ..color = color.withAlpha(150)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(zones[i], 14, zonePaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: p > 0 ? p.toStringAsFixed(0) : '--',
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        zones[i] - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant FootPressurePainter oldDelegate) =>
      oldDelegate.points != points;
}
