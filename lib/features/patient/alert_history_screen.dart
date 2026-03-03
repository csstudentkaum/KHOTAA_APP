import 'package:flutter/material.dart';
import '../../models/smart_alert.dart';
import '../../services/alert_service.dart';
import 'risk_explanation_screen.dart';

/// Alert History Screen
/// Shows all past alerts in a scrollable, chronological list
class AlertHistoryScreen extends StatefulWidget {
  const AlertHistoryScreen({Key? key}) : super(key: key);

  @override
  State<AlertHistoryScreen> createState() => _AlertHistoryScreenState();
}

class _AlertHistoryScreenState extends State<AlertHistoryScreen>
    with SingleTickerProviderStateMixin {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Unread', 'High', 'Medium', 'Low'];
  late AnimationController _listAnimationController;

  @override
  void initState() {
    super.initState();
    _listAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _listAnimationController.forward();

    // Listen for alert changes
    AlertService().addListener(_onAlertsChanged);
  }

  void _onAlertsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _listAnimationController.dispose();
    AlertService().removeListener(_onAlertsChanged);
    super.dispose();
  }

  List<SmartAlert> get _filteredAlerts {
    final alerts = AlertService().alerts;
    switch (_selectedFilter) {
      case 'High':
        return alerts.where((a) => a.riskLevel == RiskLevel.high).toList();
      case 'Medium':
        return alerts.where((a) => a.riskLevel == RiskLevel.medium).toList();
      case 'Low':
        return alerts.where((a) => a.riskLevel == RiskLevel.low).toList();
      case 'Unread':
        return alerts.where((a) => !a.isViewed).toList();
      default:
        return alerts;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: Color(0xFF1A1A2E),
              size: 18,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          if (AlertService().unreadCount > 0)
            TextButton(
              onPressed: () {
                AlertService().markAllAsViewed();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All notifications marked as read'),
                    backgroundColor: Color(0xFF2A9D8F),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text(
                'Mark all read',
                style: TextStyle(
                  color: Color(0xFF2A9D8F),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(
                        filter == 'Unread'
                            ? 'Unread (${AlertService().unreadCount})'
                            : filter,
                        style: TextStyle(
                          color: isSelected 
                              ? Colors.white 
                              : const Color(0xFF6B7280),
                          fontWeight: isSelected 
                              ? FontWeight.w600 
                              : FontWeight.normal,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      },
                      backgroundColor: Colors.white,
                      selectedColor: const Color(0xFF2A9D8F),
                      checkmarkColor: Colors.white,
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFF2A9D8F)
                            : const Color(0xFFE5E7EB),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Alert list
          Expanded(
            child: _filteredAlerts.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredAlerts.length,
                    itemBuilder: (context, index) {
                      return _buildAlertItem(
                        _filteredAlerts[index],
                        index,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF2A9D8F).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_off_outlined,
              size: 50,
              color: Color(0xFF2A9D8F),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Notifications',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'All'
                ? 'You have no alerts yet.\nWe\'ll notify you when something needs attention.'
                : 'No $_selectedFilter risk alerts found.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertItem(SmartAlert alert, int index) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _listAnimationController,
        curve: Interval(
          (index * 0.1).clamp(0.0, 1.0),
          ((index * 0.1) + 0.3).clamp(0.0, 1.0),
          curve: Curves.easeOut,
        ),
      )),
      child: GestureDetector(
        onTap: () {
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
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: alert.isViewed
                  ? const Color(0xFFE5E7EB)
                  : alert.riskLevel.color.withOpacity(0.3),
              width: alert.isViewed ? 1 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Unread indicator
              if (!alert.isViewed)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: alert.riskLevel.color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: alert.riskLevel.color.withOpacity(0.4),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Risk Level Icon
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: alert.riskLevel.backgroundColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        alert.riskLevel.icon,
                        color: alert.riskLevel.color,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Risk Level Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: alert.riskLevel.color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  alert.riskLevel.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: alert.riskLevel.color,
                                  ),
                                ),
                              ),
                              // Timestamp
                              Text(
                                alert.formattedTime,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Title
                          Text(
                            alert.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: alert.isViewed
                                  ? const Color(0xFF4B5563)
                                  : const Color(0xFF1A1A2E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Description
                          Text(
                            alert.shortDescription,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          // Category chip and arrow
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    alert.category.icon,
                                    size: 16,
                                    color: const Color(0xFF2A9D8F),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    alert.category.label,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF2A9D8F),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Text(
                                    'View Details',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    size: 20,
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
            ],
          ),
        ),
      ),
    );
  }
}
