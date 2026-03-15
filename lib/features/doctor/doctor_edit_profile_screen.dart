import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../app/app_theme.dart';

/// Doctor Edit Profile screen
class DoctorEditProfileScreen extends StatefulWidget {
  const DoctorEditProfileScreen({super.key});

  @override
  State<DoctorEditProfileScreen> createState() =>
      _DoctorEditProfileScreenState();
}

class _DoctorEditProfileScreenState extends State<DoctorEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _hospitalCtrl = TextEditingController();
  String? _specialtyLevel;
  String? _degree;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _hospitalCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _firstNameCtrl.text = data['firstName'] ?? '';
          _lastNameCtrl.text = data['lastName'] ?? '';
          _hospitalCtrl.text = data['hospitalName'] ?? '';
          _specialtyLevel = data['specialtyLevel'];
          _degree = data['degree'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final updates = <String, dynamic>{
        'firstName': _firstNameCtrl.text.trim(),
        'lastName': _lastNameCtrl.text.trim(),
        'hospitalName': _hospitalCtrl.text.trim(),
        'updatedAt': Timestamp.now(),
      };

      if (_specialtyLevel != null) updates['specialtyLevel'] = _specialtyLevel;
      if (_degree != null) updates['degree'] = _degree;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(updates);

      final fullName =
          '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}'.trim();
      await user.updateDisplayName(fullName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

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
          'Edit Profile',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Center(
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: AppColors.primary.withAlpha(30),
                        child: Text(
                          _firstNameCtrl.text.isNotEmpty
                              ? _firstNameCtrl.text[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // First Name
                    _buildLabel('First Name'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _firstNameCtrl,
                      decoration: _inputDecoration('Enter first name'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),

                    // Last Name
                    _buildLabel('Last Name'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _lastNameCtrl,
                      decoration: _inputDecoration('Enter last name'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),

                    // Specialty Level
                    _buildLabel('Specialty'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _specialtyLevel,
                      decoration: _inputDecoration('Select specialty'),
                      items: const [
                        DropdownMenuItem(
                          value: 'General',
                          child: Text('General'),
                        ),
                        DropdownMenuItem(
                          value: 'Podiatrist',
                          child: Text('Podiatrist'),
                        ),
                        DropdownMenuItem(
                          value: 'Endocrinologist',
                          child: Text('Endocrinologist'),
                        ),
                        DropdownMenuItem(
                          value: 'Orthopedic',
                          child: Text('Orthopedic'),
                        ),
                        DropdownMenuItem(
                          value: 'Dermatologist',
                          child: Text('Dermatologist'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _specialtyLevel = v),
                    ),
                    const SizedBox(height: 20),

                    // Degree
                    _buildLabel('Degree'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _degree,
                      decoration: _inputDecoration('Select degree'),
                      items: const [
                        DropdownMenuItem(value: 'MD', child: Text('MD')),
                        DropdownMenuItem(value: 'MBBS', child: Text('MBBS')),
                        DropdownMenuItem(value: 'DO', child: Text('DO')),
                        DropdownMenuItem(value: 'PhD', child: Text('PhD')),
                        DropdownMenuItem(
                          value: 'Consultant',
                          child: Text('Consultant'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _degree = v),
                    ),
                    const SizedBox(height: 20),

                    // Hospital
                    _buildLabel('Hospital / Clinic'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _hospitalCtrl,
                      decoration: _inputDecoration(
                        'Enter hospital or clinic name',
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor: AppColors.primary.withAlpha(
                            120,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(
                                  color: Colors.white,
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

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textHint),
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
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
