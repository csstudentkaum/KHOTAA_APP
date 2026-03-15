import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../app/app_theme.dart';
import '../../models/doctor_model.dart';
import 'booking/doctor_detail_screen.dart';

/// Shows the patient's favourite (liked) doctors
class FavouriteDoctorsScreen extends StatefulWidget {
  const FavouriteDoctorsScreen({super.key});

  @override
  State<FavouriteDoctorsScreen> createState() => _FavouriteDoctorsScreenState();
}

class _FavouriteDoctorsScreenState extends State<FavouriteDoctorsScreen> {
  List<DoctorModel> _favouriteDoctors = [];
  Set<String> _favouriteIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavourites();
  }

  Future<void> _loadFavourites() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1. Get the patient's favoriteDoctors list
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists || !mounted) return;

      final ids = List<String>.from(userDoc.data()?['favoriteDoctors'] ?? []);
      _favouriteIds = ids.toSet();

      if (ids.isEmpty) {
        setState(() {
          _favouriteDoctors = [];
          _isLoading = false;
        });
        return;
      }

      // 2. Fetch each doctor doc
      final doctors = <DoctorModel>[];
      for (final id in ids) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(id)
            .get();
        if (doc.exists) {
          doctors.add(DoctorModel.fromFirestore(doc));
        }
      }

      if (mounted) {
        setState(() {
          _favouriteDoctors = doctors;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading favourites: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeFavourite(String doctorId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _favouriteIds.remove(doctorId);
      _favouriteDoctors.removeWhere((d) => d.id == doctorId);
    });

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'favoriteDoctors': _favouriteIds.toList()},
      );
    } catch (e) {
      debugPrint('Error removing favourite: $e');
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
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Favourite Doctors',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favouriteDoctors.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadFavourites,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _favouriteDoctors.length,
                itemBuilder: (context, index) {
                  return _buildDoctorCard(_favouriteDoctors[index]);
                },
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_outline, size: 80, color: AppColors.textHint),
          const SizedBox(height: 16),
          const Text(
            'No favourite doctors yet',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the Like button on any doctor\nto add them here',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textHint, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorCard(DoctorModel doctor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  doctor.firstName.isNotEmpty
                      ? doctor.firstName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dr. ${doctor.firstName} ${doctor.lastName}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    doctor.specialtyLevel ?? 'General Physician',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  if (doctor.hospitalName != null &&
                      doctor.hospitalName!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.local_hospital_outlined,
                          size: 14,
                          color: AppColors.textHint,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            doctor.hospitalName!,
                            style: const TextStyle(
                              color: AppColors.textHint,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Actions column
            Column(
              children: [
                // Unlike button
                GestureDetector(
                  onTap: () => _removeFavourite(doctor.id),
                  child: const Icon(
                    Icons.favorite,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 12),
                // View button
                GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DoctorDetailScreen(doctor: doctor),
                      ),
                    );
                    // Refresh list when returning (user may have unliked)
                    _loadFavourites();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'View',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
