import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../services/expert_system/expert_system.dart';
import '../booking/all_doctors_screen.dart';

/// Medical Alert Dialog - Simple, friendly alert for patients
/// Shows a small card initially, expands to show details on tap
/// Based on IWGDF 2023 Guidelines
class MedicalAlertDialog extends StatefulWidget {
  final ExpertSystemResult result;
  final VoidCallback? onDismiss;
  final VoidCallback? onContactDoctor;

  const MedicalAlertDialog({
    super.key,
    required this.result,
    this.onDismiss,
    this.onContactDoctor,
  });

  /// Show the alert dialog with sound
  static Future<void> show(
    BuildContext context,
    ExpertSystemResult result, {
    VoidCallback? onDismiss,
    VoidCallback? onContactDoctor,
  }) async {
    // Play alert sound
    try {
      final player = AudioPlayer();
      await player.play(AssetSource('sounds/alert_sound.wav'));
      player.onPlayerComplete.listen((_) => player.dispose());
    } catch (e) {
      debugPrint('⚠️ Could not play alert sound: $e');
    }

    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (ctx) => MedicalAlertDialog(
        result: result,
        onDismiss: () {
          Navigator.of(ctx).pop();
          onDismiss?.call();
        },
        onContactDoctor: onContactDoctor,
      ),
    );
  }

  @override
  State<MedicalAlertDialog> createState() => _MedicalAlertDialogState();
}

class _MedicalAlertDialogState extends State<MedicalAlertDialog> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        constraints: BoxConstraints(
          maxWidth: 340,
          maxHeight: _showDetails ? 560 : 380,
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Main content
                SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 16), // Space for X button
                      _buildCompactAlert(),
                      if (_showDetails) _buildDetails(),
                      _buildActions(),
                    ],
                  ),
                ),
                // Big X close button - always visible at top right
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onDismiss,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.grey[600],
                          size: 26,
                        ),
                      ),
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

  /// Compact alert view - shown initially
  Widget _buildCompactAlert() {
    final region = widget.result.affectedRegion?.displayName ?? 'Foot';
    
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Warning Icon - larger for visibility
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFFFEBEE),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_rounded,
              color: Color(0xFFE53935),
              size: 42,
            ),
          ),
          const SizedBox(height: 16),
          
          // Title - larger text
          const Text(
            'Health Alert',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 12),
          
          // Simple message - larger text
          Text(
            'Abnormal readings detected in $region.\nPlease take action.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          
          // Show details button
          if (!_showDetails)
            TextButton.icon(
              onPressed: () => setState(() => _showDetails = true),
              icon: const Icon(Icons.expand_more, size: 24),
              label: const Text('View Details', style: TextStyle(fontSize: 15)),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF64ADB3),
              ),
            ),
        ],
      ),
    );
  }

  /// Expandable details section
  Widget _buildDetails() {
    final result = widget.result;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Collapse button
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _showDetails = false),
              icon: const Icon(Icons.expand_less, size: 20),
              label: const Text('Hide Details'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[500],
              ),
            ),
          ),
          const SizedBox(height: 8),
          
          // Detected issues
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, 
                      color: Colors.orange[700], size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'What was detected',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.orange[700],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...result.triggeredRules.map((rule) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ', style: TextStyle(
                        color: Colors.orange[700],
                        fontWeight: FontWeight.bold,
                      )),
                      Expanded(
                        child: Text(
                          rule.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          // Recommendation
          if (result.recommendedActions.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, 
                        color: Colors.green[700], size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'What to do',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.green[700],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result.recommendedActions.first.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    result.recommendedActions.first.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          // Main action - Go to available doctors (BIG and clear for elderly)
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                // Push doctors screen (so user can go back)
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AllDoctorsScreen()),
                );
              },
              icon: const Icon(Icons.medical_services_rounded, size: 26),
              label: const Text(
                'Contact a Doctor',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 3,
              ),
            ),
          ),
          
          // Dismiss option - small text for those who just want to close
          const SizedBox(height: 16),
          TextButton(
            onPressed: widget.onDismiss,
            child: Text(
              'Dismiss',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[500],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
