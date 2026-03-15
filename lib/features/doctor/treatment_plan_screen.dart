import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../app/app_theme.dart';

class TreatmentPlanScreen extends StatelessWidget {
  const TreatmentPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
          'Treatment Plans',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('treatment_plans')
            .where(
              'doctorId',
              isEqualTo: FirebaseAuth.instance.currentUser?.uid,
            )
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final plans = snapshot.data?.docs ?? [];

          if (plans.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.medical_information_outlined,
                      size: 64,
                      color: AppColors.textHint.withAlpha(100),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No treatment plans yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Treatment plans will appear here when\ncreated during consultations',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: AppColors.textHint),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: plans.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final data = plans[index].data() as Map<String, dynamic>;
              return _PlanCard(docId: plans[index].id, data: data);
            },
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// ══  PLAN CARD
// ═══════════════════════════════════════════════════
class _PlanCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;

  const _PlanCard({required this.docId, required this.data});

  @override
  Widget build(BuildContext context) {
    final patientName = data['patientName'] ?? 'Unknown';
    final diagnosis = data['diagnosis'] ?? '';
    final medications = data['medications'] as List<dynamic>? ?? [];
    final notes = data['notes'] ?? '';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final status = data['status'] ?? 'active';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _PlanDetailScreen(docId: docId, data: data),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.inputBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary.withAlpha(25),
                  child: Text(
                    patientName.isNotEmpty ? patientName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patientName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (createdAt != null)
                        Text(
                          '${createdAt.day}/${createdAt.month}/${createdAt.year}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: status == 'active'
                        ? const Color(0xFF22C55E).withAlpha(20)
                        : AppColors.textHint.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status == 'active' ? 'Active' : 'Completed',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: status == 'active'
                          ? const Color(0xFF22C55E)
                          : AppColors.textHint,
                    ),
                  ),
                ),
              ],
            ),
            if (diagnosis.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  diagnosis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6366F1),
                  ),
                ),
              ),
            ],
            if (medications.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: medications.take(3).map((m) {
                  final med = m as Map<String, dynamic>;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primary.withAlpha(40),
                      ),
                    ),
                    child: Text(
                      '${med['name'] ?? ''} ${med['dosage'] ?? ''}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                notes,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// ══  PLAN DETAIL SCREEN
// ═══════════════════════════════════════════════════
class _PlanDetailScreen extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;

  const _PlanDetailScreen({required this.docId, required this.data});

  @override
  Widget build(BuildContext context) {
    final patientName = data['patientName'] ?? 'Unknown';
    final diagnosis = data['diagnosis'] ?? 'N/A';
    final medications = data['medications'] as List<dynamic>? ?? [];
    final notes = data['notes'] ?? '';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final status = data['status'] ?? 'active';

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
          'Treatment Plan',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
            onSelected: (value) async {
              if (value == 'complete') {
                await FirebaseFirestore.instance
                    .collection('treatment_plans')
                    .doc(docId)
                    .update({'status': 'completed'});
                if (context.mounted) Navigator.pop(context);
              } else if (value == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Text('Delete Plan'),
                    content: const Text(
                      'Are you sure you want to delete this treatment plan?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await FirebaseFirestore.instance
                      .collection('treatment_plans')
                      .doc(docId)
                      .delete();
                  if (context.mounted) Navigator.pop(context);
                }
              }
            },
            itemBuilder: (_) => [
              if (status == 'active')
                const PopupMenuItem(
                  value: 'complete',
                  child: Text('Mark as Completed'),
                ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient & date
            _detailSection(
              icon: Icons.person_outline,
              title: 'Patient',
              child: Text(
                patientName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (createdAt != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(
                  'Created: ${createdAt.day}/${createdAt.month}/${createdAt.year}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textHint,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Diagnosis
            _detailSection(
              icon: Icons.medical_services_outlined,
              title: 'Diagnosis',
              child: Text(
                diagnosis,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Medications
            _detailSection(
              icon: Icons.medication_outlined,
              title: 'Medications',
              child: medications.isEmpty
                  ? const Text(
                      'No medications added',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textHint,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  : Column(
                      children: medications.map((m) {
                        final med = m as Map<String, dynamic>;
                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.inputFill,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.inputBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                med['name'] ?? '',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              _medDetail('Dosage', med['dosage'] ?? 'N/A'),
                              _medDetail(
                                'Frequency',
                                med['frequency'] ?? 'N/A',
                              ),
                              _medDetail('Duration', med['duration'] ?? 'N/A'),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 20),

            // Notes
            if (notes.isNotEmpty)
              _detailSection(
                icon: Icons.note_alt_outlined,
                title: 'Notes',
                child: Text(
                  notes,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailSection({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(padding: const EdgeInsets.only(left: 26), child: child),
      ],
    );
  }

  Widget _medDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// ══  CREATE TREATMENT PLAN SCREEN
// ═══════════════════════════════════════════════════
class _CreateTreatmentPlanScreen extends StatefulWidget {
  const _CreateTreatmentPlanScreen();

  @override
  State<_CreateTreatmentPlanScreen> createState() =>
      _CreateTreatmentPlanScreenState();
}

class _CreateTreatmentPlanScreenState
    extends State<_CreateTreatmentPlanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _diagnosisController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedPatientId;
  String? _selectedPatientName;
  bool _isSaving = false;

  // Medications list
  final List<Map<String, String>> _medications = [];

  // Temp controllers for medication dialog
  final _medNameController = TextEditingController();
  final _medDosageController = TextEditingController();
  final _medFrequencyController = TextEditingController();
  final _medDurationController = TextEditingController();

  // Common suggestions
  static const _diagnosisSuggestions = [
    'Diabetic Foot Ulcer',
    'Peripheral Neuropathy',
    'Charcot Foot',
    'Plantar Fasciitis',
    'Diabetic Foot Infection',
    'Peripheral Artery Disease',
    'Callus / Corn Formation',
    'Ingrown Toenail',
    'Dry / Cracked Skin',
    'Fungal Infection',
  ];

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
  void dispose() {
    _diagnosisController.dispose();
    _notesController.dispose();
    _medNameController.dispose();
    _medDosageController.dispose();
    _medFrequencyController.dispose();
    _medDurationController.dispose();
    super.dispose();
  }

  Future<void> _savePlan() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPatientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a patient'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance.collection('treatment_plans').add({
        'doctorId': FirebaseAuth.instance.currentUser?.uid,
        'patientId': _selectedPatientId,
        'patientName': _selectedPatientName ?? '',
        'diagnosis': _diagnosisController.text.trim(),
        'medications': _medications,
        'notes': _notesController.text.trim(),
        'status': 'active',
        'createdAt': Timestamp.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Treatment plan created successfully'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showAddMedicationDialog() {
    _medNameController.clear();
    _medDosageController.clear();
    _medFrequencyController.clear();
    _medDurationController.clear();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Medication'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildAutoCompleteField(
                controller: _medNameController,
                label: 'Medication Name',
                suggestions: _medicationSuggestions,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _medDosageController,
                decoration: _inputDeco('Dosage (e.g., 500mg)'),
              ),
              const SizedBox(height: 12),
              _buildAutoCompleteField(
                controller: _medFrequencyController,
                label: 'Frequency',
                suggestions: _frequencySuggestions,
              ),
              const SizedBox(height: 12),
              _buildAutoCompleteField(
                controller: _medDurationController,
                label: 'Duration',
                suggestions: _durationSuggestions,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_medNameController.text.trim().isEmpty) return;
              setState(() {
                _medications.add({
                  'name': _medNameController.text.trim(),
                  'dosage': _medDosageController.text.trim(),
                  'frequency': _medFrequencyController.text.trim(),
                  'duration': _medDurationController.text.trim(),
                });
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
      filled: true,
      fillColor: AppColors.inputFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.inputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _buildAutoCompleteField({
    required TextEditingController controller,
    required String label,
    required List<String> suggestions,
  }) {
    return Autocomplete<String>(
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) return suggestions;
        return suggestions.where(
          (s) => s.toLowerCase().contains(textEditingValue.text.toLowerCase()),
        );
      },
      onSelected: (selection) => controller.text = selection,
      fieldViewBuilder: (context, textController, focusNode, onSubmit) {
        // Sync with external controller
        textController.text = controller.text;
        textController.addListener(() {
          controller.text = textController.text;
        });
        return TextField(
          controller: textController,
          focusNode: focusNode,
          decoration: _inputDeco(label),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          'New Treatment Plan',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1) Select Patient ──
              _sectionLabel(Icons.person_outline, 'Patient'),
              const SizedBox(height: 8),
              _buildPatientSelector(),
              const SizedBox(height: 24),

              // ── 2) Diagnosis ──
              _sectionLabel(Icons.medical_services_outlined, 'Diagnosis'),
              const SizedBox(height: 8),
              Autocomplete<String>(
                optionsBuilder: (textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return _diagnosisSuggestions;
                  }
                  return _diagnosisSuggestions.where(
                    (s) => s.toLowerCase().contains(
                      textEditingValue.text.toLowerCase(),
                    ),
                  );
                },
                onSelected: (selection) {
                  _diagnosisController.text = selection;
                },
                fieldViewBuilder:
                    (context, textController, focusNode, onSubmit) {
                      textController.text = _diagnosisController.text;
                      textController.addListener(() {
                        _diagnosisController.text = textController.text;
                      });
                      return TextFormField(
                        controller: textController,
                        focusNode: focusNode,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Please enter a diagnosis'
                            : null,
                        decoration: _inputDeco('e.g., Diabetic Foot Ulcer'),
                      );
                    },
              ),
              const SizedBox(height: 24),

              // ── 3) Medications ──
              _sectionLabel(Icons.medication_outlined, 'Medications'),
              const SizedBox(height: 8),
              if (_medications.isNotEmpty)
                ..._medications.asMap().entries.map((entry) {
                  final i = entry.key;
                  final med = entry.value;
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.inputFill,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.inputBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                med['name'] ?? '',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                [
                                  if (med['dosage']!.isNotEmpty) med['dosage'],
                                  if (med['frequency']!.isNotEmpty)
                                    med['frequency'],
                                  if (med['duration']!.isNotEmpty)
                                    med['duration'],
                                ].join(' • '),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _medications.removeAt(i)),
                          child: const Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showAddMedicationDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Medication'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── 4) Additional Notes ──
              _sectionLabel(Icons.note_alt_outlined, 'Additional Notes'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                maxLines: 4,
                decoration: _inputDeco(
                  'e.g., Wound care instructions, follow-up schedule...',
                ),
              ),
              const SizedBox(height: 32),

              // ── Save ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _savePlan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                          'Create Treatment Plan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildPatientSelector() {
    final doctorId = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'patient')
          .where('doctorId', isEqualTo: doctorId)
          .snapshots(),
      builder: (context, snapshot) {
        final patients = snapshot.data?.docs ?? [];

        // Build dropdown items
        final items = patients.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'
              .trim();
          return DropdownMenuItem<String>(
            value: doc.id,
            child: Text(name.isNotEmpty ? name : 'Unknown'),
          );
        }).toList();

        return DropdownButtonFormField<String>(
          initialValue: _selectedPatientId,
          isExpanded: true,
          hint: const Text('Select a patient'),
          validator: (v) => v == null ? 'Please select a patient' : null,
          decoration: _inputDeco('Patient'),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.textSecondary,
          ),
          dropdownColor: Colors.white,
          items: items,
          onChanged: (id) {
            if (id == null) return;
            final doc = patients.firstWhere((d) => d.id == id);
            final data = doc.data() as Map<String, dynamic>;
            final name = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'
                .trim();
            setState(() {
              _selectedPatientId = id;
              _selectedPatientName = name;
            });
          },
        );
      },
    );
  }
}
