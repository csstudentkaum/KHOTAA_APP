import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../app/app_theme.dart';
import '../../../models/doctor_model.dart';
import 'select_date_time_screen.dart';

/// Doctor detail screen - shows doctor info and book button
class DoctorDetailScreen extends StatefulWidget {
  final DoctorModel doctor;

  const DoctorDetailScreen({super.key, required this.doctor});

  @override
  State<DoctorDetailScreen> createState() => _DoctorDetailScreenState();
}

class _DoctorDetailScreenState extends State<DoctorDetailScreen> {
  Map<String, dynamic>? _workingHours;
  bool _loadingHours = true;
  late DoctorModel _doctor;

  DoctorModel get doctor => _doctor;

  @override
  void initState() {
    super.initState();
    _doctor = widget.doctor;
    _loadWorkingHours();
    _refreshDoctorData();
  }

  /// Re-fetch doctor data from Firestore to get the latest updates
  Future<void> _refreshDoctorData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.doctor.id)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          _doctor = DoctorModel.fromFirestore(doc);
        });
      }
    } catch (e) {
      debugPrint('Error refreshing doctor data: $e');
    }
  }

  Future<void> _loadWorkingHours() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(doctor.id)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data();
        setState(() {
          _workingHours = data?['workingHours'] as Map<String, dynamic>?;
          _loadingHours = false;
        });
      } else {
        if (mounted) setState(() => _loadingHours = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingHours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Teal header with doctor avatar ──
          _buildProfileHeader(context),

          // ── Scrollable content ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                children: [
                  // Stats row
                  _buildStatsRow(),
                  const SizedBox(height: 20),

                  // Working hours
                  _buildWorkingHours(),
                  const SizedBox(height: 28),

                  // Book appointment button
                  _buildBookButton(context),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────── HEADER ─────────────────────────────

  Widget _buildProfileHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF64ADB3), Color(0xFF4D9DA3)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            children: [
              // ── Top bar: back, title, favourite ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const Text(
                    'Doctor Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 8),

              // ── Avatar ──
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.2),
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
                child: Icon(
                  Icons.person,
                  size: 38,
                  color: Colors.white.withOpacity(0.85),
                ),
              ),
              const SizedBox(height: 10),

              // ── Name ──
              Text(
                'Dr. ${doctor.firstName} ${doctor.lastName}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              // ── Hospital pill ──
              if (doctor.hospitalName != null &&
                  doctor.hospitalName!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_hospital_outlined,
                        size: 13,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        doctor.hospitalName!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────── STATS ──────────────────────────────

  Widget _buildStatsRow() {
    final hasRating = doctor.ratingCount > 0;
    return Row(
      children: [
        _buildStatCard('Degree', doctor.degree ?? 'N/A', Icons.school_outlined),
        const SizedBox(width: 10),
        _buildStatCard(
          'Specialty',
          doctor.specialtyLevel ?? 'General',
          Icons.medical_services_outlined,
        ),
        if (hasRating) ...[
          const SizedBox(width: 10),
          _buildStatCard(
            'Rating',
            doctor.rating.toStringAsFixed(1),
            Icons.star_rounded,
            iconColor: Colors.amber,
          ),
        ],
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon, {
    Color? iconColor,
  }) {
    final color = iconColor ?? AppColors.primary;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.12)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: AppColors.textHint, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────── WORKING HOURS ─────────────────────────

  Widget _buildWorkingHours() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.schedule,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Working Hours',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loadingHours)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_workingHours != null)
            ..._buildDynamicHours()
          else ...[
            _buildHoursRow('Sunday', '24 Hours'),
            const SizedBox(height: 8),
            _buildHoursRow('Monday', '24 Hours'),
            const SizedBox(height: 8),
            _buildHoursRow('Tuesday', '24 Hours'),
            const SizedBox(height: 8),
            _buildHoursRow('Wednesday', '24 Hours'),
            const SizedBox(height: 8),
            _buildHoursRow('Thursday', '24 Hours'),
            const SizedBox(height: 8),
            _buildHoursRow('Friday', 'Closed', isClosed: true),
            const SizedBox(height: 8),
            _buildHoursRow('Saturday', 'Closed', isClosed: true),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildDynamicHours() {
    const dayOrder = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final widgets = <Widget>[];
    for (int i = 0; i < dayOrder.length; i++) {
      final day = dayOrder[i];
      final dayData = _workingHours![day] as Map<String, dynamic>?;
      if (i > 0) widgets.add(const SizedBox(height: 10));
      if (dayData != null && dayData['enabled'] == true) {
        widgets.add(
          _buildHoursRow(day, '${dayData['start']} - ${dayData['end']}'),
        );
      } else {
        widgets.add(_buildHoursRow(day, 'Closed', isClosed: true));
      }
    }
    return widgets;
  }

  Widget _buildHoursRow(String day, String hours, {bool isClosed = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            day,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isClosed
                  ? AppColors.error.withOpacity(0.08)
                  : AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              hours,
              style: TextStyle(
                color: isClosed ? AppColors.error : AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── BOOK BUTTON ────────────────────────────

  Widget _buildBookButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SelectDateTimeScreen(doctor: doctor),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_month_outlined, size: 20),
            SizedBox(width: 8),
            Text(
              'Book Appointment',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
