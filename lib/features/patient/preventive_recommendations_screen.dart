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
  final List<String> _filters = ['All', 'Unread', 'High', 'Medium', 'Low'];

  // Combined recommendations from sample data and AlertService
  List<RecommendationItem> _recommendations = [];

  // Sample data - Always available as base recommendations
  static final List<RecommendationItem> _sampleRecommendations = [
    RecommendationItem(
      id: '1',
      type: RecommendationType.pressure,
      title: 'Reduce Standing Time',
      description: 'High pressure detected on heel. Rest your feet for 15 minutes.',
      urgency: UrgencyLevel.high,
      dateTime: DateTime.now().subtract(const Duration(hours: 2)),
      icon: Icons.airline_seat_recline_normal,
      isCompleted: false,
      instructions: 'Sit down and elevate your feet above heart level. This helps reduce swelling and pressure on your heels.',
    ),
    RecommendationItem(
      id: '2',
      type: RecommendationType.temperature,
      title: 'Cool Down Your Feet',
      description: 'Elevated temperature detected. Apply cool compress.',
      urgency: UrgencyLevel.high,
      dateTime: DateTime.now().subtract(const Duration(hours: 5)),
      icon: Icons.ac_unit,
      isCompleted: false,
      instructions: 'Use a cool (not cold) compress on your feet for 10-15 minutes. Avoid ice directly on skin.',
    ),
    RecommendationItem(
      id: '3',
      type: RecommendationType.movement,
      title: 'Gentle Stretching',
      description: 'Limited movement detected. Try ankle rotations.',
      urgency: UrgencyLevel.medium,
      dateTime: DateTime.now().subtract(const Duration(days: 1)),
      icon: Icons.self_improvement,
      isCompleted: true,
      instructions: 'Rotate your ankles clockwise 10 times, then counterclockwise 10 times. Repeat 3 sets.',
    ),
    RecommendationItem(
      id: '4',
      type: RecommendationType.pressure,
      title: 'Change Footwear',
      description: 'Uneven pressure distribution. Check your shoes.',
      urgency: UrgencyLevel.medium,
      dateTime: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
      icon: Icons.directions_walk,
      isCompleted: false,
      instructions: 'Inspect your shoes for wear. Consider diabetic-friendly footwear with proper cushioning.',
    ),
    RecommendationItem(
      id: '5',
      type: RecommendationType.temperature,
      title: 'Stay Hydrated',
      description: 'Maintain proper hydration for foot health.',
      urgency: UrgencyLevel.low,
      dateTime: DateTime.now().subtract(const Duration(days: 2)),
      icon: Icons.water_drop,
      isCompleted: true,
      instructions: 'Drink at least 8 glasses of water daily. Proper hydration helps maintain healthy skin on your feet.',
    ),
    RecommendationItem(
      id: '6',
      type: RecommendationType.movement,
      title: 'Schedule Doctor Visit',
      description: 'Urgent checkup needed for foot assessment.',
      urgency: UrgencyLevel.high,
      dateTime: DateTime.now().subtract(const Duration(hours: 1)),
      icon: Icons.medical_services,
      isCompleted: false,
      instructions: 'Book an urgent appointment with your podiatrist for a comprehensive foot examination. Early detection is crucial for preventing complications.',
    ),
  ];

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
    // Start with sample recommendations
    _recommendations = List.from(_sampleRecommendations);

    // Add recommendations from AlertService alerts
    final alerts = AlertService().alerts;
    for (final alert in alerts) {
      if (alert.recommendationTitle != null && !alert.isResolved) {
        // Convert alert to recommendation if not already present
        if (!_recommendations.any((r) => r.id == 'alert_${alert.id}')) {
          _recommendations.add(_alertToRecommendation(alert));
        }
      }
    }

    // Sort by date (newest first)
    _recommendations.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    // Reinitialize animations
    _disposePulseControllers();
    _initializePulseAnimations();

    if (mounted) setState(() {});
  }

  RecommendationItem _alertToRecommendation(alert_model.SmartAlert alert) {
    return RecommendationItem(
      id: 'alert_${alert.id}',
      type: _categoryToType(alert.category),
      title: alert.recommendationTitle ?? alert.title,
      description: alert.recommendationDescription ?? alert.shortDescription,
      urgency: _riskLevelToUrgency(alert.riskLevel),
      dateTime: alert.timestamp,
      icon: _getCategoryIcon(alert.category),
      isCompleted: alert.isResolved,
      instructions: alert.instructions ?? '',
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
        return RecommendationType.movement;
    }
  }

  UrgencyLevel _riskLevelToUrgency(alert_model.RiskLevel level) {
    switch (level) {
      case alert_model.RiskLevel.high:
        return UrgencyLevel.high;
      case alert_model.RiskLevel.medium:
        return UrgencyLevel.medium;
      case alert_model.RiskLevel.low:
        return UrgencyLevel.low;
    }
  }

  IconData _getCategoryIcon(alert_model.RiskCategory category) {
    switch (category) {
      case alert_model.RiskCategory.pressure:
        return Icons.compress;
      case alert_model.RiskCategory.temperature:
        return Icons.thermostat;
      case alert_model.RiskCategory.movement:
        return Icons.directions_walk;
      case alert_model.RiskCategory.general:
        return Icons.health_and_safety;
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

    // Start pulse animation for high urgency items
    for (int i = 0; i < _recommendations.length; i++) {
      if (_recommendations[i].urgency == UrgencyLevel.high &&
          !_recommendations[i].isCompleted) {
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
        case 'High':
          return item.urgency == UrgencyLevel.high;
        case 'Medium':
          return item.urgency == UrgencyLevel.medium;
        case 'Low':
          return item.urgency == UrgencyLevel.low;
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
      case 'High':
        return const Color(0xFFE53935);
      case 'Medium':
        return const Color(0xFFFFA726);
      case 'Low':
        return const Color(0xFF66BB6A);
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
            // Show detail dialog only for High Risk recommendations
            if (item.urgency == UrgencyLevel.high) {
              _showDetailDialog(item);
            } else {
              // For Medium/Low, show a simple snackbar
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(item.description),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: const Color(0xFF2A9D8F),
                ),
              );
            }
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
      } else if (_recommendations[index].urgency == UrgencyLevel.high) {
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
              color: Color(0xFFE53935),
              label: 'High Risk',
              description: 'Requires immediate attention',
            ),
            SizedBox(height: 12),
            _InfoRow(
              color: Color(0xFFFFA726),
              label: 'Medium Risk',
              description: 'Should be addressed soon',
            ),
            SizedBox(height: 12),
            _InfoRow(
              color: Color(0xFF66BB6A),
              label: 'Low Risk',
              description: 'Preventive care tips',
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
                : _getUrgencyColor(item.urgency).withOpacity(0.3),
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

    // Add pulse animation for high urgency items
    if (item.urgency == UrgencyLevel.high && !item.isCompleted) {
      return AnimatedBuilder(
        animation: pulseController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE53935)
                      .withOpacity(0.2 * pulseController.value),
                  blurRadius: 20 * pulseController.value,
                  spreadRadius: 2 * pulseController.value,
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
    return Stack(
      children: [
        Container(
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
        ),
        // Urgency dot
        Positioned(
          right: 0,
          top: 0,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: item.isCompleted
                  ? Colors.grey[400]
                  : _getUrgencyColor(item.urgency),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
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

  Color _getUrgencyColor(UrgencyLevel urgency) {
    switch (urgency) {
      case UrgencyLevel.high:
        return const Color(0xFFE53935);
      case UrgencyLevel.medium:
        return const Color(0xFFFFA726);
      case UrgencyLevel.low:
        return const Color(0xFF66BB6A);
    }
  }

  Color _getTypeColor(RecommendationType type) {
    switch (type) {
      case RecommendationType.pressure:
        return const Color(0xFF5C6BC0);
      case RecommendationType.temperature:
        return const Color(0xFFEF5350);
      case RecommendationType.movement:
        return const Color(0xFF26A69A);
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
    String label;
    Color color;

    switch (item.urgency) {
      case UrgencyLevel.high:
        label = 'High Priority';
        color = const Color(0xFFE53935);
        break;
      case UrgencyLevel.medium:
        label = 'Medium Priority';
        color = const Color(0xFFFFA726);
        break;
      case UrgencyLevel.low:
        label = 'Low Priority';
        color = const Color(0xFF66BB6A);
        break;
    }

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
        return const Color(0xFF5C6BC0);
      case RecommendationType.temperature:
        return const Color(0xFFEF5350);
      case RecommendationType.movement:
        return const Color(0xFF26A69A);
    }
  }
}

// Data Models
enum UrgencyLevel { high, medium, low }

enum RecommendationType { pressure, temperature, movement }

class RecommendationItem {
  final String id;
  final RecommendationType type;
  final String title;
  final String description;
  final UrgencyLevel urgency;
  final DateTime dateTime;
  final IconData icon;
  final bool isCompleted;
  final String instructions;

  const RecommendationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.urgency,
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
    UrgencyLevel? urgency,
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
      urgency: urgency ?? this.urgency,
      dateTime: dateTime ?? this.dateTime,
      icon: icon ?? this.icon,
      isCompleted: isCompleted ?? this.isCompleted,
      instructions: instructions ?? this.instructions,
    );
  }
}
