import 'package:flutter/material.dart';
import '../../models/smart_alert.dart';
import '../../services/alert_service.dart';
import 'risk_explanation_screen.dart';

/// Alert History Screen
/// Shows notifications in tabs: Smart Insole and Consultation Booking
/// With Read All and Clear All functionality
class AlertHistoryScreen extends StatefulWidget {
  const AlertHistoryScreen({Key? key}) : super(key: key);

  @override
  State<AlertHistoryScreen> createState() => _AlertHistoryScreenState();
}

class _AlertHistoryScreenState extends State<AlertHistoryScreen>
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

  List<SmartAlert> get _healthAlerts {
    return AlertService().alerts
        .where((a) => a.notificationType == NotificationType.health)
        .toList();
  }

  List<SmartAlert> get _appointmentAlerts {
    return AlertService().alerts
        .where((a) => a.notificationType == NotificationType.appointment)
        .toList();
  }

  List<SmartAlert> get _currentTabAlerts {
    return _tabController.index == 0 ? _healthAlerts : _appointmentAlerts;
  }

  int get _currentTabUnreadCount {
    return _currentTabAlerts.where((a) => !a.isViewed).length;
  }

  int get _healthUnreadCount => _healthAlerts.where((a) => !a.isViewed).length;

  int get _appointmentUnreadCount =>
      _appointmentAlerts.where((a) => !a.isViewed).length;

  void _readAllCurrentTab() {
    final alerts = _currentTabAlerts;
    for (final alert in alerts) {
      if (!alert.isViewed) {
        AlertService().markAsViewed(alert.id);
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _tabController.index == 0
              ? 'All insole alerts marked as read'
              : 'All booking alerts marked as read',
        ),
        backgroundColor: const Color(0xFF64ADB3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _clearAllCurrentTab() {
    final alerts = _currentTabAlerts;
    if (alerts.isEmpty) return;

    final tabName = _tabController.index == 0
        ? 'Smart Insole'
        : 'Consultation Booking';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Clear All Notifications',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          'Are you sure you want to clear all $tabName notifications? This cannot be undone.',
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
              _performClear(alerts);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$tabName notifications cleared'),
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

  void _performClear(List<SmartAlert> alerts) {
    // Copy IDs first since the list will change during removal
    final ids = alerts.map((a) => a.id).toList();
    for (final id in ids) {
      AlertService().removeAlert(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAlertList(
                  alerts: _healthAlerts,
                  accentColor: const Color(0xFFF57C00),
                  emptyIcon: Icons.sensors_off_outlined,
                  emptyTitle: 'No Insole Alerts',
                  emptySubtitle:
                      'Your smart insole alerts will appear here\nwhen something needs attention.',
                ),
                _buildAlertList(
                  alerts: _appointmentAlerts,
                  accentColor: const Color(0xFF5C6BC0),
                  emptyIcon: Icons.calendar_today_outlined,
                  emptyTitle: 'No Booking Notifications',
                  emptySubtitle:
                      'Your consultation booking updates\nwill appear here.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final hasAlerts = _currentTabAlerts.isNotEmpty;
    final hasUnread = _currentTabUnreadCount > 0;

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1A1A2E)),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Notifications',
        style: TextStyle(
          color: Color(0xFF64ADB3),
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      actions: [
        if (hasAlerts)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFF1A1A2E)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              if (value == 'read_all') {
                _readAllCurrentTab();
              } else if (value == 'clear_all') {
                _clearAllCurrentTab();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'read_all',
                enabled: hasUnread,
                child: Row(
                  children: [
                    Icon(
                      Icons.done_all_rounded,
                      size: 20,
                      color: hasUnread
                          ? const Color(0xFF64ADB3)
                          : const Color(0xFFD1D5DB),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Read All',
                      style: TextStyle(
                        color: hasUnread
                            ? const Color(0xFF1A1A2E)
                            : const Color(0xFFD1D5DB),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'clear_all',
                child: Row(
                  children: [
                    const Icon(
                      Icons.delete_sweep_outlined,
                      size: 20,
                      color: Color(0xFFE57373),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Clear All',
                      style: TextStyle(
                        color: Color(0xFFE57373),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF1A1A2E),
        unselectedLabelColor: const Color(0xFF9CA3AF),
        indicatorColor: const Color(0xFF64ADB3),
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Smart Insole'),
                if (_healthUnreadCount > 0) ...[
                  const SizedBox(width: 6),
                  _buildBadge(_healthUnreadCount, const Color(0xFFF57C00)),
                ],
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Bookings'),
                if (_appointmentUnreadCount > 0) ...[
                  const SizedBox(width: 6),
                  _buildBadge(_appointmentUnreadCount, const Color(0xFF5C6BC0)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildAlertList({
    required List<SmartAlert> alerts,
    required Color accentColor,
    required IconData emptyIcon,
    required String emptyTitle,
    required String emptySubtitle,
  }) {
    if (alerts.isEmpty) {
      return _buildEmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        subtitle: emptySubtitle,
        color: accentColor,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: alerts.length,
      itemBuilder: (context, index) {
        return _buildAlertCard(alerts[index], accentColor);
      },
    );
  }

  Widget _buildAlertCard(SmartAlert alert, Color accentColor) {
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
          // Mark as viewed when tapped
          if (!alert.isViewed) {
            AlertService().markAsViewed(alert.id);
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RiskExplanationScreen(alert: alert),
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
                  : accentColor.withOpacity(0.4),
              width: alert.isViewed ? 1 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Color accent bar on the left
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                  ),
                ),
                // Main content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            alert.category.icon,
                            color: accentColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title row
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
                                            : const Color(0xFF1A1A2E),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // Unread indicator
                                  if (!alert.isViewed)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.only(left: 8),
                                      decoration: BoxDecoration(
                                        color: accentColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // Description
                              Text(
                                alert.shortDescription,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              // Timestamp and View
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

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 50, color: color),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}
