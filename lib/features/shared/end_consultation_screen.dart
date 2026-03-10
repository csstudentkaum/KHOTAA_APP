import 'dart:ui';
import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import '../../models/consultation.dart';
import '../../services/firebase/consultation_chat_service.dart';

/// Full-screen wrap-up form: Consultation Summary + Treatment Plan + Decision.
class EndConsultationScreen extends StatefulWidget {
  final Consultation consultation;

  const EndConsultationScreen({super.key, required this.consultation});

  @override
  State<EndConsultationScreen> createState() => _EndConsultationScreenState();
}

class _EndConsultationScreenState extends State<EndConsultationScreen> {
  final _service = ConsultationChatService();
  final _diagnosisController = TextEditingController();
  final _notesController = TextEditingController();
  final _prescriptionController = TextEditingController();
  final _treatmentNotesController = TextEditingController();
  final _followUpInstructionsController = TextEditingController();

  final List<Map<String, String>> _medications = [];
  bool _isSaving = false;
  bool _hasChanges = false;
  bool _isLoading = true;

  // Decision: null = not chosen, 'complete', 'followUp'
  String? _decision;
  bool get _isFollowUp => widget.consultation.status == 'followUp';
  int _followUpDays = 3;
  final _customDaysController = TextEditingController();
  bool _useCustomDays = false;

  // Follow-up task toggles
  bool _taskPhoto = false;
  bool _taskFeeling = false;
  bool _taskMedication = false;

  static const _medicationSuggestions = [
    'Metformin',
    'Insulin Glargine',
    'Insulin Lispro',
    'Amoxicillin/Clavulanate',
    'Ciprofloxacin',
    'Clindamycin',
    'Gabapentin',
    'Pregabalin',
    'Aspirin',
    'Clopidogrel',
    'Silver Sulfadiazine Cream',
    'Mupirocin Ointment',
    'Ibuprofen',
    'Paracetamol',
  ];

  static const _frequencySuggestions = [
    'Once daily',
    'Twice daily',
    'Three times daily',
    'Every 8 hours',
    'Every 12 hours',
    'As needed',
    'Once weekly',
    'Once at bedtime',
  ];

  static const _durationSuggestions = [
    '7 days',
    '14 days',
    '1 month',
    '2 months',
    '3 months',
    '6 months',
    'Ongoing',
  ];

  @override
  void initState() {
    super.initState();
    // Pre-fill from consultation
    final c = widget.consultation;
    if (c.diagnosis != null) _diagnosisController.text = c.diagnosis!;
    if (c.notes != null) _notesController.text = c.notes!;
    if (c.prescription != null) _prescriptionController.text = c.prescription!;

    // If follow-up, load existing treatment plan data
    if (_isFollowUp) {
      _loadExistingTreatmentPlan();
    } else {
      _isLoading = false;
    }

    // Track changes
    for (final ctrl in [
      _diagnosisController,
      _notesController,
      _prescriptionController,
      _treatmentNotesController,
      _followUpInstructionsController,
    ]) {
      ctrl.addListener(_onChanged);
    }
  }

  Future<void> _loadExistingTreatmentPlan() async {
    try {
      final plan = await _service.getTreatmentPlan(
          widget.consultation.consultationID);
      if (plan != null && mounted) {
        setState(() {
          _treatmentNotesController.text = plan.notes;
          _medications.addAll(plan.medications);
          // Diagnosis from plan as fallback
          if (_diagnosisController.text.isEmpty) {
            _diagnosisController.text = plan.diagnosis;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  @override
  void dispose() {
    _diagnosisController.dispose();
    _notesController.dispose();
    _prescriptionController.dispose();
    _treatmentNotesController.dispose();
    _followUpInstructionsController.dispose();
    _customDaysController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges && _medications.isEmpty) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Discard Changes?',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        content: const Text(
          'You have unsaved changes. Are you sure you want to leave?',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Keep Editing',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Discard',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _save() async {
    final diagnosis = _diagnosisController.text.trim();
    if (diagnosis.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please enter a diagnosis'),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    if (_decision == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select what\'s next for this patient'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final notes = _notesController.text.trim();
      final prescription = _prescriptionController.text.trim();
      final treatmentNotes = _treatmentNotesController.text.trim();

      if (_decision == 'complete') {
        await _service.completeWithSummary(
          consultationId: widget.consultation.consultationID,
          diagnosis: diagnosis,
          notes: notes,
          prescription: prescription,
          medications: _medications,
          treatmentNotes: treatmentNotes,
        );
      } else {
        // Build follow-up tasks
        final tasks = <Map<String, dynamic>>[];
        if (_taskPhoto) {
          tasks.add({'id': 'photo', 'label': 'Upload wound photo', 'type': 'photo', 'completed': false});
        }
        if (_taskFeeling) {
          tasks.add({'id': 'feeling', 'label': 'How are you feeling?', 'type': 'text', 'completed': false});
        }
        if (_taskMedication) {
          tasks.add({'id': 'medication', 'label': 'Medication adherence', 'type': 'choice', 'completed': false});
        }

        await _service.setFollowUpWithPlan(
          consultationId: widget.consultation.consultationID,
          diagnosis: diagnosis,
          notes: notes,
          prescription: prescription,
          medications: _medications,
          treatmentNotes: treatmentNotes,
          followUpDays: _followUpDays,
          followUpTasks: tasks,
          followUpInstructions: _followUpInstructionsController.text.trim(),
        );
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showAddMedicationDialog() {
    final nameCtrl = TextEditingController();
    final dosageCtrl = TextEditingController();
    final freqCtrl = TextEditingController();
    final durCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.medication_outlined,
                          color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Text('Add Medication',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        )),
                  ],
                ),
                const SizedBox(height: 20),
                _buildAutocompleteField(
                  controller: nameCtrl,
                  label: 'Medication Name',
                  icon: Icons.medication_rounded,
                  suggestions: _medicationSuggestions,
                ),
                const SizedBox(height: 14),
                _buildInputField(
                  controller: dosageCtrl,
                  label: 'Dosage (e.g., 500mg)',
                  icon: Icons.science_outlined,
                ),
                const SizedBox(height: 14),
                _buildAutocompleteField(
                  controller: freqCtrl,
                  label: 'Frequency',
                  icon: Icons.schedule_rounded,
                  suggestions: _frequencySuggestions,
                ),
                const SizedBox(height: 14),
                _buildAutocompleteField(
                  controller: durCtrl,
                  label: 'Duration',
                  icon: Icons.calendar_today_rounded,
                  suggestions: _durationSuggestions,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(color: AppColors.inputBorder),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancel',
                            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (nameCtrl.text.trim().isEmpty) return;
                          setState(() {
                            _medications.add({
                              'name': nameCtrl.text.trim(),
                              'dosage': dosageCtrl.text.trim(),
                              'frequency': freqCtrl.text.trim(),
                              'duration': durCtrl.text.trim(),
                            });
                            _hasChanges = true;
                          });
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        child: const Text('Add',
                            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges && _medications.isEmpty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () async {
              if (!_hasChanges && _medications.isEmpty) {
                Navigator.of(context).pop();
              } else {
                final shouldPop = await _onWillPop();
                if (shouldPop && context.mounted) {
                  Navigator.of(context).pop();
                }
              }
            },
          ),
          title: const Text(
            'Consultation Summary',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
        ),
        body: (_isSaving || _isLoading)
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 16),
                    Text(_isSaving ? 'Saving...' : 'Loading...',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          color: AppColors.textSecondary,
                          fontSize: 15,
                        )),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Patient info mini-card
                    _buildPatientHeader(),
                    const SizedBox(height: 24),

                    // ── Section 1: Consultation Summary ──
                    _buildSectionCard(
                      icon: Icons.medical_information_outlined,
                      title: 'Consultation Summary',
                      children: [
                        _buildSectionLabel(Icons.local_hospital_outlined, 'Diagnosis'),
                        const SizedBox(height: 8),
                        _buildTextArea(
                          controller: _diagnosisController,
                          hint: 'Enter diagnosis details...',
                          maxLines: 2,
                        ),
                        const SizedBox(height: 18),
                        _buildSectionLabel(Icons.note_alt_outlined, 'Clinical Notes'),
                        const SizedBox(height: 8),
                        _buildTextArea(
                          controller: _notesController,
                          hint: 'Write your clinical observations...',
                          maxLines: 3,
                        ),
                        const SizedBox(height: 18),
                        _buildSectionLabel(Icons.receipt_long_outlined, 'Prescription'),
                        const SizedBox(height: 8),
                        _buildTextArea(
                          controller: _prescriptionController,
                          hint: 'Enter prescription details...',
                          maxLines: 2,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Section 2: Treatment Plan ──
                    _buildSectionCard(
                      icon: Icons.medication_outlined,
                      title: 'Treatment Plan',
                      children: [
                        _buildSectionLabel(Icons.medication_rounded, 'Medications'),
                        const SizedBox(height: 10),
                        ..._medications.asMap().entries.map((entry) =>
                            _buildMedicationCard(entry.key, entry.value)),
                        const SizedBox(height: 8),
                        _buildAddMedicationButton(),
                        const SizedBox(height: 18),
                        _buildSectionLabel(Icons.note_alt_outlined, 'Additional Notes'),
                        const SizedBox(height: 8),
                        _buildTextArea(
                          controller: _treatmentNotesController,
                          hint: 'e.g., Wound care instructions, activity limitations...',
                          maxLines: 3,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Section 3: What's Next? ──
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 14),
                      child: Text(
                        'What\'s next for this patient?',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    _buildDecisionCard(
                      key: 'complete',
                      icon: Icons.check_circle_rounded,
                      color: AppColors.success,
                      title: 'Complete & Close',
                      subtitle: _isFollowUp
                          ? 'Review is done. Close this consultation.'
                          : 'Patient is stable. No further monitoring needed.',
                    ),
                    const SizedBox(height: 12),
                    _buildDecisionCard(
                      key: 'followUp',
                      icon: Icons.event_repeat_rounded,
                      color: AppColors.primary,
                      title: 'Follow-up Required',
                      subtitle: _isFollowUp
                          ? 'Patient needs another follow-up round.'
                          : 'I need to check on this patient\'s progress.',
                    ),

                    // ── Follow-up options (animated) ──
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      child: _decision == 'followUp'
                          ? _buildFollowUpOptions()
                          : const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 32),

                    // ── Save button ──
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _decision != null ? _save : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _decision == 'followUp'
                              ? AppColors.primary
                              : AppColors.success,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.inputBorder,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          _decision == 'followUp'
                              ? 'Save & Continue Monitoring'
                              : 'Complete Consultation',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
      ),
    );
  }

  // ── Widgets ──

  Widget _buildPatientHeader() {
    final c = widget.consultation;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.12),
            const Color(0xFF1F7A6E).withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.12),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.6),
            blurRadius: 1,
            spreadRadius: 0,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            child: Center(
              child: Text(
                (c.patientName ?? 'P')[0].toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.patientName ?? 'Patient',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (c.reason != null && c.reason!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      c.reason!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.1),
                  AppColors.primary.withValues(alpha: 0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.15),
              ),
            ),
            child: Text(
              c.formattedDate,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    ),
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  )),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSectionLabel(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            )),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: const TextStyle(
          fontFamily: 'Poppins',
          color: AppColors.textHint,
          fontSize: 14,
        ),
        prefixIcon: icon != null
            ? Icon(icon, size: 20, color: AppColors.textHint)
            : null,
        filled: true,
        fillColor: AppColors.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildAutocompleteField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    required List<String> suggestions,
  }) {
    return Autocomplete<String>(
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) return suggestions;
        return suggestions.where((s) =>
            s.toLowerCase().contains(textEditingValue.text.toLowerCase()));
      },
      onSelected: (selection) {
        controller.text = selection;
      },
      fieldViewBuilder: (context, textController, focusNode, onSubmit) {
        // Sync with our own controller
        if (textController.text.isEmpty && controller.text.isNotEmpty) {
          textController.text = controller.text;
        }
        textController.addListener(() {
          controller.text = textController.text;
        });
        return TextField(
          controller: textController,
          focusNode: focusNode,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
          decoration: InputDecoration(
            hintText: label,
            hintStyle: const TextStyle(
              fontFamily: 'Poppins',
              color: AppColors.textHint,
              fontSize: 14,
            ),
            prefixIcon: icon != null
                ? Icon(icon, size: 20, color: AppColors.textHint)
                : null,
            filled: true,
            fillColor: AppColors.inputFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.inputBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 320),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (_, i) {
                  final option = options.elementAt(i);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Text(option,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          )),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextArea({
    required TextEditingController controller,
    required String hint,
    int maxLines = 3,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontFamily: 'Poppins',
          color: AppColors.textHint,
          fontSize: 14,
        ),
        filled: true,
        fillColor: AppColors.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildMedicationCard(int index, Map<String, String> med) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.medication_rounded,
                color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(med['name'] ?? '',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    )),
                const SizedBox(height: 4),
                if (med['dosage']?.isNotEmpty == true)
                  _medDetail('Dosage', med['dosage']!),
                if (med['frequency']?.isNotEmpty == true)
                  _medDetail('Frequency', med['frequency']!),
                if (med['duration']?.isNotEmpty == true)
                  _medDetail('Duration', med['duration']!),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() {
              _medications.removeAt(index);
              _hasChanges = true;
            }),
            child: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close_rounded,
                  color: AppColors.error, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _medDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Row(
        children: [
          Text('$label: ',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: AppColors.textSecondary,
              )),
          Text(value,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              )),
        ],
      ),
    );
  }

  Widget _buildAddMedicationButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _showAddMedicationDialog,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text('Add Medication',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }

  Widget _buildDecisionCard({
    required String key,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    final selected = _decision == key;
    return GestureDetector(
      onTap: () => setState(() {
        _decision = key;
        _hasChanges = true;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.07) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : AppColors.inputBorder,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(
                  color: color.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: selected ? color : AppColors.textPrimary,
                      )),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: AppColors.textHint,
                      )),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24, height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? color : Colors.transparent,
                border: Border.all(
                  color: selected ? color : AppColors.inputBorder,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowUpOptions() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 12,
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
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.schedule_rounded,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                const Text('Follow-up Settings',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    )),
              ],
            ),
            const SizedBox(height: 18),

            // Duration picker — dropdown + custom
            const Text('Review in',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                )),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.inputBorder),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _useCustomDays ? -1 : _followUpDays,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  borderRadius: BorderRadius.circular(12),
                  dropdownColor: Colors.white,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  items: const [
                    DropdownMenuItem(value: 2, child: Text('2 days')),
                    DropdownMenuItem(value: 3, child: Text('3 days')),
                    DropdownMenuItem(value: 5, child: Text('5 days')),
                    DropdownMenuItem(value: 7, child: Text('1 week')),
                    DropdownMenuItem(value: 14, child: Text('2 weeks')),
                    DropdownMenuItem(value: 21, child: Text('3 weeks')),
                    DropdownMenuItem(value: 30, child: Text('1 month')),
                    DropdownMenuItem(value: -1, child: Text('Custom...')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      if (value == -1) {
                        _useCustomDays = true;
                      } else {
                        _useCustomDays = false;
                        _followUpDays = value;
                        _customDaysController.clear();
                      }
                    });
                  },
                ),
              ),
            ),
            if (_useCustomDays) ...[              const SizedBox(height: 10),
              TextField(
                controller: _customDaysController,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                onChanged: (val) {
                  final days = int.tryParse(val);
                  if (days != null && days > 0) {
                    _followUpDays = days;
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Enter number of days',
                  hintStyle: const TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.textHint,
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(Icons.edit_calendar_rounded,
                      size: 20, color: AppColors.textHint),
                  filled: true,
                  fillColor: AppColors.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.inputBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.inputBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ],
            const SizedBox(height: 22),

            // Patient check-in tasks
            const Text('Ask patient to report',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                )),
            const SizedBox(height: 10),
            _buildTaskToggle(
              icon: Icons.camera_alt_rounded,
              label: 'Wound photo update',
              value: _taskPhoto,
              onChanged: (v) => setState(() => _taskPhoto = v),
            ),
            const SizedBox(height: 8),
            _buildTaskToggle(
              icon: Icons.edit_note_rounded,
              label: 'How are you feeling?',
              value: _taskFeeling,
              onChanged: (v) => setState(() => _taskFeeling = v),
            ),
            const SizedBox(height: 8),
            _buildTaskToggle(
              icon: Icons.medication_liquid_rounded,
              label: 'Medication adherence',
              value: _taskMedication,
              onChanged: (v) => setState(() => _taskMedication = v),
            ),
            const SizedBox(height: 18),

            // Instructions
            const Text('Note to patient (optional)',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                )),
            const SizedBox(height: 8),
            _buildTextArea(
              controller: _followUpInstructionsController,
              hint: 'e.g., Please keep the wound dry...',
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskToggle({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: value
              ? AppColors.primary.withValues(alpha: 0.06)
              : AppColors.inputFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value
                ? AppColors.primary.withValues(alpha: 0.3)
                : AppColors.inputBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20,
                color: value ? AppColors.primary : AppColors.textHint),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: value ? FontWeight.w500 : FontWeight.w400,
                    color: value ? AppColors.textPrimary : AppColors.textSecondary,
                  )),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22, height: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: value ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: value ? AppColors.primary : AppColors.inputBorder,
                  width: 1.5,
                ),
              ),
              child: value
                  ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
