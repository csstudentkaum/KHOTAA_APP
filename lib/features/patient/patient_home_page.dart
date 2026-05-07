import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dashboard_screen.dart';
import 'preventive_recommendations_screen.dart';
import 'booking/my_bookings_screen.dart';
import 'my_treatment_plans_screen.dart';
import 'patient_shell.dart';
import '../sensor_alerts/alert_service.dart';
import '../../services/daily_sensor_summary_service.dart';
import '../../services/consultation_service.dart';
import '../../services/notification_service.dart';
import '../../models/consultation.dart';
import '../../app/app_theme.dart';
import '../../shared/widgets/notification_bell_widget.dart';
import '../shared/consultation_session_screen.dart';

/// Patient Home Page - Main dashboard for patients
/// Matches the Figma design exactly
class PatientHomePage extends StatefulWidget {
  const PatientHomePage({super.key});

  @override
  State<PatientHomePage> createState() => _PatientHomePageState();
}

class _PatientHomePageState extends State<PatientHomePage>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<int> _currentTipNotifier = ValueNotifier<int>(0);
  String _userName = 'User'; // Default name
  final ConsultationService _consultationService = ConsultationService();
  final Set<String> _autoCompletedFollowUps = {};

  final List<String> _tips = [
    'Wear comfortable shoes to prevent foot injuries',
    'Check your feet daily for any cuts or sores',
    'Keep your feet clean and dry at all times',
  ];

  final PageController _tipsController = PageController();
  late AnimationController _emergencyButtonController;
  late Animation<double> _pulseAnimation;
  Timer? _tipsAutoScroll;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _emergencyButtonController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _emergencyButtonController,
        curve: Curves.easeInOut,
      ),
    );

    // Initialize alert service and add sample data
    _initializeAlertService();

    // Auto-scroll tips every 4 seconds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startTipsAutoScroll();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Restart auto-scroll if timer was lost (e.g. after hot reload)
    if (_tipsAutoScroll == null || !_tipsAutoScroll!.isActive) {
      _startTipsAutoScroll();
    }
  }

  Future<void> _initializeAlertService() async {
    try {
      // Get the actual user ID from Firebase Auth
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('No user logged in, skipping alert service init');
        return;
      }
      await AlertService().initialize(user.uid);
      await DailySensorSummaryService().initialize(user.uid);
    } catch (e) {
      debugPrint('Error initializing alert service: $e');
    }
  }

  void _loadUserName() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        // Use displayName if available, otherwise extract from email or use phone
        _userName = user.displayName ?? user.email?.split('@').first ?? 'User';
      });
    }
  }

  void _startTipsAutoScroll() {
    _tipsAutoScroll?.cancel();
    _tipsAutoScroll = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      if (!_tipsController.hasClients) return;
      final nextPage = (_currentTipNotifier.value + 1) % _tips.length;
      _tipsController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _tipsAutoScroll?.cancel();
    _tipsController.dispose();
    _currentTipNotifier.dispose();
    _emergencyButtonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  // Header with greeting and notification
                  _buildHeader(),
                  const SizedBox(height: 20),
                  // Tips carousel
                  _buildTipsCarousel(),
                  const SizedBox(height: 24),
                  // Feature cards grid
                  _buildFeatureCards(),
                  const SizedBox(height: 24),
                  // Active session (if any)
                  _buildActiveSessionBanner(),
                  // Upcoming appointments
                  _buildUpcomingAppointments(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            // Floating Emergency Button
            _buildEmergencyButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyButton() {
    return Positioned(
      right: 20,
      bottom: 20,
      child: ScaleTransition(
        scale: _pulseAnimation,
        child: GestureDetector(
          onTap: _showEmergencyDialog,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFE53935),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE53935).withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.phone, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }

  void _showEmergencyDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.emergency,
                  color: Color(0xFFE53935),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Emergency Call',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to call Ambulance 997?',
            style: TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6B7280),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _makeEmergencyCall();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.phone, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Call',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _makeEmergencyCall() async {
    final Uri phoneUri = Uri(scheme: 'tel', path: '997');
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not launch phone dialer'),
              backgroundColor: Color(0xFFE53935),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
    }
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Hi $_userName!',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const NotificationBellWidget(),
      ],
    );
  }

  Widget _buildTipsCarousel() {
    return Column(
      children: [
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F4F5),
            borderRadius: BorderRadius.circular(25),
          ),
          child: PageView.builder(
            controller: _tipsController,
            onPageChanged: (index) {
              _currentTipNotifier.value = index;
            },
            itemCount: _tips.length,
            itemBuilder: (context, index) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    _tips[index],
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF4D8A8F),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Dots indicator — only this rebuilds on tip change
        ValueListenableBuilder<int>(
          valueListenable: _currentTipNotifier,
          builder: (context, currentIndex, _) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _tips.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: currentIndex == index ? 8 : 6,
                  height: currentIndex == index ? 8 : 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: currentIndex == index
                        ? const Color(0xFF64ADB3)
                        : const Color(0xFFBBDFE2),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFeatureCards() {
    return Column(
      children: [
        // First row
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _quickAction(
                icon: Icons.calendar_today_outlined,
                label: 'Book an\nAppointment',
                description: 'Find a doctor or specialist',
                color: const Color(0xFF5C6BC0),
                onTap: () {
                  final shellState = context
                      .findAncestorStateOfType<PatientShellState>();
                  if (shellState != null) {
                    shellState.switchToTab(3);
                  }
                },
              ),
              const SizedBox(width: 12),
              _quickAction(
                icon: Icons.description_outlined,
                label: 'My Treatment\nPlan',
                description: 'View personalized plan',
                color: const Color(0xFF7E57C2),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MyTreatmentPlansScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Second row
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _quickAction(
                icon: Icons.health_and_safety,
                label: 'Foot Health\nStatus',
                description: 'View foot health',
                color: const Color(0xFFE57373),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DashboardScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              _quickAction(
                icon: Icons.lightbulb_outline,
                label: 'Preventive\nTips',
                description: 'View recommendations',
                color: const Color(0xFF26A69A),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const PreventiveRecommendationsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
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

  Widget _buildActiveSessionBanner() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<List<Consultation>>(
      stream: _consultationService.streamPatientConsultations(user.uid),
      builder: (context, snapshot) {
        final allSessions = snapshot.data ?? [];

        // Auto-complete expired follow-up sessions
        for (final session in allSessions) {
          if (session.isFollowUpExpired &&
              !_autoCompletedFollowUps.contains(session.consultationID)) {
            _autoCompletedFollowUps.add(session.consultationID);
            _consultationService.completeConsultation(session.consultationID);
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
              personName: session.doctorName ?? 'Doctor',
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildSessionBannerCard({
    required Consultation session,
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
                isDoctor: false,
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
              onPressed: _navigateToBookings,
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
                    .map((booking) => _buildRealAppointmentCard(booking))
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

  Widget _buildRealAppointmentCard(Consultation c) {
    final date = c.consultationDate;
    final dayStr = date != null ? '${date.day}' : '';
    final dayName = date != null ? _getDayAbbr(date.weekday) : '';

    return GestureDetector(
      onTap: _navigateToBookings,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFF64ADB3), Color(0xFF4D9DA3)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Date container
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayStr,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    dayName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Time and doctor info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (c.timeSlot != null)
                    Text(
                      c.timeSlot!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    c.doctorName ?? 'Doctor',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            // More options button
            GestureDetector(
              onTap: _navigateToBookings,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.more_horiz,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToBookings() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
    );
    if (result == 'findDoctor') {
      final shellState = context.findAncestorStateOfType<PatientShellState>();
      shellState?.switchToTab(3);
    }
  }

  String _getDayAbbr(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
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
