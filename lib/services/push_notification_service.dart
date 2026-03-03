import 'dart:async';
import 'package:flutter/material.dart';
import '../models/smart_alert.dart';
import 'alert_service.dart';

/// Push Notification Service
/// Handles local notifications and prepares for Firebase Cloud Messaging integration
/// 
/// Note: For full push notification support, add these packages to pubspec.yaml:
/// - flutter_local_notifications: ^17.0.0
/// - firebase_messaging: ^15.0.0
/// 
/// This service provides the infrastructure for push notifications while
/// using in-app overlay notifications as a fallback.
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  // Global navigator key for showing notifications from anywhere
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // Stream controller for notification taps
  final StreamController<SmartAlert> _notificationTapController =
      StreamController<SmartAlert>.broadcast();
  Stream<SmartAlert> get onNotificationTap => _notificationTapController.stream;

  // Current overlay entry
  OverlayEntry? _currentOverlay;
  Timer? _dismissTimer;

  /// Initialize the notification service
  Future<void> initialize() async {
    // Listen for new alerts and show notifications
    AlertService().onNewAlert.listen(_handleNewAlert);
  }

  /// Handle a new alert by showing a notification
  void _handleNewAlert(SmartAlert alert) {
    // Show in-app notification overlay
    _showInAppNotification(alert);
  }

  /// Show an in-app notification overlay
  void _showInAppNotification(SmartAlert alert) {
    // Dismiss any existing notification
    _dismissCurrentNotification();

    final context = navigatorKey.currentContext;
    if (context == null) return;

    final overlay = Overlay.of(context);

    _currentOverlay = OverlayEntry(
      builder: (context) => _InAppNotification(
        alert: alert,
        onTap: () {
          _dismissCurrentNotification();
          _notificationTapController.add(alert);
        },
        onDismiss: _dismissCurrentNotification,
      ),
    );

    overlay.insert(_currentOverlay!);

    // Auto-dismiss after 5 seconds
    _dismissTimer = Timer(const Duration(seconds: 5), () {
      _dismissCurrentNotification();
    });
  }

  /// Dismiss the current notification
  void _dismissCurrentNotification() {
    _dismissTimer?.cancel();
    _currentOverlay?.remove();
    _currentOverlay = null;
  }

  /// Show a custom notification
  void showNotification({
    required String title,
    required String body,
    required RiskLevel riskLevel,
    SmartAlert? alert,
  }) {
    if (alert != null) {
      _showInAppNotification(alert);
    }
  }

  /// Trigger a test notification (for demo purposes)
  Future<void> triggerTestNotification() async {
    final alert = await AlertService().triggerAlert(
      pressureValue: 270.0,
      temperatureValue: 38.5,
      footSide: 'Left',
      sensorRegion: 'Heel',
    );
    _showInAppNotification(alert);
  }

  void dispose() {
    _dismissCurrentNotification();
    _notificationTapController.close();
  }
}

/// In-App Notification Widget
/// Slides down from the top of the screen
class _InAppNotification extends StatefulWidget {
  final SmartAlert alert;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _InAppNotification({
    required this.alert,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_InAppNotification> createState() => _InAppNotificationState();
}

class _InAppNotificationState extends State<_InAppNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ),
    );

    _controller.forward();
  }

  void _dismiss() {
    _controller.reverse().then((_) {
      widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: widget.onTap,
              onVerticalDragEnd: (details) {
                if (details.velocity.pixelsPerSecond.dy < -100) {
                  _dismiss();
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border(
                    left: BorderSide(
                      color: widget.alert.riskLevel.color,
                      width: 4,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Risk Level Icon
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: widget.alert.riskLevel.backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.alert.riskLevel.icon,
                        color: widget.alert.riskLevel.color,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Risk Level Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: widget.alert.riskLevel.color,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${widget.alert.riskLevel.label} Risk',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              // Timestamp
                              Text(
                                widget.alert.formattedTime,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Title
                          Text(
                            widget.alert.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A2E),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          // Description
                          Text(
                            widget.alert.shortDescription,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Arrow
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey[400],
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

/// Notification Navigation Handler
/// Mixin to add to screens that need to handle notification navigation
mixin NotificationNavigationHandler<T extends StatefulWidget> on State<T> {
  StreamSubscription? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _setupNotificationListener();
  }

  void _setupNotificationListener() {
    _notificationSubscription = PushNotificationService()
        .onNotificationTap
        .listen(_handleNotificationTap);
  }

  void _handleNotificationTap(SmartAlert alert);

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }
}
