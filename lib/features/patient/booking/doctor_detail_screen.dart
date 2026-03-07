import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  bool _isFavourite = false;
  Map<String, dynamic>? _workingHours;
  bool _loadingHours = true;
  late DoctorModel _doctor;

  DoctorModel get doctor => _doctor;

  @override
  void initState() {
    super.initState();
    _doctor = widget.doctor;
    _loadFavouriteStatus();
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

  Future<void> _loadFavouriteStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && mounted) {
        final favs = List<String>.from(doc.data()?['favoriteDoctors'] ?? []);
        setState(() => _isFavourite = favs.contains(doctor.id));
      }
    } catch (_) {}
  }

  Future<void> _toggleFavourite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isFavourite = !_isFavourite);

    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final doc = await ref.get();
      final favs = List<String>.from(doc.data()?['favoriteDoctors'] ?? []);

      if (_isFavourite) {
        if (!favs.contains(doctor.id)) favs.add(doctor.id);
      } else {
        favs.remove(doctor.id);
      }

      await ref.update({'favoriteDoctors': favs});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isFavourite ? 'Added to favourites' : 'Removed from favourites',
            ),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      // Revert on error
      setState(() => _isFavourite = !_isFavourite);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Doctor Details',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _toggleFavourite,
            icon: Icon(
              _isFavourite ? Icons.favorite : Icons.favorite_border,
              color: _isFavourite ? AppColors.primary : AppColors.textHint,
              size: 26,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Doctor image and basic info
              _buildDoctorHeader(),
              const SizedBox(height: 24),

              // Stats row
              _buildStatsRow(),
              const SizedBox(height: 24),

              // About section
              _buildAboutSection(),
              const SizedBox(height: 24),

              // Working hours
              _buildWorkingHours(),
              const SizedBox(height: 32),

              // Book appointment button
              _buildBookButton(context),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDoctorHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Doctor image
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.background,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 3),
            ),
            child: Icon(
              Icons.person,
              size: 60,
              color: AppColors.primary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),

          // Doctor name
          Text(
            'Dr. ${doctor.firstName} ${doctor.lastName}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          // Specialty
          Text(
            doctor.specialtyLevel ?? 'General Physician',
            style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [SizedBox(width: 4)],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatCard(
          'Experience',
          '10+ yrs',
          Icons.workspace_premium_outlined,
        ),
        const SizedBox(width: 16),
        _buildStatCard('Rating', '5.0', Icons.star_outline),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: AppColors.textHint, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Dr. ${doctor.firstName} ${doctor.lastName} is a highly qualified medical professional with extensive experience in patient care. '
            'Specializing in ${doctor.specialtyLevel ?? "general medicine"}, they are committed to providing comprehensive and compassionate healthcare.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
          if (doctor.degree != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.school_outlined, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  doctor.degree!,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkingHours() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Working Hours',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
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
            _buildHoursRow('Monday - Friday', '09:00 AM - 05:00 PM'),
            const SizedBox(height: 8),
            _buildHoursRow('Saturday', '09:00 AM - 01:00 PM'),
            const SizedBox(height: 8),
            _buildHoursRow('Sunday', 'Closed', isClosed: true),
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
      if (i > 0) widgets.add(const SizedBox(height: 8));
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(day, style: TextStyle(color: AppColors.textSecondary)),
        Text(
          hours,
          style: TextStyle(
            color: isClosed ? AppColors.error : AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

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
        child: const Text(
          'Book Appointment',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
