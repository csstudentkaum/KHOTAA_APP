import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app/app_theme.dart';
import '../models/smart_alert.dart';
import '../services/alert_service.dart';
import '../services/notification_service.dart';
import '../features/patient/risk_explanation_screen.dart';

/// Booking-related notification types
const _bookingTypes = {
  'new_booking',
  'booking_confirmed',
  'booking_accepted',
  'booking_rejected',
  'booking_completed',
  'booking_cancelled',
  'follow_up_started',
  'follow_up_completed',
};

/// Notifications screen — two tabs: Smart Insole (AlertService) & Bookings (Firestore)
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    AlertService().addListener(_onAlertsChanged);
  }

  void _onAlertsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    AlertService().removeListener(_onAlertsChanged);
    super.dispose();
  }

  // AlertService data for Smart Insole tab
  List<SmartAlert> get _healthAlerts {
    return AlertService().alerts
        .where((a) => a.notificationType == NotificationType.health)
        .toList();
  }

  int get _healthUnreadCount => _healthAlerts.where((a) => !a.isViewed).length;

  void _readAllInsoleAlerts() {
    for (final alert in _healthAlerts) {
      if (!alert.isViewed) {
        AlertService().markAsViewed(alert.id);
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('All insole alerts marked as read'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _clearAllInsoleAlerts() {
    if (_healthAlerts.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Clear All Notifications',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: const Text(
          'Are you sure you want to clear all Smart Insole notifications? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final ids = _healthAlerts.map((a) => a.id).toList();
              for (final id in ids) {
                AlertService().removeAlert(id);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Smart Insole notifications cleared'),
                  backgroundColor: const Color(0xFFE57373),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text(
              'Clear All',
              style: TextStyle(
                color: Color(0xFFE57373),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _clearAllBookingNotifications(String userId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.delete_outline, size: 48, color: Colors.red),
        title: const Text(
          'Clear All Notifications',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: const Text(
          'This will permanently delete all your booking notifications. This action cannot be undone.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await NotificationService().clearAllNotifications(userId);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Booking notifications cleared'),
                          backgroundColor: const Color(0xFFE57373),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
  }

  void _handleMenuAction(String value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (_tabController.index == 0) {
      if (value == 'read_all') {
        _readAllInsoleAlerts();
      } else if (value == 'clear_all') {
        _clearAllInsoleAlerts();
      }
    } else {
      if (user == null) return;
      if (value == 'read_all') {
        await NotificationService().markAllAsRead(user.uid);
      } else if (value == 'clear_all') {
        _clearAllBookingNotifications(user.uid);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final insoleHasAlerts = _healthAlerts.isNotEmpty;
    final insoleHasUnread = _healthUnreadCount > 0;

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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: _handleMenuAction,
            itemBuilder: (_) {
              if (_tabController.index == 0) {
                return [
                  PopupMenuItem<String>(
                    value: 'read_all',
                    enabled: insoleHasUnread,
                    child: Row(
                      children: [
                        Icon(
                          Icons.done_all_rounded,
                          size: 20,
                          color: insoleHasUnread
                              ? AppColors.primary
                              : const Color(0xFFD1D5DB),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Read All',
                          style: TextStyle(
                            color: insoleHasUnread
                                ? AppColors.textPrimary
                                : const Color(0xFFD1D5DB),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (insoleHasAlerts)
                    const PopupMenuItem<String>(
                      value: 'clear_all',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_sweep_outlined,
                            size: 20,
                            color: Color(0xFFE57373),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Clear All',
                            style: TextStyle(
                              color: Color(0xFFE57373),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ];
              } else {
                return [
                  const PopupMenuItem<String>(
                    value: 'read_all',
                    child: Row(
                      children: [
                        Icon(
                          Icons.done_all_rounded,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Mark all as read',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'clear_all',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_sweep_outlined,
                          size: 20,
                          color: Color(0xFFE57373),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Clear All',
                          style: TextStyle(
                            color: Color(0xFFE57373),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ];
              }
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textHint,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Smart Insole'),
                    if (_healthUnreadCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF57C00),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$_healthUnreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Tab(text: 'Bookings'),
            ],
          ),
        ),
      ),
      body: user == null
          ? const Center(child: Text('Please sign in'))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildInsoleTab(),
                _BookingsTab(userID: user.uid),
              ],
            ),
    );
  }

  // Smart Insole Tab — from AlertService
  Widget _buildInsoleTab() {
    final alerts = _healthAlerts;

    if (alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sensors_off_outlined,
              size: 64,
              color: AppColors.textHint.withAlpha(100),
            ),
            const SizedBox(height: 16),
            const Text(
              'No alerts yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Smart insole alerts and sensor\nnotifications will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textHint),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: alerts.length,
      itemBuilder: (context, index) {
        return _buildInsoleAlertCard(alerts[index]);
      },
    );
  }

  Widget _buildInsoleAlertCard(SmartAlert alert) {
    const accentColor = Color(0xFFF57C00);

    return Dismissible(
      key: Key(alert.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFE57373),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
      ),
      onDismissed: (_) {
        AlertService().removeAlert(alert.id);
      },
      child: GestureDetector(
        onTap: () {
          if (!alert.isViewed) {
            AlertService().markAsViewed(alert.id);
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RiskExplanationScreen(alert: alert),
            ),
          ).then((_) => setState(() {}));
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: alert.isViewed
                  ? const Color(0xFFE5E7EB)
                  : accentColor.withAlpha(100),
              width: alert.isViewed ? 1 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 4,
                  decoration: const BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: accentColor.withAlpha(25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            alert.category.icon,
                            color: accentColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      alert.title,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: alert.isViewed
                                            ? const Color(0xFF4B5563)
                                            : AppColors.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (!alert.isViewed)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.only(left: 8),
                                      decoration: const BoxDecoration(
                                        color: accentColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                alert.shortDescription,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 14,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        alert.formattedTime,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        'View',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right,
                                        size: 16,
                                        color: Colors.grey[400],
                                      ),
                                    ],
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Bookings Tab — Firestore notifications
class _BookingsTab extends StatelessWidget {
  final String userID;

  const _BookingsTab({required this.userID});

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

        final allDocs = snapshot.data?.docs ?? [];
        final filtered = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final type = data['type'] ?? '';
          return _bookingTypes.contains(type);
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 64,
                  color: AppColors.textHint.withAlpha(100),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No booking notifications',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Booking confirmations, follow-ups\nand updates will appear here',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.textHint),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final data = filtered[index].data() as Map<String, dynamic>;
            return _BookingNotificationCard(data: data);
          },
        );
      },
    );
  }
}

class _BookingNotificationCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _BookingNotificationCard({required this.data});

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
      case 'new_booking':
        return (Icons.calendar_today, AppColors.primary, AppColors.primary);
      case 'booking_confirmed':
        return (
          Icons.check_circle_outline,
          const Color(0xFF22C55E),
          const Color(0xFF22C55E),
        );
      case 'booking_accepted':
        return (
          Icons.check_circle_outline,
          const Color(0xFF22C55E),
          const Color(0xFF22C55E),
        );
      case 'booking_rejected':
        return (
          Icons.cancel_outlined,
          const Color(0xFFEF4444),
          const Color(0xFFEF4444),
        );
      case 'booking_completed':
        return (Icons.task_alt, AppColors.primary, AppColors.primary);
      case 'booking_cancelled':
        return (
          Icons.event_busy,
          const Color(0xFFEF4444),
          const Color(0xFFEF4444),
        );
      case 'follow_up_started':
        return (
          Icons.assignment_turned_in_outlined,
          AppColors.primary,
          AppColors.primary,
        );
      case 'follow_up_completed':
        return (Icons.verified_outlined, AppColors.primary, AppColors.primary);
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
