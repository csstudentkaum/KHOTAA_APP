import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/alert_service.dart';
import '../../features/patient/alert_history_screen.dart';

/// Notification Bell Widget
/// Displays a bell icon with unread count badge and animation
/// Can be placed on any screen for consistent notification access
class NotificationBellWidget extends StatefulWidget {
  final Color? iconColor;
  final Color? badgeColor;
  final double? size;
  final VoidCallback? onTap;

  const NotificationBellWidget({
    Key? key,
    this.iconColor,
    this.badgeColor,
    this.size,
    this.onTap,
  }) : super(key: key);

  @override
  State<NotificationBellWidget> createState() => _NotificationBellWidgetState();
}

class _NotificationBellWidgetState extends State<NotificationBellWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  StreamSubscription? _bellSubscription;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    
    // Setup shake animation
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.1), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.1, end: -0.1), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.1, end: 0.1), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.1, end: -0.1), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.1, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeInOut,
    ));

    // Listen for new alerts
    _bellSubscription = AlertService().onBellAnimation.listen((_) {
      _triggerShake();
    });

    // Listen for changes in alert service
    AlertService().addListener(_updateUnreadCount);
    _updateUnreadCount();
  }

  void _updateUnreadCount() {
    if (mounted) {
      final newCount = AlertService().unreadCount;
      debugPrint('NotificationBell: Updating unread count to $newCount');
      setState(() {
        _unreadCount = newCount;
      });
    }
  }

  void _triggerShake() {
    _shakeController.forward(from: 0.0);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _bellSubscription?.cancel();
    AlertService().removeListener(_updateUnreadCount);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.iconColor ?? const Color(0xFF6B7280);
    final badgeColor = widget.badgeColor ?? const Color(0xFFE53935);
    final size = widget.size ?? 24.0;

    return GestureDetector(
      onTap: widget.onTap ?? () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AlertHistoryScreen(),
          ),
        );
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        ),
        child: AnimatedBuilder(
          animation: _shakeController,
          builder: (context, child) {
            return Transform.rotate(
              angle: _shakeAnimation.value,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    _unreadCount > 0
                        ? Icons.notifications_active
                        : Icons.notifications_outlined,
                    color: iconColor,
                    size: size,
                  ),
                  if (_unreadCount > 0)
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
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: badgeColor.withOpacity(0.4),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _unreadCount > 99 ? '99+' : _unreadCount.toString(),
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
    );
  }
}

/// Notification Bell for AppBar
/// A simpler version optimized for AppBar placement
class AppBarNotificationBell extends StatefulWidget {
  final VoidCallback? onTap;

  const AppBarNotificationBell({
    Key? key,
    this.onTap,
  }) : super(key: key);

  @override
  State<AppBarNotificationBell> createState() => _AppBarNotificationBellState();
}

class _AppBarNotificationBellState extends State<AppBarNotificationBell>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  StreamSubscription? _bellSubscription;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    
    // Setup pulse animation for badge
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // Listen for new alerts
    _bellSubscription = AlertService().onBellAnimation.listen((_) {
      _triggerPulse();
    });

    // Listen for changes
    AlertService().addListener(_updateUnreadCount);
    _updateUnreadCount();
  }

  void _updateUnreadCount() {
    if (mounted) {
      setState(() {
        _unreadCount = AlertService().unreadCount;
      });
      if (_unreadCount > 0) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  void _triggerPulse() {
    if (!_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }
    // Stop after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _unreadCount == 0) {
        _pulseController.stop();
        _pulseController.reset();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _bellSubscription?.cancel();
    AlertService().removeListener(_updateUnreadCount);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: widget.onTap ?? () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AlertHistoryScreen(),
          ),
        );
      },
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            _unreadCount > 0
                ? Icons.notifications_active
                : Icons.notifications_outlined,
            color: Colors.white,
            size: 26,
          ),
          if (_unreadCount > 0)
            Positioned(
              top: -4,
              right: -4,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
