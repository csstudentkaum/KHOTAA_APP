import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app/app_theme.dart';
import '../services/notification_service.dart';

/// Notifications screen — shows all notifications for the current user
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

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
            TextButton(
              onPressed: () async {
                await NotificationService().markAllAsRead(user.uid);
              },
              child: const Text(
                'Read all',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('Please sign in'))
          : StreamBuilder<QuerySnapshot>(
              stream: NotificationService().streamNotifications(user.uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint('❌ Notifications error: ${snapshot.error}');
                  return Center(child: Text('Error loading notifications'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                debugPrint(
                  '📋 Notifications loaded: ${docs.length} for ${user.uid}',
                );

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_off_outlined,
                          size: 64,
                          color: AppColors.textHint.withAlpha(100),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No notifications yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'You\'ll see booking updates and\nrisk alerts here',
                          textAlign: TextAlign.center,
                          style: TextStyle(
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
            ),
    );
  }
}

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

    IconData icon;
    Color iconColor;

    switch (type) {
      case 'new_booking':
        icon = Icons.calendar_today;
        iconColor = AppColors.primary;
        break;
      case 'booking_accepted':
        icon = Icons.check_circle_outline;
        iconColor = const Color(0xFF22C55E);
        break;
      case 'booking_rejected':
        icon = Icons.cancel_outlined;
        iconColor = Colors.red;
        break;
      case 'booking_completed':
        icon = Icons.task_alt;
        iconColor = const Color(0xFF6366F1);
        break;
      case 'high_pressure':
        icon = Icons.warning_amber_rounded;
        iconColor = const Color(0xFFEF4444);
        break;
      case 'elevated_pressure':
        icon = Icons.speed;
        iconColor = const Color(0xFFF59E0B);
        break;
      case 'abnormal_temperature':
        icon = Icons.thermostat;
        iconColor = const Color(0xFFEF4444);
        break;
      case 'elevated_temperature':
        icon = Icons.thermostat_outlined;
        iconColor = const Color(0xFFF59E0B);
        break;
      default:
        icon = Icons.notifications_outlined;
        iconColor = AppColors.primary;
    }

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
