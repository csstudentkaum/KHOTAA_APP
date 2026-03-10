import 'package:flutter/material.dart';
import '../../services/alert_service.dart';
import '../../models/smart_alert.dart' as alert_model;

/// Preventive Recommendations Screen
/// Displays alerts from smart insole with personalized recommendations
class PreventiveRecommendationsScreen extends StatefulWidget {
  const PreventiveRecommendationsScreen({Key? key}) : super(key: key);

  @override
  State<PreventiveRecommendationsScreen> createState() =>
      _PreventiveRecommendationsScreenState();
}

class _PreventiveRecommendationsScreenState
    extends State<PreventiveRecommendationsScreen>
    with TickerProviderStateMixin {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Unread'];  // Simplified filters

  // Recommendations synced directly from Smart Insole health alerts
  List<RecommendationItem> _recommendations = [];

  List<AnimationController> _pulseControllers = [];

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
    // Listen for alert service changes
    AlertService().addListener(_onAlertServiceChanged);
  }

  void _onAlertServiceChanged() {
    // Defer to avoid calling setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadRecommendations();
    });
  }

  void _loadRecommendations() {
    // Get ONLY health alerts from Smart Insole (synced with Notification History)
    final healthAlerts = AlertService()
        .alerts
        .where((a) => a.notificationType == alert_model.NotificationType.health)
        .take(5) // Same limit as Smart Insole notifications
        .toList();

    // Convert health alerts to recommendations
    _recommendations = healthAlerts.map(_alertToRecommendation).toList();

    // Sort by date (newest first)
    _recommendations.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    // Reinitialize animations
    _disposePulseControllers();
    _initializePulseAnimations();

    if (mounted) setState(() {});
  }

  RecommendationItem _alertToRecommendation(alert_model.SmartAlert alert) {
    return RecommendationItem(
      id: alert.id,
      type: _categoryToType(alert.category),
      title: alert.recommendationTitle ?? alert.title,
      description: alert.recommendationDescription ?? alert.shortDescription,
      dateTime: alert.timestamp,
      icon: _getCategoryIcon(alert.category),
      isCompleted: alert.isResolved,
      instructions: alert.instructions ?? _getDefaultInstructions(alert.category),
    );
  }

  RecommendationType _categoryToType(alert_model.RiskCategory category) {
    switch (category) {
      case alert_model.RiskCategory.pressure:
        return RecommendationType.pressure;
      case alert_model.RiskCategory.temperature:
        return RecommendationType.temperature;
      case alert_model.RiskCategory.movement:
      case alert_model.RiskCategory.general:
        // Map movement/general to pressure as fallback (since we only have 2 types now)
        return RecommendationType.pressure;
    }
  }

  IconData _getCategoryIcon(alert_model.RiskCategory category) {
    switch (category) {
      case alert_model.RiskCategory.pressure:
        return Icons.compress;
      case alert_model.RiskCategory.temperature:
        return Icons.thermostat;
      case alert_model.RiskCategory.movement:
      case alert_model.RiskCategory.general:
        return Icons.health_and_safety;
    }
  }

  String _getDefaultInstructions(alert_model.RiskCategory category) {
    switch (category) {
      case alert_model.RiskCategory.pressure:
        return 'Reduce standing time and rest your feet. Consider changing to more supportive footwear with proper cushioning.';
      case alert_model.RiskCategory.temperature:
        return 'Apply a cool compress to the affected area for 10-15 minutes. Monitor for any signs of inflammation.';
      case alert_model.RiskCategory.movement:
      case alert_model.RiskCategory.general:
        return 'Follow general foot care guidelines and consult your healthcare provider if symptoms persist.';
    }
  }

  void _disposePulseControllers() {
    for (var controller in _pulseControllers) {
      controller.dispose();
    }
    _pulseControllers = [];
  }

  void _initializePulseAnimations() {
    _pulseControllers = List.generate(
      _recommendations.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 1500),
        vsync: this,
      ),
    );

    // Start pulse animation for incomplete items
    for (int i = 0; i < _recommendations.length; i++) {
      if (!_recommendations[i].isCompleted) {
        _pulseControllers[i].repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    AlertService().removeListener(_onAlertServiceChanged);
    _disposePulseControllers();
    super.dispose();
  }

  List<RecommendationItem> get _filteredRecommendations {
    if (_selectedFilter == 'All') {
      return _recommendations;
    }
    return _recommendations.where((item) {
      switch (_selectedFilter) {
        case 'Unread':
          return !item.isCompleted;
        default:
          return true;
      }
    }).toList();
  }

  int get _pendingCount =>
      _recommendations.where((item) => !item.isCompleted).length;
  int get _completedCount =>
      _recommendations.where((item) => item.isCompleted).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildProgressSummary(),
          _buildFilterChips(),
          Expanded(
            child: _buildRecommendationsList(),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2E)),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preventive Recommendations',
            style: TextStyle(
              color: Color(0xFF1A1A2E),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            'All Alerts',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline, color: Color(0xFF6B7280)),
          onPressed: _showInfoDialog,
        ),
      ],
    );
  }

  Widget _buildProgressSummary() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A9D8F), Color(0xFF3DB4A6)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2A9D8F).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Progress',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_pendingCount pending, $_completedCount completed',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  value: _recommendations.isEmpty
                      ? 0
                      : _completedCount / _recommendations.length,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 6,
                ),
              ),
              Text(
                '${((_completedCount / _recommendations.length) * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final unreadCount = _recommendations.where((item) => !item.isCompleted).length;
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter;
          final displayText = filter == 'Unread' ? 'Unread ($unreadCount)' : filter;
          return FilterChip(
            label: Text(
              displayText,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
            selected: isSelected,
            onSelected: (selected) {
              setState(() => _selectedFilter = filter);
            },
            backgroundColor: Colors.white,
            selectedColor: _getFilterColor(filter),
            checkmarkColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected
                    ? Colors.transparent
                    : const Color(0xFFE5E7EB),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getFilterColor(String filter) {
    switch (filter) {
      case 'Unread':
        return const Color(0xFF5C6BC0);
      default:
        return const Color(0xFF2A9D8F);
    }
  }

  Widget _buildRecommendationsList() {
    final items = _filteredRecommendations;

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No recommendations in this category',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final originalIndex = _recommendations.indexOf(item);
        return _RecommendationCard(
          item: item,
          pulseController: _pulseControllers[originalIndex],
          onMarkComplete: () => _toggleComplete(originalIndex),
          onTap: () {
            // Show detail dialog for all recommendations
            _showDetailDialog(item);
          },
        );
      },
    );
  }

  void _toggleComplete(int index) {
    setState(() {
      _recommendations[index] = _recommendations[index].copyWith(
        isCompleted: !_recommendations[index].isCompleted,
      );

      if (_recommendations[index].isCompleted) {
        _pulseControllers[index].stop();
        _pulseControllers[index].reset();
      } else {
        _pulseControllers[index].repeat(reverse: true);
      }
    });
  }

  void _showDetailDialog(RecommendationItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DetailBottomSheet(item: item),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF2A9D8F)),
            SizedBox(width: 12),
            Text('About Recommendations'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(
              color: Color(0xFF5C6BC0),
              label: 'Pressure',
              description: 'High plantar pressure detected (>200 kPa)',
            ),
            SizedBox(height: 12),
            _InfoRow(
              color: Color(0xFFEF5350),
              label: 'Temperature',
              description: 'Temperature difference detected (>2.2°C)',
            ),
            SizedBox(height: 16),
            Text(
              'Synced with Smart Insole notifications',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final Color color;
  final String label;
  final String description;

  const _InfoRow({
    required this.color,
    required this.label,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Recommendation Card Widget
class _RecommendationCard extends StatelessWidget {
  final RecommendationItem item;
  final AnimationController pulseController;
  final VoidCallback onMarkComplete;
  final VoidCallback onTap;

  const _RecommendationCard({
    required this.item,
    required this.pulseController,
    required this.onMarkComplete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: item.isCompleted ? Colors.grey[100] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: item.isCompleted
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
          border: Border.all(
            color: item.isCompleted
                ? Colors.grey[300]!
                : _getTypeColor(item.type).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon & Urgency Indicator
            _buildIconSection(),
            const SizedBox(width: 16),
            // Content
            Expanded(child: _buildContentSection()),
            // Complete Button
            _buildCompleteButton(),
          ],
        ),
      ),
    );

    // Add subtle animation for incomplete items
    if (!item.isCompleted) {
      return AnimatedBuilder(
        animation: pulseController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _getTypeColor(item.type)
                      .withOpacity(0.1 * pulseController.value),
                  blurRadius: 10 * pulseController.value,
                  spreadRadius: 1 * pulseController.value,
                ),
              ],
            ),
            child: child,
          );
        },
        child: card,
      );
    }

    return card;
  }

  Widget _buildIconSection() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: _getTypeColor(item.type).withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        item.icon,
        color: item.isCompleted
            ? Colors.grey[400]
            : _getTypeColor(item.type),
        size: 28,
      ),
    );
  }

  Widget _buildContentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Type badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getTypeColor(item.type).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            item.type.name.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: item.isCompleted
                  ? Colors.grey[500]
                  : _getTypeColor(item.type),
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Title
        Text(
          item.title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: item.isCompleted
                ? Colors.grey[500]
                : const Color(0xFF1A1A2E),
            decoration:
                item.isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        const SizedBox(height: 4),
        // Description
        Text(
          item.description,
          style: TextStyle(
            fontSize: 14,
            color: item.isCompleted
                ? Colors.grey[400]
                : const Color(0xFF6B7280),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        // Date/Time
        Row(
          children: [
            Icon(
              Icons.access_time,
              size: 14,
              color: Colors.grey[400],
            ),
            const SizedBox(width: 4),
            Text(
              _formatDateTime(item.dateTime),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompleteButton() {
    return GestureDetector(
      onTap: onMarkComplete,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: item.isCompleted
              ? const Color(0xFF66BB6A)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          item.isCompleted ? Icons.check : Icons.check,
          color: item.isCompleted ? Colors.white : Colors.grey[400],
          size: 24,
        ),
      ),
    );
  }

  Color _getTypeColor(RecommendationType type) {
    switch (type) {
      case RecommendationType.pressure:
        return const Color(0xFF5C6BC0);  // Indigo for pressure
      case RecommendationType.temperature:
        return const Color(0xFFFF7043);  // Orange for temperature (matching weekly report)
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${diff.inDays} days ago';
    }
  }
}

/// Detail Bottom Sheet
class _DetailBottomSheet extends StatelessWidget {
  final RecommendationItem item;

  const _DetailBottomSheet({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: _getTypeColor(item.type).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        item.icon,
                        color: _getTypeColor(item.type),
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          _buildUrgencyBadge(),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Instructions
                const Text(
                  'Instructions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item.instructions,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF6B7280),
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2A9D8F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Got it!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrgencyBadge() {
    // Show type category instead of urgency
    String label = item.type.name.toUpperCase();
    Color color = _getTypeColor(item.type);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Color _getTypeColor(RecommendationType type) {
    switch (type) {
      case RecommendationType.pressure:
        return const Color(0xFF5C6BC0);  // Indigo for pressure
      case RecommendationType.temperature:
        return const Color(0xFFFF7043);  // Orange for temperature
    }
  }
}

// Data Models - Only pressure and temperature (matching Smart Insole)
enum RecommendationType { pressure, temperature }

class RecommendationItem {
  final String id;
  final RecommendationType type;
  final String title;
  final String description;
  final DateTime dateTime;
  final IconData icon;
  final bool isCompleted;
  final String instructions;

  const RecommendationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.dateTime,
    required this.icon,
    required this.isCompleted,
    required this.instructions,
  });

  RecommendationItem copyWith({
    String? id,
    RecommendationType? type,
    String? title,
    String? description,
    DateTime? dateTime,
    IconData? icon,
    bool? isCompleted,
    String? instructions,
  }) {
    return RecommendationItem(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      dateTime: dateTime ?? this.dateTime,
      icon: icon ?? this.icon,
      isCompleted: isCompleted ?? this.isCompleted,
      instructions: instructions ?? this.instructions,
    );
  }
}
