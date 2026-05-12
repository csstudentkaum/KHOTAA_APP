import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../app/app_theme.dart';
import '../../services/consultation_service.dart';
import '../../services/notification_service.dart';
import '../sensor_alerts/doctor_risk_monitor.dart';
import '../../shared/in_app_notification_popup.dart';
import 'doctor_notifications_screen.dart';
import '../../models/consultation.dart';
import 'patient_detail_screen.dart';
import 'treatment_plan_screen.dart';
import 'consultation_requests_screen.dart';
import 'doctor_edit_profile_screen.dart';
import 'doctor_help_support_screen.dart';
import 'working_hours_screen.dart';
import '../shared/consultation_session_screen.dart';

class DHomeScreen extends StatefulWidget {
  const DHomeScreen({super.key});

  @override
  State<DHomeScreen> createState() => _DHomeScreenState();
}

class _DHomeScreenState extends State<DHomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  String _firstName = '';
  String _lastName = '';
  int _selectedAppointmentTab = 0;
  late TabController _appointmentTabController;
  final DoctorRiskMonitor _riskMonitor = DoctorRiskMonitor();
  final Set<String> _autoCompletedFollowUps = {};
  final TextEditingController _patientSearchController = TextEditingController();
  String _patientSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _appointmentTabController = TabController(length: 3, vsync: this);
    _appointmentTabController.addListener(() {
      if (!_appointmentTabController.indexIsChanging) {
        setState(() {
          _selectedAppointmentTab = _appointmentTabController.index;
        });
      }
    });
    _loadUserData();
    _startRiskMonitor();
  }

  void _startRiskMonitor() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _riskMonitor.startMonitoring(user.uid);
    }
  }

  @override
  void dispose() {
    _appointmentTabController.dispose();
    _patientSearchController.dispose();
    _riskMonitor.stopMonitoring();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('❌ _loadUserData: No user logged in');
      return;
    }

    debugPrint('🔍 _loadUserData: uid=${user.uid}, phone=${user.phoneNumber}');

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      debugPrint('🔍 _loadUserData: doc.exists=${doc.exists}');
      if (doc.exists) {
        debugPrint('🔍 _loadUserData: data=${doc.data()}');
      }

      if (doc.exists && mounted) {
        setState(() {
          _firstName = doc.data()?['firstName'] ?? '';
          _lastName = doc.data()?['lastName'] ?? '';
        });
        debugPrint(
          ' _loadUserData: firstName=$_firstName, lastName=$_lastName',
        );
      } else if (!doc.exists && mounted) {
        // Fallback: try to find user by phone number
        debugPrint(' Doc not found by UID, trying phone lookup...');
        final phoneQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('phone', isEqualTo: user.phoneNumber)
            .limit(1)
            .get();

        if (phoneQuery.docs.isNotEmpty && mounted) {
          final data = phoneQuery.docs.first.data();
          debugPrint(' Found by phone: data=$data');
          setState(() {
            _firstName = data['firstName'] ?? '';
            _lastName = data['lastName'] ?? '';
          });
          debugPrint(
            ' _loadUserData (phone fallback): firstName=$_firstName, lastName=$_lastName',
          );
        } else {
          debugPrint(' _loadUserData: No user document found at all');
        }
      }
    } catch (e) {
      debugPrint(' Error loading user data: $e');
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return InAppNotificationListener(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _buildHomeTab(),
            _buildPatientsTab(),
            _buildAppointmentsTab(),
            _buildProfileTab(),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(13),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, Icons.home_outlined, Icons.home),
                  _buildNavItem(1, Icons.people_outline, Icons.people),
                  _buildNavItem(
                    2,
                    Icons.calendar_month_outlined,
                    Icons.calendar_month,
                  ),
                  _buildNavItem(3, Icons.person_outline, Icons.person),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── TAB 1: DOCTOR HOME ─────────────────────────────────────────────

  Widget _buildHomeTab() {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // ── Simple header matching patient style ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Hi Dr. ${_firstName.isNotEmpty ? _firstName : 'Doctor'}!',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DoctorNotificationsScreen(),
                        ),
                      );
                    },
                    child: StreamBuilder<int>(
                      stream: NotificationService().streamUnreadCount(
                        FirebaseAuth.instance.currentUser?.uid ?? '',
                      ),
                      builder: (context, snapshot) {
                        final unread = snapshot.data ?? 0;
                        return Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE5E7EB),
                              width: 1,
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                unread > 0
                                    ? Icons.notifications_active
                                    : Icons.notifications_outlined,
                                color: const Color(0xFF6B7280),
                                size: 24,
                              ),
                              if (unread > 0)
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      minWidth: 18,
                                      minHeight: 18,
                                    ),
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE53935),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Text(
                                        unread > 9 ? '9+' : '$unread',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildStatsRow(),
              const SizedBox(height: 24),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _quickAction(
                      icon: Icons.dashboard_outlined,
                      label: 'Patient\nDashboard',
                      description: 'View patient details',
                      color: const Color(0xFF6366F1),
                      onTap: () => setState(() => _currentIndex = 1),
                    ),
                    const SizedBox(width: 12),
                    _quickAction(
                      icon: Icons.notifications_active_outlined,
                      label: 'Patient\nAlerts',
                      description: 'View patient risk alerts',
                      color: const Color(0xFF22C55E),
                      onTap: () => _navigateTo(
                        const DoctorNotificationsScreen(initialTab: 1),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _quickAction(
                      icon: Icons.medical_information_outlined,
                      label: 'Treatment\nPlans',
                      description: 'Manage treatment plans',
                      color: const Color(0xFFEF4444),
                      onTap: () => _navigateTo(const TreatmentPlanScreen()),
                    ),
                    const SizedBox(width: 12),
                    _quickAction(
                      icon: Icons.bookmark_outline,
                      label: 'My\nRequests',
                      description: 'View consultation requests',
                      color: const Color(0xFFF97316),
                      onTap: () =>
                          _navigateTo(const ConsultationRequestsScreen()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Active session banner
              _buildDoctorActiveSessionBanner(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Upcoming Appointments",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _currentIndex = 2),
                    child: const Text('See All'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildTodaysAppointmentsSection(),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDoctorActiveSessionBanner() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<List<Consultation>>(
      stream: ConsultationService().streamDoctorConsultations(user.uid),
      builder: (context, snapshot) {
        final allSessions = snapshot.data ?? [];

        // Auto-complete expired follow-up sessions
        for (final session in allSessions) {
          if (session.isFollowUpExpired &&
              !_autoCompletedFollowUps.contains(session.consultationID)) {
            _autoCompletedFollowUps.add(session.consultationID);
            ConsultationService().completeConsultation(session.consultationID);
            NotificationService().notifyFollowUpCompleted(
              patientID: session.patientID,
              doctorID: session.doctorID,
              doctorName: session.doctorName ?? 'Doctor',
              patientName: session.patientName ?? 'Patient',
              consultationID: session.consultationID,
            );
          }
        }

        final active =
            allSessions
                .where(
                  (c) =>
                      (c.status == 'active' || c.status == 'followUp') &&
                      !c.isFollowUpExpired,
                )
                .toList()
              // Show active sessions first, then follow-ups
              ..sort((a, b) {
                if (a.status == 'active' && b.status != 'active') return -1;
                if (a.status != 'active' && b.status == 'active') return 1;
                return 0;
              });

        if (active.isEmpty) return const SizedBox.shrink();

        return Column(
          children: active.map((session) {
            return _buildSessionBannerCard(
              session: session,
              isDoctor: true,
              personName: session.patientName ?? 'Patient',
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildSessionBannerCard({
    required Consultation session,
    required bool isDoctor,
    required String personName,
  }) {
    final isFollowUp = session.status == 'followUp';

    // Calculate remaining days for follow-up
    String? remainingText;
    if (isFollowUp && session.followUpDueDate != null) {
      final now = DateTime.now();
      final due = session.followUpDueDate!;
      final diff = due.difference(now).inDays;
      if (diff > 1) {
        remainingText = '$diff days remaining';
      } else if (diff == 1) {
        remainingText = '1 day remaining';
      } else if (diff == 0) {
        remainingText = 'Due today';
      } else {
        remainingText = 'Overdue';
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ConsultationSessionScreen(
                consultationId: session.consultationID,
                isDoctor: isDoctor,
              ),
            ),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isFollowUp
                  ? [const Color(0xFF64ADB3), const Color(0xFF4D9DA3)]
                  : [const Color(0xFF22C55E), const Color(0xFF16A34A)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color:
                    (isFollowUp
                            ? const Color(0xFF64ADB3)
                            : const Color(0xFF22C55E))
                        .withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isFollowUp
                      ? Icons.assignment_turned_in_outlined
                      : Icons.video_call_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isFollowUp ? 'Follow-Up In Progress' : 'Active Session',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'With $personName',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    if (isFollowUp && remainingText != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            color: Colors.white.withOpacity(0.85),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            remainingText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.85),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isFollowUp ? 'View' : 'Join',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isFollowUp
                        ? const Color(0xFF4D9DA3)
                        : const Color(0xFF22C55E),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodaysAppointmentsSection() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return _buildEmptyCard(
        icon: Icons.calendar_today_outlined,
        title: 'Not logged in',
        subtitle: 'Please log in to see appointments',
      );
    }

    return StreamBuilder<List<Consultation>>(
      stream: ConsultationService().streamTodaysConsultations(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildEmptyCard(
            icon: Icons.error_outline,
            title: 'Error loading appointments',
            subtitle: snapshot.error.toString(),
          );
        }

        final bookings = snapshot.data ?? [];

        if (bookings.isEmpty) {
          return _buildEmptyCard(
            icon: Icons.calendar_today_outlined,
            title: 'No appointments today',
            subtitle: 'Your scheduled appointments will appear here',
          );
        }

        // Sort by time slot (soonest first)
        bookings.sort((a, b) {
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

        return Column(
          children: bookings.map((booking) {
            return _buildTodayAppointmentCard(booking);
          }).toList(),
        );
      },
    );
  }

  Widget _buildTodayAppointmentCard(Consultation booking) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PatientDetailScreen(
                        patientId: booking.patientID,
                        patientName: booking.patientName ?? 'Patient',
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person,
                    color: AppColors.primary.withAlpha(120),
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.patientName ?? 'Unknown Patient',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'General Consultation',
                      style: TextStyle(color: AppColors.textHint, fontSize: 13),
                    ),
                  ],
                ),
              ),
              // View patient profile button
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PatientDetailScreen(
                        patientId: booking.patientID,
                        patientName: booking.patientName ?? 'Patient',
                      ),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.medical_information_outlined,
                  color: AppColors.primary,
                  size: 22,
                ),
                tooltip: 'View Medical History',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary.withAlpha(25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Date and time row
          Row(
            children: [
              _buildInfoChip(
                Icons.calendar_today_outlined,
                booking.consultationDate != null
                    ? booking.formattedDate
                    : 'Today',
              ),
              const SizedBox(width: 16),
              if (booking.timeSlot != null)
                _buildInfoChip(Icons.access_time, booking.timeSlot!),
            ],
          ),

          // Start Consultation button (disabled until 30 min before)
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isChatCallAvailable(booking)
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ConsultationSessionScreen(
                            consultationId: booking.consultationID,
                            isDoctor: true,
                          ),
                        ),
                      );
                    }
                  : null,
              icon: Icon(
                Icons.video_call_outlined,
                size: 20,
                color: _isChatCallAvailable(booking)
                    ? Colors.white
                    : AppColors.textHint,
              ),
              label: Text(
                _isChatCallAvailable(booking)
                    ? 'Start Consultation'
                    : 'Available 30 min before appointment',
                style: TextStyle(
                  color: _isChatCallAvailable(booking)
                      ? Colors.white
                      : AppColors.textHint,
                  fontWeight: FontWeight.w600,
                  fontSize: _isChatCallAvailable(booking) ? 14 : 12,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isChatCallAvailable(booking)
                    ? AppColors.primary
                    : Colors.grey.shade200,
                disabledBackgroundColor: Colors.grey.shade200,
                elevation: _isChatCallAvailable(booking) ? 2 : 0,
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

  /// Returns true if the consultation starts within 30 minutes from now
  /// or has already started (i.e. the time has passed).
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
    // Available if within 30 min before start or already started
    return diff <= 30;
  }

  /// Parses a time slot string like "10:00 AM" into a TimeOfDay
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

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ],
    );
  }

  String _formatDueDate(DateTime date) {
    const months = [
      '',
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
    return '${months[date.month]} ${date.day}, ${date.year}';
  }

  Widget _buildStatsRow() {
    final user = FirebaseAuth.instance.currentUser;

    Widget buildStatCard(
      String value,
      String label,
      Color color,
      IconData icon,
    ) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
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
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildContent(
      String served,
      String followUp,
      String today,
      String upcoming,
    ) {
      return Row(
        children: [
          buildStatCard(
            served,
            'Served Patients',
            const Color(0xFF3B82F6),
            Icons.people_outline,
          ),
          const SizedBox(width: 12),
          buildStatCard(
            followUp,
            'Follow-Up',
            const Color(0xFF8B5CF6),
            Icons.event_repeat_rounded,
          ),
          const SizedBox(width: 12),
          buildStatCard(
            today,
            'Today',
            const Color(0xFF10B981),
            Icons.calendar_today_outlined,
          ),
          const SizedBox(width: 12),
          buildStatCard(
            upcoming,
            'Upcoming',
            const Color(0xFFF59E0B),
            Icons.upcoming_outlined,
          ),
        ],
      );
    }

    if (user == null) {
      return buildContent('0', '0', '0', '0');
    }

    return StreamBuilder<List<Consultation>>(
      stream: ConsultationService().streamDoctorConsultations(user.uid),
      builder: (context, allSnapshot) {
        final allBookings = allSnapshot.data ?? [];

        final now = DateTime.now();
        final startOfDay = DateTime(now.year, now.month, now.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));

        final servedCount = allBookings
            .where((b) => b.status == 'completed')
            .map((b) => b.patientID)
            .toSet()
            .length;

        final followUpCount = allBookings
            .where((b) => b.status == 'followUp')
            .length;

        final todayCount = allBookings.where((b) {
          final date = b.consultationDate;
          if (date == null) return false;
          return date.isAfter(startOfDay) &&
              date.isBefore(endOfDay) &&
              b.status == 'accepted';
        }).length;

        final upcomingCount = allBookings
            .where(
              (b) =>
                  b.status == 'accepted' &&
                  b.consultationDate != null &&
                  !b.consultationDate!.isBefore(startOfDay),
            )
            .length;

        return buildContent(
          '$servedCount',
          '$followUpCount',
          '$todayCount',
          '$upcomingCount',
        );
      },
    );
  }

  // ─── TAB 2: PATIENTS LIST ───────────────────────────────────────────

  Widget _buildPatientsTab() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Follow-Up Patients',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search a Patient',
                  hintStyle: TextStyle(color: AppColors.textHint),
                  prefixIcon: Icon(Icons.search, color: AppColors.textHint),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onChanged: (value) {
                  setState(() {});
                },
              ),
            ),
          ),
          // Patients list — query consultations with 'followUp' status for this doctor
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('consultations')
                  .where(
                    'doctorID',
                    isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                  )
                  .where('status', isEqualTo: 'followUp')
                  .snapshots(),

              builder: (context, consultSnap) {
                if (consultSnap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                final consultDocs = consultSnap.data?.docs ?? [];

                if (consultDocs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: _buildEmptyCard(
                        icon: Icons.people_outline,
                        title: 'No patients yet',
                        subtitle:
                            'Patients with active follow-up\nconsultations will appear here',
                      ),
                    ),
                  );
                }

                // Deduplicate by patientID, keep the most recent consultation
                final Map<String, Map<String, dynamic>> patientMap = {};
                for (final doc in consultDocs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final patientId = data['patientID'] as String? ?? '';
                  if (patientId.isNotEmpty) {
                    patientMap[patientId] = {
                      'patientName': data['patientName'] ?? 'Unknown',
                      'consultationId': doc.id,
                      'followUpDueDate': data['followUpDueDate'],
                    };
                  }
                }

                final patientEntries = patientMap.entries.toList();

                return Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: patientEntries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final entry = patientEntries[index];
                          final name = entry.value['patientName'] as String;
                          final dueDate = entry.value['followUpDueDate'];
                          String? dueDateStr;
                          if (dueDate != null && dueDate is Timestamp) {
                            final d = dueDate.toDate();
                            dueDateStr = '${d.day}/${d.month}/${d.year}';
                          }

                          return _buildPatientCard(
                            name: name,
                            patientId: entry.key,
                            followUpDue: dueDateStr,
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withAlpha(40),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Patients are listed here during their active follow-up period with you.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.primary,
                                  height: 1.4,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientCard({
    required String name,
    required String patientId,
    String? followUpDue,
  }) {
    return GestureDetector(
      onTap: () => _navigateTo(
        PatientDetailScreen(patientId: patientId, patientName: name),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
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
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withAlpha(25),
              child: Text(
                name[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (followUpDue != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Follow-up due: $followUpDue',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
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

  // ─── TAB 3: APPOINTMENTS ────────────────────────────────────────────

  Widget _buildAppointmentsTab() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Appointments',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _appointmentTabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textHint,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Follow-Up'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: StreamBuilder<List<Consultation>>(
        stream: ConsultationService().streamDoctorConsultations(
          FirebaseAuth.instance.currentUser?.uid ?? '',
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final allBookings = snapshot.data ?? [];

          // Filter based on selected tab
          List<Consultation> filtered;
          String emptyTitle;
          String emptySubtitle;

          switch (_selectedAppointmentTab) {
            case 1: // Follow-Up
              filtered = allBookings
                  .where((b) => b.status == 'followUp')
                  .toList();
              emptyTitle = 'No follow-up appointments';
              emptySubtitle =
                  'Patients with active follow-up plans will appear here';
              break;
            case 2: // Completed
              filtered = allBookings
                  .where((b) => b.status == 'completed')
                  .toList();
              emptyTitle = 'No completed appointments';
              emptySubtitle =
                  'Appointments you mark as completed will appear here';
              break;
            default: // Upcoming (pending + accepted + active, today or future only)
              final todayStart = DateTime.now();
              final startOfToday = DateTime(
                todayStart.year,
                todayStart.month,
                todayStart.day,
              );
              filtered = allBookings
                  .where(
                    (b) =>
                        (b.status == 'pending' ||
                            b.status == 'accepted' ||
                            b.status == 'active') &&
                        b.consultationDate != null &&
                        !b.consultationDate!.isBefore(startOfToday),
                  )
                  .toList();
              emptyTitle = 'No upcoming appointments';
              emptySubtitle = 'Your upcoming appointments will appear here';
              break;
          }

          if (filtered.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _buildEmptyCard(
                  icon: Icons.event_note_outlined,
                  title: emptyTitle,
                  subtitle: emptySubtitle,
                ),
              ),
            );
          }

          // Sort by date + time slot (soonest first)
          filtered.sort((a, b) {
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

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return _buildBookingCard(filtered[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildBookingCard(Consultation booking) {
    Color statusColor;
    IconData statusIcon;
    String statusText =
        booking.status.substring(0, 1).toUpperCase() +
        booking.status.substring(1);

    switch (booking.status) {
      case 'accepted':
        statusColor = AppColors.primary;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'active':
        statusColor = const Color(0xFF3B82F6);
        statusIcon = Icons.play_circle_outline;
        statusText = 'In Session';
        break;
      case 'followUp':
        statusColor = Colors.orange;
        statusIcon = Icons.access_time;
        statusText = 'Follow-up';
        break;
      case 'completed':
        statusColor = const Color(0xFF22C55E);
        statusIcon = Icons.check_circle;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusIcon = Icons.cancel_outlined;
        break;
      default: // pending
        statusColor = Colors.orange;
        statusIcon = Icons.pending_actions;
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConsultationSessionScreen(
              consultationId: booking.consultationID,
              isDoctor: true,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.inputBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(5),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PatientDetailScreen(
                          patientId: booking.patientID,
                          patientName: booking.patientName ?? 'Patient',
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person,
                      color: AppColors.primary.withAlpha(120),
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.patientName ?? 'Unknown Patient',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'General Consultation',
                        style: TextStyle(
                          color: AppColors.textHint,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // View patient profile button
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PatientDetailScreen(
                          patientId: booking.patientID,
                          patientName: booking.patientName ?? 'Patient',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.medical_information_outlined,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  tooltip: 'View Medical History',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary.withAlpha(25),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                if (booking.status != 'accepted' &&
                    booking.status != 'rejected')
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusText.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Date and time row
            Row(
              children: [
                _buildInfoChip(
                  Icons.calendar_today_outlined,
                  booking.consultationDate != null
                      ? booking.formattedDate
                      : 'No date',
                ),
                const SizedBox(width: 16),
                if (booking.timeSlot != null)
                  _buildInfoChip(Icons.access_time, booking.timeSlot!),
              ],
            ),

            // Due date for follow-up
            if (booking.status == 'followUp' &&
                booking.followUpDueDate != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildInfoChip(
                    Icons.event,
                    'Due: ${_formatDueDate(booking.followUpDueDate!)}',
                  ),
                ],
              ),
            ],

            // Start Consultation button (only for accepted, disabled until 30 min before)
            if (booking.status == 'accepted') ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isChatCallAvailable(booking)
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ConsultationSessionScreen(
                                consultationId: booking.consultationID,
                                isDoctor: true,
                              ),
                            ),
                          );
                        }
                      : null,
                  icon: Icon(
                    Icons.video_call_outlined,
                    size: 20,
                    color: _isChatCallAvailable(booking)
                        ? Colors.white
                        : AppColors.textHint,
                  ),
                  label: Text(
                    _isChatCallAvailable(booking)
                        ? 'Start Consultation'
                        : 'Available 30 min before appointment',
                    style: TextStyle(
                      color: _isChatCallAvailable(booking)
                          ? Colors.white
                          : AppColors.textHint,
                      fontWeight: FontWeight.w600,
                      fontSize: _isChatCallAvailable(booking) ? 14 : 12,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isChatCallAvailable(booking)
                        ? AppColors.primary
                        : Colors.grey.shade200,
                    disabledBackgroundColor: Colors.grey.shade200,
                    elevation: _isChatCallAvailable(booking) ? 2 : 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── TAB 4: PROFILE ────────────────────────────────────────────────

  Widget _buildProfileTab() {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = 'Dr. $_firstName $_lastName'.trim();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 45,
              backgroundColor: AppColors.primary.withAlpha(30),
              child: Text(
                _firstName.isNotEmpty ? _firstName[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              displayName.isNotEmpty ? displayName : 'Doctor',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              user?.phoneNumber ?? '',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 30),
            _profileTile(
              icon: Icons.person_outline,
              title: 'Edit Profile',
              onTap: () async {
                final updated = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DoctorEditProfileScreen(),
                  ),
                );
                if (updated == true) _loadUserData();
              },
            ),
            _profileTile(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DoctorNotificationsScreen(),
                  ),
                );
              },
            ),
            _profileTile(
              icon: Icons.access_time_outlined,
              title: 'Working Hours',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WorkingHoursScreen()),
                );
              },
            ),
            _profileTile(
              icon: Icons.help_outline,
              title: 'Help & Support',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DoctorHelpSupportScreen(),
                  ),
                );
              },
            ),
            _profileTile(
              icon: Icons.logout,
              title: 'Sign Out',
              color: Colors.red,
              onTap: _handleLogout,
            ),
          ],
        ),
      ),
    );
  }

  // ─── SHARED WIDGETS ─────────────────────────────────────────────────

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          isSelected ? activeIcon : icon,
          color: isSelected ? AppColors.primary : AppColors.textHint,
          size: 26,
        ),
      ),
    );
  }

  void _navigateTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Widget _quickAction({
    required IconData icon,
    required String label,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 170,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 14),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.3,
                ),
              ),
              const Spacer(),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
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
          Icon(icon, size: 40, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }

  Widget _profileTile({
    required IconData icon,
    required String title,
    Color? color,
    required VoidCallback onTap,
  }) {
    final tileColor = color ?? AppColors.textPrimary;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: tileColor),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: tileColor,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.textHint,
        size: 20,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
