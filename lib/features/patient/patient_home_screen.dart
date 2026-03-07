import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../app/app_theme.dart';
import '../../models/consultation.dart';
import '../../services/consultation_service.dart';
import 'booking/my_bookings_screen.dart';

/// Patient Home Screen - Dashboard for patients
class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  String _firstName = '';
  final ConsultationService _consultationService = ConsultationService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          _firstName = doc.data()?['firstName'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final greeting = _firstName.isNotEmpty
        ? 'Hello, $_firstName'
        : 'Hello there';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              // Header row
              _buildHeader(greeting),
              const SizedBox(height: 4),
              const Text(
                'How are you feeling today?',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                height: 350,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 24),

              // Upcoming Appointments
              _buildUpcomingAppointments(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String greeting) {
    return Row(
      children: [
        Expanded(
          child: Text(
            greeting,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingAppointments() {
    final user = FirebaseAuth.instance.currentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Upcoming Appointments',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
                );
              },
              child: const Text('See All'),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (user == null)
          _buildEmptyAppointmentCard()
        else
          StreamBuilder<List<Consultation>>(
            stream: _consultationService.streamPatientConsultations(user.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final upcomingBookings = (snapshot.data ?? [])
                  .where((c) => c.isUpcoming)
                  .toList();

              // Sort by date + time slot (soonest first)
              upcomingBookings.sort((a, b) {
                final dateA = a.consultationDate ?? DateTime(2099);
                final dateB = b.consultationDate ?? DateTime(2099);
                final dateCmp = dateA.compareTo(dateB);
                if (dateCmp != 0) return dateCmp;
                final timeA = _parseTimeSlot(a.timeSlot ?? '');
                final timeB = _parseTimeSlot(b.timeSlot ?? '');
                final minutesA = timeA != null
                    ? timeA.hour * 60 + timeA.minute
                    : 9999;
                final minutesB = timeB != null
                    ? timeB.hour * 60 + timeB.minute
                    : 9999;
                return minutesA.compareTo(minutesB);
              });

              final displayBookings = upcomingBookings.take(2).toList();

              if (displayBookings.isEmpty) {
                return _buildEmptyAppointmentCard();
              }

              return Column(
                children: displayBookings
                    .map((booking) => _buildAppointmentCard(booking))
                    .toList(),
              );
            },
          ),
      ],
    );
  }

  Widget _buildEmptyAppointmentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 40,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 12),
          const Text(
            'No upcoming appointments',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Book an appointment with a doctor',
            style: TextStyle(fontSize: 13, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(Consultation c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${c.consultationDate?.day ?? ''}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    if (c.consultationDate != null)
                      Text(
                        _getMonthAbbr(c.consultationDate!.month),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.doctorName ?? 'Doctor',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (c.timeSlot != null)
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: AppColors.textHint,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            c.timeSlot!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isChatCallAvailable(c)
                  ? () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Consultation feature coming soon'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    }
                  : null,
              icon: Icon(
                Icons.video_call_outlined,
                size: 20,
                color: _isChatCallAvailable(c)
                    ? Colors.white
                    : AppColors.textHint,
              ),
              label: Text(
                _isChatCallAvailable(c)
                    ? 'Start Consultation'
                    : 'Available 30 min before appointment',
                style: TextStyle(
                  color: _isChatCallAvailable(c)
                      ? Colors.white
                      : AppColors.textHint,
                  fontWeight: FontWeight.w600,
                  fontSize: _isChatCallAvailable(c) ? 14 : 12,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isChatCallAvailable(c)
                    ? AppColors.primary
                    : Colors.grey.shade200,
                disabledBackgroundColor: Colors.grey.shade200,
                elevation: _isChatCallAvailable(c) ? 2 : 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthAbbr(int month) {
    const months = [
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
    return months[month - 1];
  }

  /// Returns true if the consultation starts within 30 minutes from now
  /// or has already started.
  bool _isChatCallAvailable(Consultation booking) {
    if (booking.consultationDate == null || booking.timeSlot == null) {
      return false;
    }
    final slotTime = _parseTimeSlot(booking.timeSlot!);
    if (slotTime == null) return false;

    final consultDate = booking.consultationDate!;
    final appointmentDateTime = DateTime(
      consultDate.year,
      consultDate.month,
      consultDate.day,
      slotTime.hour,
      slotTime.minute,
    );

    final now = DateTime.now();
    final diff = appointmentDateTime.difference(now).inMinutes;
    return diff <= 30;
  }

  /// Parses a time slot string like "10:00 AM" into a TimeOfDay.
  TimeOfDay? _parseTimeSlot(String slot) {
    try {
      final parts = slot.trim().split(' ');
      if (parts.length != 2) return null;
      final timeParts = parts[0].split(':');
      if (timeParts.length != 2) return null;

      int hour = int.parse(timeParts[0]);
      final int minute = int.parse(timeParts[1]);
      final period = parts[1].toUpperCase();

      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;

      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return null;
    }
  }
}
