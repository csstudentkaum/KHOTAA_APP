import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../app/app_theme.dart';

/// Screen for patients to enter/edit their medical information.
/// Uses dropdowns, chip selectors, and suggestions for easy input.
/// Data is stored directly in the 'users' collection document.
class MedicalInfoScreen extends StatefulWidget {
  const MedicalInfoScreen({super.key});

  @override
  State<MedicalInfoScreen> createState() => _MedicalInfoScreenState();
}

class _MedicalInfoScreenState extends State<MedicalInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otherAllergyController = TextEditingController();
  final _otherMedicationController = TextEditingController();
  final _otherConditionController = TextEditingController();
  final _additionalNotesController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  // ── Diabetes fields ──
  String? _diabetesType;
  String? _diagnosisYear;
  String? _insulinUsage;
  String? _hba1cLevel;

  // ── Medical History (multi-select chips) ──
  final Set<String> _selectedConditions = {};

  // ── Allergies (multi-select chips) ──
  final Set<String> _selectedAllergies = {};

  // ── Current Medications (multi-select chips) ──
  final Set<String> _selectedMedications = {};

  // ── Options ──
  static const _diabetesTypes = [
    'Type 1',
    'Type 2',
    'Gestational',
    'Prediabetes',
    'Other',
  ];

  static const _insulinOptions = [
    'Yes – Insulin Pump',
    'Yes – Injections',
    'No – Oral Medication Only',
    'No – Diet Controlled',
  ];

  static const _hba1cLevels = [
    'Below 5.7% (Normal)',
    '5.7% – 6.4% (Prediabetes)',
    '6.5% – 7.0% (Good Control)',
    '7.1% – 8.0% (Fair Control)',
    '8.1% – 9.0% (Poor Control)',
    'Above 9.0% (Very Poor Control)',
    'Not Sure',
  ];

  static const _conditionOptions = [
    'Hypertension',
    'Heart Disease',
    'High Cholesterol',
    'Kidney Disease',
    'Neuropathy',
    'Retinopathy',
    'Peripheral Artery Disease',
    'Thyroid Disorder',
    'Asthma',
    'Stroke',
    'Obesity',
    'Depression / Anxiety',
    'Previous Amputation',
    'Foot Ulcer History',
  ];

  static const _allergyOptions = [
    'Penicillin',
    'Sulfa Drugs',
    'Aspirin / NSAIDs',
    'Insulin',
    'Latex',
    'Iodine / Contrast Dye',
    'Adhesive / Tape',
    'No Known Allergies',
  ];

  static const _medicationOptions = [
    'Metformin',
    'Insulin Glargine (Lantus)',
    'Insulin Lispro (Humalog)',
    'Insulin Aspart (NovoRapid)',
    'Gliclazide',
    'Glimepiride',
    'Sitagliptin (Januvia)',
    'Empagliflozin (Jardiance)',
    'Dapagliflozin (Forxiga)',
    'Liraglutide (Victoza)',
    'Semaglutide (Ozempic)',
    'Pioglitazone',
    'Atorvastatin',
    'Amlodipine',
    'Losartan',
    'Aspirin (Low Dose)',
  ];

  List<String> get _yearOptions {
    final currentYear = DateTime.now().year;
    return List.generate(50, (i) => '${currentYear - i}');
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _otherAllergyController.dispose();
    _otherMedicationController.dispose();
    _otherConditionController.dispose();
    _additionalNotesController.dispose();
    super.dispose();
  }

  // ── Load existing data ──
  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data() ?? {};

        setState(() {
          _diabetesType = _safeDropdownValue(
            data['diabetesType'],
            _diabetesTypes,
          );
          _diagnosisYear = _safeDropdownValue(
            data['diagnosisYear'],
            _yearOptions,
          );
          _insulinUsage = _safeDropdownValue(
            data['insulinUsage'],
            _insulinOptions,
          );
          _hba1cLevel = _safeDropdownValue(data['hba1cLevel'], _hba1cLevels);

          _selectedConditions.addAll(_parseList(data['medicalHistory']));
          _selectedAllergies.addAll(_parseList(data['allergies']));
          _selectedMedications.addAll(_parseList(data['currentMedications']));
          _additionalNotesController.text =
              data['additionalMedicalNotes'] ?? '';

          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading medical info: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _safeDropdownValue(dynamic value, List<String> options) {
    if (value == null) return null;
    final str = value.toString();
    if (str.isEmpty) return null;
    if (options.contains(str)) return str;
    return null;
  }

  Set<String> _parseList(dynamic value) {
    if (value == null) return {};
    if (value is List) {
      return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toSet();
    }
    if (value is String && value.isNotEmpty) {
      return value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet();
    }
    return {};
  }

  // ── Save ──
  Future<void> _saveData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      final diabetesHistoryParts = <String>[];
      if (_diabetesType != null) diabetesHistoryParts.add(_diabetesType!);
      if (_diagnosisYear != null) {
        diabetesHistoryParts.add('Diagnosed in $_diagnosisYear');
      }
      if (_insulinUsage != null) {
        diabetesHistoryParts.add('Insulin: $_insulinUsage');
      }
      if (_hba1cLevel != null) {
        diabetesHistoryParts.add('HbA1c: $_hba1cLevel');
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'diabetesType': _diabetesType ?? '',
            'diagnosisYear': _diagnosisYear ?? '',
            'insulinUsage': _insulinUsage ?? '',
            'hba1cLevel': _hba1cLevel ?? '',
            'diabetesHistory': diabetesHistoryParts.join('  •  '),
            'medicalHistory': _selectedConditions.toList(),
            'allergies': _selectedAllergies.toList(),
            'currentMedications': _selectedMedications.toList(),
            'additionalMedicalNotes': _additionalNotesController.text.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medical information saved successfully'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving medical info: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ═══════════════════════════════════════════════════
  // ══  BUILD
  // ═══════════════════════════════════════════════════
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
          'Medical Information',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: AppColors.primary,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoBanner(),
                    const SizedBox(height: 24),

                    // ── 1) Diabetes History ──
                    _buildSectionHeader(
                      Icons.bloodtype_outlined,
                      'Diabetes History',
                    ),
                    const SizedBox(height: 12),
                    _buildDropdown(
                      label: 'Diabetes Type',
                      value: _diabetesType,
                      items: _diabetesTypes,
                      onChanged: (v) => setState(() => _diabetesType = v),
                    ),
                    const SizedBox(height: 12),
                    _buildDropdown(
                      label: 'Year of Diagnosis',
                      value: _diagnosisYear,
                      items: _yearOptions,
                      onChanged: (v) => setState(() => _diagnosisYear = v),
                    ),
                    const SizedBox(height: 12),
                    _buildDropdown(
                      label: 'Insulin Usage',
                      value: _insulinUsage,
                      items: _insulinOptions,
                      onChanged: (v) => setState(() => _insulinUsage = v),
                    ),
                    const SizedBox(height: 12),
                    _buildDropdown(
                      label: 'Latest HbA1c Level',
                      value: _hba1cLevel,
                      items: _hba1cLevels,
                      onChanged: (v) => setState(() => _hba1cLevel = v),
                    ),
                    const SizedBox(height: 28),

                    // ── 2) Medical History ──
                    _buildSectionHeader(
                      Icons.history_outlined,
                      'Medical History',
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Select all conditions that apply:',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildChipSelector(
                      options: _conditionOptions,
                      selected: _selectedConditions,
                    ),
                    const SizedBox(height: 8),
                    _buildAddOtherField(
                      controller: _otherConditionController,
                      hint: 'Add other condition...',
                      onAdd: (val) {
                        setState(() => _selectedConditions.add(val));
                        _otherConditionController.clear();
                      },
                    ),
                    const SizedBox(height: 28),

                    // ── 3) Allergies ──
                    _buildSectionHeader(
                      Icons.warning_amber_outlined,
                      'Allergies',
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Select all allergies that apply:',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildChipSelector(
                      options: _allergyOptions,
                      selected: _selectedAllergies,
                      isExclusive: 'No Known Allergies',
                    ),
                    const SizedBox(height: 8),
                    _buildAddOtherField(
                      controller: _otherAllergyController,
                      hint: 'Add other allergy...',
                      onAdd: (val) {
                        setState(() {
                          _selectedAllergies.remove('No Known Allergies');
                          _selectedAllergies.add(val);
                        });
                        _otherAllergyController.clear();
                      },
                    ),
                    const SizedBox(height: 28),

                    // ── 4) Current Medications ──
                    _buildSectionHeader(
                      Icons.medication_outlined,
                      'Current Medications',
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Select all medications you currently take:',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildChipSelector(
                      options: _medicationOptions,
                      selected: _selectedMedications,
                    ),
                    const SizedBox(height: 8),
                    _buildAddOtherField(
                      controller: _otherMedicationController,
                      hint: 'Add other medication...',
                      onAdd: (val) {
                        setState(() => _selectedMedications.add(val));
                        _otherMedicationController.clear();
                      },
                    ),
                    const SizedBox(height: 28),

                    // ── 5) Additional Notes ──
                    _buildSectionHeader(
                      Icons.note_alt_outlined,
                      'Additional Notes',
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Anything else your doctor should know:',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _additionalNotesController,
                      maxLines: 3,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText:
                            'e.g., Recent foot injury, numbness in feet...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: AppColors.textHint.withAlpha(150),
                        ),
                        filled: true,
                        fillColor: AppColors.inputFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.inputBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.inputBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Save button ──
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveData,
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
                                'Save',
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

  // ═══════════════════════════════════════════════════
  // ══  WIDGETS
  // ═══════════════════════════════════════════════════

  Widget _buildInfoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withAlpha(40)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'This information will be visible to your doctor to provide better care.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
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

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
        filled: true,
        fillColor: AppColors.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: AppColors.textSecondary,
      ),
      dropdownColor: Colors.white,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      items: items
          .map(
            (e) => DropdownMenuItem(
              value: e,
              child: Text(e, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildChipSelector({
    required List<String> options,
    required Set<String> selected,
    String? isExclusive,
  }) {
    final allOptions = [...options];
    for (final s in selected) {
      if (!allOptions.contains(s)) allOptions.add(s);
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: allOptions.map((option) {
        final isSelected = selected.contains(option);
        final isExclusiveOption = option == isExclusive;

        return FilterChip(
          label: Text(
            option,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? Colors.white : AppColors.textPrimary,
            ),
          ),
          selected: isSelected,
          onSelected: (val) {
            setState(() {
              if (val) {
                if (isExclusiveOption) {
                  selected.clear();
                  selected.add(option);
                } else {
                  selected.remove(isExclusive);
                  selected.add(option);
                }
              } else {
                selected.remove(option);
              }
            });
          },
          selectedColor: AppColors.primary,
          backgroundColor: AppColors.inputFill,
          checkmarkColor: Colors.white,
          side: BorderSide(
            color: isSelected ? AppColors.primary : AppColors.inputBorder,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        );
      }).toList(),
    );
  }

  Widget _buildAddOtherField({
    required TextEditingController controller,
    required String hint,
    required ValueChanged<String> onAdd,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: 13,
                color: AppColors.textHint.withAlpha(150),
              ),
              filled: true,
              fillColor: AppColors.inputFill,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.inputBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.inputBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            onSubmitted: (val) {
              if (val.trim().isNotEmpty) onAdd(val.trim());
            },
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              final val = controller.text.trim();
              if (val.isNotEmpty) onAdd(val);
            },
            child: const SizedBox(
              width: 42,
              height: 42,
              child: Icon(Icons.add, color: Colors.white, size: 20),
            ),
          ),
        ),
      ],
    );
  }
}
