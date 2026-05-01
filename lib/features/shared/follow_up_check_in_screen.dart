import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../app/app_theme.dart';
import '../../models/consultation.dart';
import '../../services/firebase/consultation_chat_service.dart';

/// Patient check-in screen for follow-up consultations.
/// Shows tasks assigned by the doctor (wound photo, feeling, medication adherence).
class FollowUpCheckInScreen extends StatefulWidget {
  final Consultation consultation;

  const FollowUpCheckInScreen({super.key, required this.consultation});

  @override
  State<FollowUpCheckInScreen> createState() => _FollowUpCheckInScreenState();
}

class _FollowUpCheckInScreenState extends State<FollowUpCheckInScreen> {
  final _service = ConsultationChatService();
  final _imagePicker = ImagePicker();
  final _feelingController = TextEditingController();

  bool _isSaving = false;
  String? _photoUrl;
  File? _photoFile;
  String? _medicationAdherence; // 'yes', 'partial', 'no'

  @override
  void dispose() {
    _feelingController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _tasks => widget.consultation.followUpTasks;

  bool get _hasPhotoTask => _tasks.any((t) => t['id'] == 'photo');
  bool get _hasFeelingTask => _tasks.any((t) => t['id'] == 'feeling');
  bool get _hasMedicationTask => _tasks.any((t) => t['id'] == 'medication');

  bool get _canSubmit {
    if (_hasPhotoTask && _photoUrl == null) return false;
    if (_hasFeelingTask && _feelingController.text.trim().isEmpty) return false;
    if (_hasMedicationTask && _medicationAdherence == null) return false;
    return true;
  }

  Future<void> _pickPhoto() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;

    setState(() {
      _photoFile = File(picked.path);
      _isSaving = true;
    });

    try {
      final url = await _uploadPhoto(File(picked.path));
      setState(() {
        _photoUrl = url;
        _isSaving = false;
      });
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<String> _uploadPhoto(File file) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final ext = file.path.split('.').last.toLowerCase();
    final mimeMap = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
    };

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final ref = FirebaseStorage.instance
        .ref()
        .child('consultations')
        .child(widget.consultation.consultationID)
        .child('checkin')
        .child(fileName);

    final metadata = SettableMetadata(
      contentType: mimeMap[ext] ?? 'image/jpeg',
      customMetadata: {
        'consultationId': widget.consultation.consultationID,
        'senderId': user.uid,
      },
    );

    final task = await ref.putFile(file, metadata);
    return task.ref.getDownloadURL();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _isSaving = true);

    try {
      final responses = <String, dynamic>{
        'submittedAt': DateTime.now().toIso8601String(),
      };

      if (_hasPhotoTask && _photoUrl != null) {
        responses['photo'] = _photoUrl;
      }
      if (_hasFeelingTask) {
        responses['feeling'] = _feelingController.text.trim();
      }
      if (_hasMedicationTask && _medicationAdherence != null) {
        responses['medicationAdherence'] = _medicationAdherence;
      }

      await _service.submitCheckIn(
        consultationId: widget.consultation.consultationID,
        responses: responses,
      );

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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
    final c = widget.consultation;
    final alreadyDone = c.hasCheckIn;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Follow-up Check-in',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: AppColors.primary,
          ),
        ),
        centerTitle: true,
      ),
      body: alreadyDone ? _buildAlreadySubmitted(c) : _buildCheckInForm(c),
    );
  }

  Widget _buildAlreadySubmitted(Consultation c) {
    final checkIn = c.followUpCheckIn!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Success header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.success,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Check-in Submitted',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Your doctor will review your update.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Show responses
          if (checkIn['photo'] != null) ...[
            _responseCard(
              icon: Icons.camera_alt_rounded,
              title: 'Wound Photo',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  checkIn['photo'] as String,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (checkIn['feeling'] != null) ...[
            _responseCard(
              icon: Icons.edit_note_rounded,
              title: 'How are you feeling?',
              child: Text(
                checkIn['feeling'] as String,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (checkIn['medicationAdherence'] != null) ...[
            _responseCard(
              icon: Icons.medication_liquid_rounded,
              title: 'Medication Adherence',
              child: _adherenceBadge(checkIn['medicationAdherence'] as String),
            ),
          ],
        ],
      ),
    );
  }

  Widget _responseCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _adherenceBadge(String value) {
    Color color;
    String label;
    IconData icon;
    switch (value) {
      case 'yes':
        color = AppColors.success;
        label = 'Taking all medications as prescribed';
        icon = Icons.check_circle_rounded;
        break;
      case 'partial':
        color = AppColors.warning;
        label = 'Missed some doses';
        icon = Icons.warning_amber_rounded;
        break;
      default:
        color = AppColors.error;
        label = 'Not taking medications';
        icon = Icons.cancel_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckInForm(Consultation c) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Doctor instructions
                if (c.followUpInstructions != null &&
                    c.followUpInstructions!.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.info.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 20,
                          color: AppColors.info,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Note from your doctor',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.info,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                c.followUpInstructions!,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Due date
                if (c.followUpDueDate != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Due: ${_formatDate(c.followUpDueDate!)}',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                const Text(
                  'Your doctor would like you to report:',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),

                // Photo task
                if (_hasPhotoTask) ...[
                  _buildTaskCard(
                    icon: Icons.camera_alt_rounded,
                    title: 'Wound Photo',
                    subtitle: 'Take or upload a photo of the wound area',
                    child: _photoUrl != null
                        ? Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: _photoFile != null
                                    ? Image.file(
                                        _photoFile!,
                                        height: 180,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.network(
                                        _photoUrl!,
                                        height: 180,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () => setState(() {
                                    _photoUrl = null;
                                    _photoFile = null;
                                  }),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : OutlinedButton.icon(
                            onPressed: _isSaving ? null : _pickPhoto,
                            icon: const Icon(
                              Icons.add_a_photo_rounded,
                              size: 20,
                            ),
                            label: const Text(
                              'Upload Photo',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: BorderSide(
                                color: AppColors.primary.withValues(alpha: 0.4),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 13,
                                horizontal: 20,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Feeling task
                if (_hasFeelingTask) ...[
                  _buildTaskCard(
                    icon: Icons.edit_note_rounded,
                    title: 'How are you feeling?',
                    subtitle: 'Describe any symptoms, pain, or improvements',
                    child: TextField(
                      controller: _feelingController,
                      maxLines: 3,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g., The wound looks better, less pain...',
                        hintStyle: const TextStyle(
                          fontFamily: 'Poppins',
                          color: AppColors.textHint,
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: AppColors.inputFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.inputBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.inputBorder,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Medication adherence task
                if (_hasMedicationTask) ...[
                  _buildTaskCard(
                    icon: Icons.medication_liquid_rounded,
                    title: 'Medication Adherence',
                    subtitle: 'Have you been taking your medications?',
                    child: Column(
                      children: [
                        _adherenceOption(
                          'yes',
                          'Yes, all as prescribed',
                          Icons.check_circle_outline_rounded,
                          AppColors.success,
                        ),
                        const SizedBox(height: 8),
                        _adherenceOption(
                          'partial',
                          'Missed some doses',
                          Icons.warning_amber_rounded,
                          AppColors.warning,
                        ),
                        const SizedBox(height: 8),
                        _adherenceOption(
                          'no',
                          'Not taking medications',
                          Icons.cancel_outlined,
                          AppColors.error,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Submit button — glass effect
        ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: _canSubmit && !_isSaving
                        ? const LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryDark],
                          )
                        : null,
                    color: _canSubmit && !_isSaving
                        ? null
                        : AppColors.inputBorder,
                    boxShadow: _canSubmit && !_isSaving
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: ElevatedButton(
                    onPressed: _canSubmit && !_isSaving ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.transparent,
                      disabledForegroundColor: Colors.white.withValues(
                        alpha: 0.55,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                      shadowColor: Colors.transparent,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Submit Check-in',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTaskCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _adherenceOption(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    final selected = _medicationAdherence == value;
    return GestureDetector(
      onTap: () => setState(() => _medicationAdherence = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.08) : AppColors.inputFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.4)
                : AppColors.inputBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: selected ? color : AppColors.textHint),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                  color: selected ? color : AppColors.textSecondary,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? color : Colors.transparent,
                border: Border.all(
                  color: selected ? color : AppColors.inputBorder,
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}
