import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../app/app_theme.dart';
import '../../services/notification_service.dart';

/// Doctor notifications screen — two tabs: Bookings & Patient Alerts
class DoctorNotificationsScreen extends StatefulWidget {
  const DoctorNotificationsScreen({super.key});

  @override
  State<DoctorNotificationsScreen> createState() =>
      _DoctorNotificationsScreenState();
}

class _DoctorNotificationsScreenState extends State<DoctorNotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _notificationService = NotificationService();

  // Booking notification types
  static const _bookingTypes = [
    'new_booking',
    'booking_accepted',
    'booking_rejected',
    'booking_completed',
    'booking_cancelled',
    'booking_confirmed',
    'follow_up_started',
    'follow_up_completed',
  ];

  // Risk alert notification types
  static const _alertTypes = [
    'high_pressure',
    'elevated_pressure',
    'abnormal_temperature',
    'elevated_temperature',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

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
          'Notifications',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
        actions: [
          if (user != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
              onSelected: (value) async {
                if (value == 'read_all') {
                  await _notificationService.markAllAsRead(user.uid);
                } else if (value == 'clear_all') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      title: const Text('Clear All Notifications'),
                      content: const Text(
                        'This will permanently delete all your notifications. This action cannot be undone.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      actions: [
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                child: const Text(
                                  'Clear All',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await _notificationService.clearAllNotifications(user.uid);
                  }
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'read_all',
                  child: Row(
                    children: [
                      Icon(Icons.done_all, size: 20, color: AppColors.primary),
                      SizedBox(width: 10),
                      Text('Mark all as read'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      SizedBox(width: 10),
                      Text('Clear all', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textHint,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          tabs: const [
            Tab(child: Text('Bookings')),
            Tab(child: Text('Patient Alerts')),
          ],
        ),
      ),
      body: user == null
          ? const Center(child: Text('Please sign in'))
          : TabBarView(
              controller: _tabController,
              children: [
                _BookingsTab(
                  userID: user.uid,
                  filterTypes: _bookingTypes,
                  emptyIcon: Icons.calendar_today_outlined,
                  emptyTitle: 'No booking notifications',
                  emptySubtitle:
                      'Booking updates will appear here\nwhen patients book consultations',
                ),
                _BookingsTab(
                  userID: user.uid,
                  filterTypes: _alertTypes,
                  emptyIcon: Icons.monitor_heart_outlined,
                  emptyTitle: 'No patient alerts',
                  emptySubtitle:
                      'Risk alerts from patient DFU\nreadings will appear here',
                ),
              ],
            ),
    );
  }
}

// ─── Unified notification list ───────────────────────────────────────

class _BookingsTab extends StatelessWidget {
  final String userID;
  final List<String> filterTypes;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;

  const _BookingsTab({
    required this.userID,
    required this.filterTypes,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: NotificationService().streamNotifications(userID),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading notifications'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final docs = (snapshot.data?.docs ?? []).where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return filterTypes.contains(data['type']);
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  emptyIcon,
                  size: 64,
                  color: AppColors.textHint.withAlpha(100),
                ),
                const SizedBox(height: 16),
                Text(
                  emptyTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  emptySubtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return _NotificationCard(data: data);
          },
        );
      },
    );
  }
}

// ─── Notification card (matches patient design) ──────────────────────

class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _NotificationCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final title = data['title'] ?? '';
    final body = data['body'] ?? '';
    final type = data['type'] ?? '';
    final isRead = data['isRead'] ?? false;
    final notificationID = data['notificationID'] ?? '';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

    final (icon, iconColor, accentColor) = _styleFor(type);

    return GestureDetector(
      onTap: () {
        if (!isRead) {
          NotificationService().markAsRead(notificationID);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.inputBorder.withAlpha(80)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      body,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (createdAt != null) ...[
                          const Icon(
                            Icons.access_time,
                            size: 12,
                            color: AppColors.textHint,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTime(createdAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                        const Spacer(),
                        const Text(
                          'View >',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  (IconData, Color, Color) _styleFor(String type) {
    switch (type) {
      // Booking types
      case 'new_booking':
        return (
          Icons.calendar_month_rounded,
          AppColors.primary,
          AppColors.primary,
        );
      case 'booking_accepted':
        return (
          Icons.calendar_month_rounded,
          const Color(0xFF22C55E),
          const Color(0xFF22C55E),
        );
      case 'booking_rejected':
        return (
          Icons.calendar_month_rounded,
          const Color(0xFFEF4444),
          const Color(0xFFEF4444),
        );
      case 'booking_completed':
        return (
          Icons.calendar_month_rounded,
          AppColors.primary,
          AppColors.primary,
        );
      case 'booking_cancelled':
        return (
          Icons.calendar_month_rounded,
          const Color(0xFFEF4444),
          const Color(0xFFEF4444),
        );
      case 'booking_confirmed':
        return (
          Icons.calendar_month_rounded,
          const Color(0xFF22C55E),
          const Color(0xFF22C55E),
        );
      case 'follow_up_started':
        return (
          Icons.calendar_month_rounded,
          AppColors.primary,
          AppColors.primary,
        );
      case 'follow_up_completed':
        return (
          Icons.calendar_month_rounded,
          AppColors.primary,
          AppColors.primary,
        );
      // Alert types
      case 'high_pressure':
        return (
          Icons.warning_amber_rounded,
          const Color(0xFFEF4444),
          const Color(0xFFEF4444),
        );
      case 'elevated_pressure':
        return (Icons.speed, const Color(0xFFF59E0B), const Color(0xFFF59E0B));
      case 'abnormal_temperature':
        return (
          Icons.thermostat,
          const Color(0xFFEF4444),
          const Color(0xFFEF4444),
        );
      case 'elevated_temperature':
        return (
          Icons.thermostat_outlined,
          const Color(0xFFF59E0B),
          const Color(0xFFF59E0B),
        );
      default:
        return (
          Icons.notifications_outlined,
          AppColors.primary,
          AppColors.primary,
        );
    }
  }

  static String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
