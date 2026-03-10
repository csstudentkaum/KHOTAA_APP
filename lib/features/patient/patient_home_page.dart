import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dashboard_screen.dart';
import 'connect_insole_screen.dart';
import 'preventive_recommendations_screen.dart';
import 'risk_explanation_screen.dart';
import '../../services/alert_service.dart';
import '../../services/push_notification_service.dart';
import '../../models/smart_alert.dart';
import '../../shared/widgets/notification_bell_widget.dart';

/// Patient Home Page - Main dashboard for patients
/// Matches the Figma design exactly
class PatientHomePage extends StatefulWidget {
  const PatientHomePage({Key? key}) : super(key: key);

  @override
  State<PatientHomePage> createState() => _PatientHomePageState();
}

class _PatientHomePageState extends State<PatientHomePage>
    with SingleTickerProviderStateMixin {
  int _currentTipIndex = 0;
  String _userName = 'User'; // Default name

  final List<String> _tips = [
    'Wear comfortable shoes to prevent foot injuries',
    'Check your feet daily for any cuts or sores',
    'Keep your feet clean and dry at all times',
  ];

  final PageController _tipsController = PageController();
  late AnimationController _emergencyButtonController;
  late Animation<double> _pulseAnimation;
  StreamSubscription? _notificationSubscription;

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

    // Listen for notification taps
    _notificationSubscription = PushNotificationService()
        .onNotificationTap
        .listen(_handleNotificationTap);
  }

  Future<void> _initializeAlertService() async {
    try {
      // Initialize with a patient ID (in production, get from auth service)
      await AlertService().initialize('patient_001');
      // Add sample alerts for demo
      await AlertService().addSampleAlerts();
    } catch (e) {
      debugPrint('Error initializing alert service: $e');
    }
  }

  void _loadUserName() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        // Use displayName if available, otherwise extract from email or use phone
        _userName = user.displayName ?? 
                    user.email?.split('@').first ?? 
                    'User';
      });
    }
  }

  void _handleNotificationTap(SmartAlert alert) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RiskExplanationScreen(alert: alert),
      ),
    );
  }

  @override
  void dispose() {
    _tipsController.dispose();
    _emergencyButtonController.dispose();
    _notificationSubscription?.cancel();
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
            child: const Icon(
              Icons.phone,
              color: Colors.white,
              size: 28,
            ),
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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to call Ambulance 997?',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF6B7280),
            ),
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
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
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
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(25),
          ),
          child: PageView.builder(
            controller: _tipsController,
            onPageChanged: (index) {
              setState(() => _currentTipIndex = index);
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
                      color: Color(0xFF6B7280),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Dots indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _tips.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentTipIndex == index ? 8 : 6,
              height: _currentTipIndex == index ? 8 : 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentTipIndex == index
                    ? const Color(0xFF2A9D8F)
                    : const Color(0xFFD1D5DB),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCards() {
    return Column(
      children: [
        // First row
        Row(
          children: [
            Expanded(
              child: _FeatureCard(
                icon: Icons.calendar_today_outlined,
                iconColor: const Color(0xFF5C6BC0),  // Indigo blue for appointments
                iconBgColor: const Color(0xFFE8EAF6),
                title: 'Book an\nAppointment',
                subtitle: 'Find a Doctor or\nspecialist',
                cardColor: const Color(0xFFE8EAF6),  // Light indigo background
                borderColor: const Color(0xFF5C6BC0),
                hasShadow: false,
                onTap: () => _showSnackBar('Book Appointment'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _FeatureCard(
                icon: Icons.description_outlined,
                iconColor: const Color(0xFF7E57C2),  // Purple for treatment
                iconBgColor: const Color(0xFFEDE7F6),
                title: 'My Treatment\nPlan',
                subtitle: 'See your personalized\ntreatment plan',
                cardColor: const Color(0xFFEDE7F6),  // Light purple background
                borderColor: const Color(0xFF7E57C2),
                hasShadow: false,
                onTap: () => _showSnackBar('Treatment Plan'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Second row
        Row(
          children: [
            Expanded(
              child: _FeatureCard(
                icon: FontAwesomeIcons.shoePrints,  // Foot icon
                iconColor: const Color(0xFFE57373),
                iconBgColor: const Color(0xFFFCE4EC),
                title: 'Foot Health\nStatus',
                subtitle: 'View Foot Health',
                cardColor: const Color(0xFFFCE4EC),
                borderColor: const Color(0xFFE57373),
                hasShadow: false,
                iconRotation: -math.pi / 2,  // Rotate to vertical
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DashboardScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _FeatureCard(
                icon: Icons.lightbulb_outline,
                iconColor: const Color(0xFF26A69A),
                iconBgColor: const Color(0xFFE0F2F1),
                title: 'View Preventive\nRecommendations',
                subtitle: 'See recommendations',
                cardColor: const Color(0xFFE0F2F1),
                borderColor: const Color(0xFF26A69A),
                hasShadow: false,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PreventiveRecommendationsScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUpcomingAppointments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upcoming Appointments',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 16),
        _AppointmentCard(
          day: '12',
          dayName: 'Tue',
          time: '09:30 AM',
          doctorName: 'Dr. Abdullah',
          onTap: () => _showSnackBar('Appointment Details'),
          onMoreTap: () => _showSnackBar('More Options'),
        ),
      ],
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2A9D8F),
      ),
    );
  }
}

/// Feature Card Widget with hover/tap animation
class _FeatureCard extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final Color cardColor;
  final Color borderColor;
  final bool hasShadow;
  final double iconRotation;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.cardColor,
    required this.borderColor,
    this.hasShadow = true,
    this.iconRotation = 0,
    required this.onTap,
  });

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> 
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;  // For hover effect (border)
  bool _isPressed = false;  // For press effect (scale)
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      // Hover effect - shows border when mouse enters
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        // On mobile: long press also shows hover effect
        onLongPressStart: (_) => setState(() => _isHovered = true),
        onLongPressEnd: (_) => setState(() => _isHovered = false),
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 150,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    // Border shows on HOVER or PRESS
                    color: (_isHovered || _isPressed)
                        ? widget.borderColor 
                        : widget.borderColor.withOpacity(0.0),
                    width: 2.5,
                  ),
                  boxShadow: (_isHovered || _isPressed)
                      ? [
                          // Colored shadow on hover
                          BoxShadow(
                            color: widget.borderColor.withOpacity(0.25),
                            blurRadius: 12,
                            spreadRadius: 1,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : widget.hasShadow
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: widget.iconBgColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Transform.rotate(
                        angle: widget.iconRotation,
                        child: Icon(widget.icon, color: widget.iconColor, size: 24),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: const Color(0xFF6B7280).withOpacity(0.8),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Appointment Card Widget
class _AppointmentCard extends StatelessWidget {
  final String day;
  final String dayName;
  final String time;
  final String doctorName;
  final VoidCallback onTap;
  final VoidCallback onMoreTap;

  const _AppointmentCard({
    required this.day,
    required this.dayName,
    required this.time,
    required this.doctorName,
    required this.onTap,
    required this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFF2A9D8F),
              Color(0xFF3DB4A6),
            ],
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
                    day,
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
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    doctorName,
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
              onTap: onMoreTap,
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
}


