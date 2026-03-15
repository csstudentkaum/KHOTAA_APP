import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app/app_theme.dart';
import '../services/notification_service.dart';
import '../services/local_notification_service.dart';
import 'notifications_screen.dart';

/// Wraps a child widget and listens for new Firestore notifications.
/// When a new notification arrives, it slides a banner popup from the top.
class InAppNotificationListener extends StatefulWidget {
  final Widget child;

  const InAppNotificationListener({super.key, required this.child});

  @override
  State<InAppNotificationListener> createState() =>
      _InAppNotificationListenerState();
}

class _InAppNotificationListenerState extends State<InAppNotificationListener>
    with SingleTickerProviderStateMixin {
  StreamSubscription<QuerySnapshot>? _subscription;
  bool _initialLoadDone = false;

  // Popup state
  OverlayEntry? _overlayEntry;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _subscription = NotificationService().streamNotifications(uid).listen((
      snapshot,
    ) {
      // Skip the initial load — only react to real-time changes
      if (!_initialLoadDone) {
        _initialLoadDone = true;
        return;
      }

      // Look for newly added documents
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>?;
          if (data != null && data['isRead'] == false) {
            _showPopup(data);
            break; // show only one popup at a time
          }
        }
      }
    });
  }

  void _showPopup(Map<String, dynamic> data) {
    // Dismiss any existing popup
    _dismissPopup();

    // Also show a native OS notification
    final title = data['title'] as String? ?? '';
    final body = data['body'] as String? ?? '';
    final type = data['type'] as String? ?? '';
    LocalNotificationService().show(title: title, body: body, type: type);

    final overlay = Overlay.of(context);

    _overlayEntry = OverlayEntry(
      builder: (context) => _NotificationPopup(
        data: data,
        onDismiss: _dismissPopup,
        onTap: () {
          _dismissPopup();
          // Mark as read
          final notifID = data['notificationID'] as String? ?? '';
          if (notifID.isNotEmpty) {
            NotificationService().markAsRead(notifID);
          }
          // Navigate to notifications screen
          Navigator.push(
            this.context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          );
        },
      ),
    );

    overlay.insert(_overlayEntry!);

    // Auto-dismiss after 4 seconds
    _autoDismissTimer = Timer(const Duration(seconds: 4), _dismissPopup);
  }

  void _dismissPopup() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _dismissPopup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ── Animated popup banner ──

class _NotificationPopup extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const _NotificationPopup({
    required this.data,
    required this.onDismiss,
    required this.onTap,
  });

  @override
  State<_NotificationPopup> createState() => _NotificationPopupState();
}

class _NotificationPopupState extends State<_NotificationPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'new_booking':
        return Icons.calendar_today;
      case 'booking_accepted':
        return Icons.check_circle_outline;
      case 'booking_rejected':
        return Icons.cancel_outlined;
      case 'booking_completed':
        return Icons.task_alt;
      case 'booking_confirmed':
        return Icons.check_circle_outline;
      case 'booking_cancelled':
        return Icons.event_busy_outlined;
      case 'follow_up_started':
        return Icons.assignment_turned_in_outlined;
      case 'follow_up_completed':
        return Icons.verified_outlined;
      case 'high_pressure':
        return Icons.warning_amber_rounded;
      case 'elevated_pressure':
        return Icons.speed;
      case 'abnormal_temperature':
        return Icons.thermostat;
      case 'elevated_temperature':
        return Icons.thermostat_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'new_booking':
        return AppColors.primary;
      case 'booking_accepted':
        return const Color(0xFF22C55E);
      case 'booking_rejected':
        return Colors.red;
      case 'booking_completed':
        return const Color(0xFF6366F1);
      case 'booking_confirmed':
        return const Color(0xFF22C55E);
      case 'booking_cancelled':
        return const Color(0xFFEF4444);
      case 'follow_up_started':
        return AppColors.primary;
      case 'follow_up_completed':
        return const Color(0xFF6366F1);
      case 'high_pressure':
      case 'abnormal_temperature':
        return const Color(0xFFEF4444);
      case 'elevated_pressure':
      case 'elevated_temperature':
        return const Color(0xFFF59E0B);
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.data['title'] ?? '';
    final body = widget.data['body'] ?? '';
    final type = widget.data['type'] ?? '';
    final iconColor = _colorForType(type);
    final mediaQuery = MediaQuery.of(context);

    return Positioned(
      top: mediaQuery.padding.top + 8,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onTap: widget.onTap,
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null &&
                  details.primaryVelocity! < -100) {
                widget.onDismiss();
              }
            },
            child: Material(
              elevation: 8,
              shadowColor: Colors.black26,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: iconColor.withAlpha(60), width: 1),
                ),
                child: Row(
                  children: [
                    // Icon
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: iconColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _iconForType(type),
                        color: iconColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            body,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Close button
                    GestureDetector(
                      onTap: widget.onDismiss,
                      child: const Icon(
                        Icons.close,
                        size: 18,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
