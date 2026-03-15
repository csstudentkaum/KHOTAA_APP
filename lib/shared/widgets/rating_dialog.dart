import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../app/app_theme.dart';

/// A beautiful rating & feedback dialog shown after consultation completion.
/// Saves the rating to a `reviews` subcollection on the doctor and updates
/// the doctor's aggregate `rating` and `ratingCount` fields.
class RatingDialog extends StatefulWidget {
  final String doctorId;
  final String doctorName;
  final String consultationId;
  final String patientId;

  const RatingDialog({
    super.key,
    required this.doctorId,
    required this.doctorName,
    required this.consultationId,
    required this.patientId,
  });

  /// Show the rating dialog. Returns true if rating was submitted.
  static Future<bool> show(
    BuildContext context, {
    required String doctorId,
    required String doctorName,
    required String consultationId,
    required String patientId,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RatingDialog(
        doctorId: doctorId,
        doctorName: doctorName,
        consultationId: consultationId,
        patientId: patientId,
      ),
    );
    return result ?? false;
  }

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog>
    with SingleTickerProviderStateMixin {
  int _selectedRating = 0;
  final _feedbackController = TextEditingController();
  bool _isSaving = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_selectedRating == 0) return;

    setState(() => _isSaving = true);

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      // 1. Save review to doctor's reviews subcollection
      final reviewRef = db
          .collection('users')
          .doc(widget.doctorId)
          .collection('reviews')
          .doc();
      batch.set(reviewRef, {
        'rating': _selectedRating,
        'feedback': _feedbackController.text.trim(),
        'patientId': widget.patientId,
        'consultationId': widget.consultationId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Update doctor's aggregate rating
      final doctorRef = db.collection('users').doc(widget.doctorId);
      final doctorDoc = await doctorRef.get();
      final data = doctorDoc.data() ?? {};
      final currentRating = (data['rating'] as num?)?.toDouble() ?? 0.0;
      final currentCount = (data['ratingCount'] as num?)?.toInt() ?? 0;

      final newCount = currentCount + 1;
      final newRating =
          ((currentRating * currentCount) + _selectedRating) / newCount;

      batch.update(doctorRef, {
        'rating': double.parse(newRating.toStringAsFixed(1)),
        'ratingCount': newCount,
      });

      // 3. Mark consultation as rated
      final consultRef = db
          .collection('consultations')
          .doc(widget.consultationId);
      batch.update(consultRef, {'rated': true});

      await batch.commit();

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting rating: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Doctor avatar
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: const Icon(
                      Icons.person,
                      size: 36,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  const Text(
                    'How was your experience?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Rate ${widget.doctorName.startsWith('Dr.') ? widget.doctorName : 'Dr. ${widget.doctorName}'}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Star rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starNum = index + 1;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedRating = starNum),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: AnimatedScale(
                            scale: _selectedRating >= starNum ? 1.2 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              _selectedRating >= starNum
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 42,
                              color: _selectedRating >= starNum
                                  ? Colors.amber
                                  : AppColors.textHint,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),

                  if (_selectedRating > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      _ratingLabel(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Feedback text field
                  TextField(
                    controller: _feedbackController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Share your feedback (optional)',
                      hintStyle: TextStyle(
                        color: AppColors.textHint,
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving
                              ? null
                              : () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Skip'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _selectedRating > 0 && !_isSaving
                              ? _submitRating
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade200,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Submit',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // ── Dismiss X button ──
            Positioned(
              top: 14,
              right: 14,
              child: GestureDetector(
                onTap: _isSaving
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.textHint,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _ratingLabel() {
    switch (_selectedRating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }
}
