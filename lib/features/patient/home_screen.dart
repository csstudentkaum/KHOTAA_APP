import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../app/app_theme.dart';

class DHomeScreen extends StatefulWidget {
  const DHomeScreen({super.key});

  @override
  State<DHomeScreen> createState() => _DHomeScreenState();
}

class _DHomeScreenState extends State<DHomeScreen> {
  int _currentIndex = 0;
  String _firstName = '';
  String _lastName = '';

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
          _lastName = doc.data()?['lastName'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
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
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(),
          _buildPatientsTab(),
          _buildAppointmentsTab(),
          _buildProfileTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textHint,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Patients',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Appointments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // ─── TAB 1: DOCTOR HOME ─────────────────────────────────────────────

  Widget _buildHomeTab() {
    final greeting = _firstName.isNotEmpty
        ? 'Hello, Dr. $_firstName'
        : 'Hello, Doctor';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),

            // Header row
            Row(
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
                GestureDetector(
                  onTap: () {
                    // TODO: notifications screen
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        const Center(
                          child: Icon(
                            Icons.notifications_outlined,
                            color: AppColors.primary,
                            size: 26,
                          ),
                        ),
                        Positioned(
                          right: 10,
                          top: 10,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Welcome back! Good to see you.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),

            // Stats cards
            _buildStatsRow(),
            const SizedBox(height: 24),

            // Quick actions — 2x2 grid
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
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
                    icon: Icons.image_search_outlined,
                    label: 'Image\nReview',
                    description: 'Review foot images',
                    color: const Color(0xFF22C55E),
                    onTap: () => _navigateTo(const _ImageReviewScreen()),
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
                    onTap: () => _navigateTo(const _TreatmentPlanScreen()),
                  ),
                  const SizedBox(width: 12),
                  _quickAction(
                    icon: Icons.bookmark_outline,
                    label: 'My\nBookings',
                    description: 'View booking requests',
                    color: const Color(0xFFF97316),
                    onTap: () =>
                        _navigateTo(const _ConsultationRequestsScreen()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Consultation requests
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Consultation Requests',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      _navigateTo(const _ConsultationRequestsScreen()),
                  child: const Text('See All'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildConsultationRequestCard(
              patientName: 'No pending requests',
              isEmpty: true,
            ),
            const SizedBox(height: 24),

            // Today's appointments
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Today's Appointments",
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
            _buildEmptyCard(
              icon: Icons.calendar_today_outlined,
              title: 'No appointments today',
              subtitle: 'Your scheduled appointments will appear here',
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _statCard(
          label: 'Total Patients',
          value: '0',
          icon: Icons.people_outline,
          color: const Color(0xFF6366F1),
        ),
        const SizedBox(width: 10),
        _statCard(
          label: 'Today',
          value: '0',
          icon: Icons.calendar_today_outlined,
          color: const Color(0xFF22C55E),
        ),
        const SizedBox(width: 10),
        _statCard(
          label: 'Pending',
          value: '0',
          icon: Icons.pending_actions_outlined,
          color: const Color(0xFFF97316),
        ),
      ],
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsultationRequestCard({
    required String patientName,
    bool isEmpty = false,
  }) {
    if (isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: const Column(
          children: [
            Icon(Icons.inbox_outlined, size: 36, color: AppColors.textHint),
            SizedBox(height: 8),
            Text(
              'No pending consultation requests',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inputBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary.withAlpha(30),
            child: Text(
              patientName[0].toUpperCase(),
              style: const TextStyle(
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
                  patientName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'New consultation request',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _miniButton(Icons.check, const Color(0xFF22C55E), () {}),
              const SizedBox(width: 8),
              _miniButton(Icons.close, Colors.red, () {}),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  // ─── TAB 2: PATIENTS LIST ───────────────────────────────────────────

  Widget _buildPatientsTab() {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'My Patients',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'View and manage your patients',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),

                // Search bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.inputFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.inputBorder),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.search, color: AppColors.textHint, size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search patients...',
                            hintStyle: TextStyle(
                              color: AppColors.textHint,
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Patient list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'patient')
                  .where(
                    'doctorId',
                    isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                  )
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                final patients = snapshot.data?.docs ?? [];

                if (patients.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: _buildEmptyCard(
                        icon: Icons.people_outline,
                        title: 'No patients yet',
                        subtitle: 'Your assigned patients will appear here',
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: patients.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final data = patients[index].data() as Map<String, dynamic>;
                    final name =
                        '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'
                            .trim();

                    return _buildPatientCard(
                      name: name.isNotEmpty ? name : 'Unknown',
                      phone: data['phone'] ?? '',
                      patientId: patients[index].id,
                    );
                  },
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
    required String phone,
    required String patientId,
  }) {
    return GestureDetector(
      onTap: () => _navigateTo(
        _PatientDetailScreen(patientId: patientId, patientName: name),
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
                  const SizedBox(height: 3),
                  Text(
                    phone,
                    style: const TextStyle(
                      fontSize: 13,
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

  // ─── TAB 3: APPOINTMENTS ────────────────────────────────────────────

  Widget _buildAppointmentsTab() {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Appointments',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Manage your schedule',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                // Filter chips
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.filter_list,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Filter',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Appointment status tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _appointmentTab('Upcoming', true),
                const SizedBox(width: 10),
                _appointmentTab('Completed', false),
                const SizedBox(width: 10),
                _appointmentTab('Cancelled', false),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Appointments list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('appointments')
                  .where(
                    'doctorId',
                    isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                  )
                  .orderBy('dateTime', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                final appointments = snapshot.data?.docs ?? [];

                if (appointments.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: _buildEmptyCard(
                        icon: Icons.event_note_outlined,
                        title: 'No appointments yet',
                        subtitle:
                            'Your scheduled appointments will appear here',
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: appointments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final data =
                        appointments[index].data() as Map<String, dynamic>;
                    return _buildAppointmentCard(data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _appointmentTab(String label, bool isActive) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.inputFill,
          borderRadius: BorderRadius.circular(10),
          border: isActive ? null : Border.all(color: AppColors.inputBorder),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> data) {
    final patientName = data['patientName'] ?? 'Unknown';
    final status = data['status'] ?? 'upcoming';
    final dateTime = (data['dateTime'] as Timestamp?)?.toDate();
    final timeStr = dateTime != null
        ? '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}'
        : 'TBD';
    final dateStr = dateTime != null
        ? '${dateTime.day}/${dateTime.month}/${dateTime.year}'
        : 'TBD';

    Color statusColor;
    switch (status) {
      case 'completed':
        statusColor = const Color(0xFF22C55E);
        break;
      case 'cancelled':
        statusColor = Colors.red;
        break;
      default:
        statusColor = AppColors.primary;
    }

    return Container(
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
          // Date block
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  dateTime != null ? '${dateTime.day}' : '--',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  dateTime != null
                      ? [
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
                        ][dateTime.month - 1]
                      : '--',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
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
                  patientName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 14,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      timeStr,
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status[0].toUpperCase() + status.substring(1),
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
              onTap: () {},
            ),
            _profileTile(
              icon: Icons.schedule_outlined,
              title: 'Working Hours',
              onTap: () {},
            ),
            _profileTile(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              onTap: () {},
            ),
            _profileTile(
              icon: Icons.lock_outline,
              title: 'Privacy & Security',
              onTap: () {},
            ),
            _profileTile(
              icon: Icons.help_outline,
              title: 'Help & Support',
              onTap: () {},
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
              const SizedBox(height: 4),
              Text(
                description,
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
          const SizedBox(height: 9),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color.fromARGB(160, 156, 163, 175),
            ),
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

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// SUB-SCREENS (navigated from quick actions)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// ─── PATIENT DETAIL (DOCTOR DASHBOARD) ────────────────────────────────

class _PatientDetailScreen extends StatefulWidget {
  final String patientId;
  final String patientName;

  const _PatientDetailScreen({
    required this.patientId,
    required this.patientName,
  });

  @override
  State<_PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<_PatientDetailScreen> {
  int _selectedFoot = 0; // 0 = Left, 1 = Right

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
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: AppColors.primary,
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
          final phone = userData['phone'] ?? 'N/A';
          final email = userData['email'] ?? 'N/A';
          final age = userData['age'] ?? '--';
          final gender = userData['gender'] ?? 'N/A';
          final diabetesType = userData['diabetesType'] ?? 'Type 2';

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
                      diabetesType: diabetesType,
                      lastReadingTime: lastReadingTime,
                      phone: phone,
                      email: email,
                    ),
                    const SizedBox(height: 12),

                    // ── Action Buttons Row ──
                    Row(
                      children: [
                        _buildActionButton(
                          icon: Icons.call_outlined,
                          label: 'Call',
                          color: AppColors.primary,
                          onTap: () {},
                        ),
                        const SizedBox(width: 10),
                        _buildActionButton(
                          icon: Icons.videocam_outlined,
                          label: 'Video',
                          color: const Color(0xFF6366F1),
                          onTap: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── View Complete Medical Records ──
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => _PatientMedicalRecordsScreen(
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
                          builder: (_) => const _ImageReviewScreen(),
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
                          builder: (_) => const _TreatmentPlanScreen(),
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
    required String diabetesType,
    required String lastReadingTime,
    required String phone,
    required String email,
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
          // Top row: avatar + name + risk badge
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

          // Detail rows
          _infoRow(Icons.bloodtype_outlined, 'Diabetes', diabetesType),
          const SizedBox(height: 8),
          _infoRow(Icons.access_time_outlined, 'Last Reading', lastReadingTime),
          const SizedBox(height: 8),
          _infoRow(Icons.phone_outlined, 'Phone', phone),
          const SizedBox(height: 8),
          _infoRow(Icons.email_outlined, 'Email', email),
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

  // ── Action Button (Call / Video / Notes) ──
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

  // ── Reading Card (Pressure / Temperature) ──
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

  // ── Foot Pressure Map ──
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
          // Toggle: Left / Right
          Row(
            children: [
              _footToggle('Left Foot', 0),
              const SizedBox(width: 8),
              _footToggle('Right Foot', 1),
            ],
          ),
          const SizedBox(height: 16),

          // Foot outline with pressure zones
          SizedBox(
            height: 260,
            child: CustomPaint(
              size: const Size(160, 260),
              painter: _FootPressurePainter(points: points),
            ),
          ),
          const SizedBox(height: 12),

          // Legend
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

  // ── Quick Action Tile ──
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

  // ── Helpers ──
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
class _FootPressurePainter extends CustomPainter {
  final List<double>
  points; // 6 zones: toe, ball-l, ball-r, arch, heel-l, heel-r

  _FootPressurePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;

    // Draw foot outline
    final outlinePaint = Paint()
      ..color = const Color(0xFFD1D5DB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final footPath = Path();
    // Simplified foot shape
    footPath.moveTo(cx - 25, 20);
    footPath.quadraticBezierTo(cx - 35, 0, cx - 15, 0);
    footPath.quadraticBezierTo(cx, 5, cx + 15, 0);
    footPath.quadraticBezierTo(cx + 35, 0, cx + 25, 20);
    // Toes to ball
    footPath.quadraticBezierTo(cx + 40, 50, cx + 38, 80);
    // Ball to arch
    footPath.quadraticBezierTo(cx + 35, 120, cx + 20, 160);
    // Arch to heel
    footPath.quadraticBezierTo(cx + 15, 200, cx + 25, 230);
    footPath.quadraticBezierTo(cx + 28, 250, cx, 255);
    footPath.quadraticBezierTo(cx - 28, 250, cx - 25, 230);
    footPath.quadraticBezierTo(cx - 15, 200, cx - 20, 160);
    footPath.quadraticBezierTo(cx - 35, 120, cx - 38, 80);
    footPath.quadraticBezierTo(cx - 40, 50, cx - 25, 20);
    footPath.close();

    // Fill foot background
    final footFill = Paint()
      ..color = const Color(0xFFF3F4F6)
      ..style = PaintingStyle.fill;
    canvas.drawPath(footPath, footFill);
    canvas.drawPath(footPath, outlinePaint);

    // Draw pressure zones
    final zones = [
      Offset(cx, 15), // Toe
      Offset(cx - 18, 65), // Ball left
      Offset(cx + 18, 65), // Ball right
      Offset(cx, 140), // Arch
      Offset(cx - 12, 230), // Heel left
      Offset(cx + 12, 230), // Heel right
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

      // Label
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
  bool shouldRepaint(covariant _FootPressurePainter oldDelegate) =>
      oldDelegate.points != points;
}

// ── Patient Medical Records Screen ──
class _PatientMedicalRecordsScreen extends StatelessWidget {
  final String patientId;
  final String patientName;

  const _PatientMedicalRecordsScreen({
    required this.patientId,
    required this.patientName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        title: Text(
          '$patientName - Records',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: AppColors.primary,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('dfu_readings')
            .where('patientId', isEqualTo: patientId)
            .orderBy('timestamp', descending: true)
            .limit(30)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.folder_off_outlined,
                    size: 64,
                    color: AppColors.textHint,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No medical records yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final d = docs[index].data() as Map<String, dynamic>;
              final pressure = (d['pressure'] ?? 0).toDouble();
              final temperature = (d['temperature'] ?? 0).toDouble();
              String time = '';
              if (d['timestamp'] != null) {
                final ts = (d['timestamp'] as dynamic).toDate();
                time =
                    '${ts.day}/${ts.month}/${ts.year} ${ts.hour}:${ts.minute.toString().padLeft(2, '0')}';
              }

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.inputBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.monitor_heart_outlined,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'P: ${pressure.toStringAsFixed(0)} kPa  •  T: ${temperature.toStringAsFixed(1)} °C',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            time,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ─── IMAGE REVIEW SCREEN ──────────────────────────────────────────────

class _ImageReviewScreen extends StatelessWidget {
  const _ImageReviewScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          'Image Review',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: AppColors.primary,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('foot_images')
            .where(
              'doctorId',
              isEqualTo: FirebaseAuth.instance.currentUser?.uid,
            )
            .orderBy('uploadedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final images = snapshot.data?.docs ?? [];

          if (images.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.image_not_supported_outlined,
                      size: 64,
                      color: AppColors.textHint.withAlpha(100),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No images to review',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Patient foot images will appear here for your review',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: AppColors.textHint),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: images.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final data = images[index].data() as Map<String, dynamic>;
              final patientName = data['patientName'] ?? 'Unknown';
              final status = data['status'] ?? 'pending';
              final uploadedAt = (data['uploadedAt'] as Timestamp?)?.toDate();

              return Container(
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
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppColors.inputFill,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.image_outlined,
                        color: AppColors.textHint,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patientName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            uploadedAt != null
                                ? '${uploadedAt.day}/${uploadedAt.month}/${uploadedAt.year}'
                                : 'Unknown date',
                            style: const TextStyle(
                              fontSize: 12,
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
                        color: status == 'reviewed'
                            ? const Color(0xFF22C55E).withAlpha(20)
                            : const Color(0xFFF97316).withAlpha(20),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status == 'reviewed' ? 'Reviewed' : 'Pending',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: status == 'reviewed'
                              ? const Color(0xFF22C55E)
                              : const Color(0xFFF97316),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ─── TREATMENT PLAN SCREEN ────────────────────────────────────────────

class _TreatmentPlanScreen extends StatelessWidget {
  const _TreatmentPlanScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          'Treatment Plans',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: AppColors.primary,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('treatment_plans')
            .where(
              'patientId',
              isEqualTo: FirebaseAuth.instance.currentUser?.uid,
            )
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final plans = snapshot.data?.docs ?? [];

          if (plans.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.medical_information_outlined,
                      size: 64,
                      color: AppColors.textHint.withAlpha(100),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No treatment plans yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Create personalized treatment plans for your patients',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: AppColors.textHint),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: plans.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final data = plans[index].data() as Map<String, dynamic>;
              final patientName = data['patientName'] ?? 'Unknown';
              final diagnosis = data['diagnosis'] ?? '';
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

              return Container(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            patientName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          createdAt != null
                              ? '${createdAt.day}/${createdAt.month}/${createdAt.year}'
                              : '',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                    if (diagnosis.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withAlpha(15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          diagnosis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      data['plan'] ?? 'No plan details',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: add new treatment plan
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// ─── CONSULTATION REQUESTS SCREEN ─────────────────────────────────────

class _ConsultationRequestsScreen extends StatelessWidget {
  const _ConsultationRequestsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          'Consultation Requests',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: AppColors.primary,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('consultation_requests')
            .where(
              'doctorId',
              isEqualTo: FirebaseAuth.instance.currentUser?.uid,
            )
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final requests = snapshot.data?.docs ?? [];

          if (requests.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 64,
                      color: AppColors.textHint.withAlpha(100),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No consultation requests',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Patient consultation requests will appear here',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: AppColors.textHint),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final data = requests[index].data() as Map<String, dynamic>;
              final patientName = data['patientName'] ?? 'Unknown';
              final reason = data['reason'] ?? '';
              final status = data['status'] ?? 'pending';
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

              Color statusColor;
              String statusText;
              switch (status) {
                case 'accepted':
                  statusColor = const Color(0xFF22C55E);
                  statusText = 'Accepted';
                  break;
                case 'rejected':
                  statusColor = Colors.red;
                  statusText = 'Rejected';
                  break;
                default:
                  statusColor = const Color(0xFFF97316);
                  statusText = 'Pending';
              }

              return Container(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.primary.withAlpha(25),
                          child: Text(
                            patientName[0].toUpperCase(),
                            style: const TextStyle(
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
                                patientName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                createdAt != null
                                    ? '${createdAt.day}/${createdAt.month}/${createdAt.year}'
                                    : '',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textHint,
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
                            color: statusColor.withAlpha(20),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (reason.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        reason,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (status == 'pending') ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                await FirebaseFirestore.instance
                                    .collection('consultation_requests')
                                    .doc(requests[index].id)
                                    .update({'status': 'rejected'});
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text('Decline'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                await FirebaseFirestore.instance
                                    .collection('consultation_requests')
                                    .doc(requests[index].id)
                                    .update({'status': 'accepted'});
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text('Accept'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
