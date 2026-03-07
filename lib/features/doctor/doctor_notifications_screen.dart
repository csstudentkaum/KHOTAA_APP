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
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 22,
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
            Tab(text: 'Bookings'),
            Tab(text: 'Patient Alerts'),
          ],
        ),
      ),
      body: user == null
          ? const Center(child: Text('Please sign in'))
          : TabBarView(
              controller: _tabController,
              children: [
                _NotificationList(
                  userID: user.uid,
                  filterTypes: _bookingTypes,
                  emptyIcon: Icons.calendar_today_outlined,
                  emptyTitle: 'No booking notifications',
                  emptySubtitle:
                      'Booking updates will appear here\nwhen patients book consultations',
                ),
                _NotificationList(
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

// ─── Filtered notification list ──────────────────────────────────────

class _NotificationList extends StatelessWidget {
  final String userID;
  final List<String> filterTypes;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;

  const _NotificationList({
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

        // Filter by type
        final docs = (snapshot.data?.docs ?? []).where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return filterTypes.contains(data['type']);
        }).toList();

        if (docs.isEmpty) {
          return _buildEmptyState();
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(emptyIcon, size: 64, color: AppColors.textHint.withAlpha(100)),
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
            style: const TextStyle(fontSize: 14, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}

// ─── Notification card ───────────────────────────────────────────────

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

    final (icon, iconColor) = _iconFor(type);

    return GestureDetector(
      onTap: () {
        if (!isRead) {
          NotificationService().markAsRead(notificationID);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : AppColors.primary.withAlpha(12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRead
                ? AppColors.inputBorder
                : AppColors.primary.withAlpha(40),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  if (createdAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _formatTime(createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (IconData, Color) _iconFor(String type) {
    switch (type) {
      case 'new_booking':
        return (Icons.calendar_today, AppColors.primary);
      case 'booking_accepted':
        return (Icons.check_circle_outline, const Color(0xFF22C55E));
      case 'booking_rejected':
        return (Icons.cancel_outlined, Colors.red);
      case 'booking_completed':
        return (Icons.task_alt, const Color(0xFF6366F1));
      case 'booking_cancelled':
        return (Icons.event_busy, const Color(0xFFEF4444));
      case 'high_pressure':
        return (Icons.warning_amber_rounded, const Color(0xFFEF4444));
      case 'elevated_pressure':
        return (Icons.speed, const Color(0xFFF59E0B));
      case 'abnormal_temperature':
        return (Icons.thermostat, const Color(0xFFEF4444));
      case 'elevated_temperature':
        return (Icons.thermostat_outlined, const Color(0xFFF59E0B));
      default:
        return (Icons.notifications_outlined, AppColors.primary);
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
