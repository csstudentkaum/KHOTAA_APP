import 'package:flutter/material.dart';
import '../../models/alert.dart';
import '../sensor_alerts/alert_service.dart';
import 'preventive_recommendations_screen.dart';

/// Risk Explanation Screen
/// Shows full details of a triggered alert with visual representation
class RiskExplanationScreen extends StatefulWidget {
  final SmartAlert alert;

  const RiskExplanationScreen({Key? key, required this.alert})
    : super(key: key);

  @override
  State<RiskExplanationScreen> createState() => _RiskExplanationScreenState();
}

class _RiskExplanationScreenState extends State<RiskExplanationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _iconAnimationController;
  late Animation<double> _iconScaleAnimation;
  late Animation<double> _iconRotateAnimation;

  @override
  void initState() {
    super.initState();

    // Mark alert as viewed after build completes to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AlertService().markAsViewed(widget.alert.id);
    });

    // Setup icon animation
    _iconAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _iconScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    _iconRotateAnimation = Tween<double>(begin: -0.05, end: 0.0).animate(
      CurvedAnimation(parent: _iconAnimationController, curve: Curves.easeOut),
    );

    _iconAnimationController.forward();
  }

  @override
  void dispose() {
    _iconAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Alert Details',
          style: TextStyle(
            color: Color(0xFF64ADB3),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.more_vert,
                color: Color(0xFF1A1A2E),
                size: 20,
              ),
            ),
            onSelected: (value) {
              if (value == 'resolve') {
                AlertService().markAsResolved(widget.alert.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Alert marked as resolved'),
                    backgroundColor: Color(0xFF27AE60),
                  ),
                );
                Navigator.pop(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'resolve',
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Color(0xFF27AE60)),
                    SizedBox(width: 12),
                    Text('Mark as Resolved'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Risk Level Badge with Animation
            _buildRiskLevelHeader(),
            const SizedBox(height: 24),
            // Alert Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    widget.alert.title,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Timestamp
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.alert.fullFormattedDateTime,
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Category Card
                  _buildCategoryCard(),
                  const SizedBox(height: 20),
                  // What This Means
                  _buildExplanationCard(),
                  const SizedBox(height: 20),
                  // Sensor Readings Card
                  if (widget.alert.sensorData != null) ...[
                    _buildSensorDataCard(),
                    const SizedBox(height: 20),
                  ],
                  // Recommendation
                  if (widget.alert.recommendationTitle != null) ...[
                    _buildRecommendationCard(),
                    const SizedBox(height: 20),
                  ],
                  // Action Buttons
                  _buildActionButtons(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Simplified header - shows category icon (no risk level)
  Widget _buildRiskLevelHeader() {
    return AnimatedBuilder(
      animation: _iconAnimationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _iconScaleAnimation.value,
          child: Transform.rotate(
            angle: _iconRotateAnimation.value,
            child: Column(
              children: [
                // Category Icon Container (simplified - no risk colors)
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1), // Calm amber background
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF57C00).withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.alert.category.icon,
                    size: 50,
                    color: const Color(0xFFF57C00),
                  ),
                ),
                const SizedBox(height: 12),
                // Category Badge (read-only label)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF64ADB3).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.alert.category.label,
                    style: const TextStyle(
                      color: Color(0xFF64ADB3),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF64ADB3).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              widget.alert.category.icon,
              color: const Color(0xFF64ADB3),
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Category',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.alert.category.label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExplanationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF64ADB3).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.description,
                  color: Color(0xFF64ADB3),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'What This Means',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _cleanExplanation(widget.alert.detailedExplanation),
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF4B5563),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  String _cleanExplanation(String text) {
    var cleaned = text.replaceAll('IWGDF 2023 Analysis:', 'Expert system findings:');

    final additionalIndex = cleaned.indexOf('Additional Recommendations:');
    if (additionalIndex >= 0) {
      cleaned = cleaned.substring(0, additionalIndex).trim();
    }

    return cleaned;
  }

  Widget _buildSensorDataCard() {
    final data = widget.alert.sensorData!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.sensors,
                  color: Color(0xFF6366F1),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Sensor Readings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSensorValue(
                  'Pressure',
                  '${data['pressureValue']?.toStringAsFixed(1) ?? 'N/A'}',
                  'units',
                  Icons.compress,
                  const Color(0xFFE53935),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSensorValue(
                  'Temperature',
                  '${data['temperatureValue']?.toStringAsFixed(1) ?? 'N/A'}',
                  '°C',
                  Icons.thermostat,
                  const Color(0xFFF39C12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildInfoChip(Icons.directions_walk, data['footSide'] ?? 'N/A'),
              const SizedBox(width: 8),
              _buildInfoChip(Icons.location_on, data['sensorRegion'] ?? 'N/A'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSensorValue(
    String label,
    String value,
    String unit,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF6B7280)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            widget.alert.riskLevel.color.withOpacity(0.1),
            widget.alert.riskLevel.backgroundColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.alert.riskLevel.color.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.alert.riskLevel.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.tips_and_updates,
                  color: widget.alert.riskLevel.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Recommendation',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.alert.recommendationTitle ?? '',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: widget.alert.riskLevel.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.alert.recommendationDescription ?? '',
            style: const TextStyle(fontSize: 15, color: Color(0xFF4B5563)),
          ),
          if (widget.alert.instructions != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: widget.alert.riskLevel.color,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.alert.instructions!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF4B5563),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // View All Recommendations Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PreventiveRecommendationsScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF64ADB3),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.list_alt, size: 22),
                SizedBox(width: 10),
                Text(
                  'View All Recommendations',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Mark as Resolved Button
        if (!widget.alert.isResolved)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: () {
                AlertService().markAsResolved(widget.alert.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Alert marked as resolved'),
                    backgroundColor: Color(0xFF27AE60),
                  ),
                );
                Navigator.pop(context);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF27AE60),
                side: const BorderSide(color: Color(0xFF27AE60), width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Mark as Resolved',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
