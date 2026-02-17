import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import '../../services/firebase/auth_service.dart';

/// Register screen — Phone + Password + OTP verification.
///
/// Flow:
///   1. User fills: name, phone, gender, password (+ doctor fields if doctor)
///   2. Taps "Sign Up" → OTP is sent to phone
///   3. Navigates to OTP screen → after OTP verified → profile saved to Firestore
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Doctor-specific
  final _specialtyController = TextEditingController();
  final _degreeController = TextEditingController();
  final _hospitalController = TextEditingController();

  final _authService = AuthService();

  String _selectedRole = 'patient';
  String? _selectedGender;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Update password hints in real-time as user types
    _passwordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _specialtyController.dispose();
    _degreeController.dispose();
    _hospitalController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final phone = _phoneController.text.trim();

      // Check if phone is already registered
      final alreadyExists = await _authService.isPhoneRegistered(phone);
      if (alreadyExists) {
        setState(() {
          _errorMessage = 'This phone number is already registered.';
          _isLoading = false;
        });
        return;
      }

      if (!mounted) return;

      // Send OTP to the phone number
      await _authService.sendOTP(
        phoneNumber: phone,
        onCodeSent: (verificationId, resendToken) {
          if (!mounted) return;
          setState(() => _isLoading = false);

          // Navigate to OTP screen with all the registration data
          Navigator.pushNamed(
            context,
            '/otp',
            arguments: {
              'verificationId': verificationId,
              'phoneNumber': phone,
              'isLogin': false,
              'role': _selectedRole,
              'firstName': _firstNameController.text.trim(),
              'lastName': _lastNameController.text.trim(),
              'password': _passwordController.text,
              'gender': _selectedGender,
              // Doctor fields
              if (_selectedRole == 'doctor') ...{
                'specialtyLevel': _specialtyController.text.trim(),
                'degree': _degreeController.text.trim(),
                'hospitalName': _hospitalController.text.trim(),
              },
            },
          );
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _errorMessage = error;
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      debugPrint('Registration error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(size),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    const Text('Create Account',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    const Text('Fill in your details to get started',
                        style: TextStyle(
                            fontSize: 14, color: AppColors.textSecondary)),
                    const SizedBox(height: 20),

                    // Role toggle
                    _buildRoleToggle(),
                    const SizedBox(height: 20),

                    // Error banner
                    if (_errorMessage != null) ...[
                      _buildErrorBanner(_errorMessage!),
                      const SizedBox(height: 16),
                    ],

                    // Name row
                    Row(
                      children: [
                        Expanded(
                          child: _buildField(
                            'First Name',
                            TextFormField(
                              controller: _firstNameController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                hintText: 'First name',
                                prefixIcon: Icon(Icons.person_outline,
                                    color: AppColors.primary),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Required'
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildField(
                            'Last Name',
                            TextFormField(
                              controller: _lastNameController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                hintText: 'Last name',
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Required'
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Phone
                    _buildField(
                      'Phone Number',
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: '+966 5XX XXX XXXX',
                          prefixIcon: Icon(Icons.phone_outlined,
                              color: AppColors.primary),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your phone number';
                          }
                          final cleaned =
                              value.trim().replaceAll(RegExp(r'\s'), '');
                          if (!RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(cleaned)) {
                            return 'Enter valid number with country code (e.g. +966...)';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Gender
                    _buildField(
                      'Gender',
                      DropdownButtonFormField<String>(
                        value: _selectedGender,
                        decoration: const InputDecoration(
                          hintText: 'Select gender',
                          prefixIcon:
                              Icon(Icons.wc_outlined, color: AppColors.primary),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                          DropdownMenuItem(
                              value: 'Female', child: Text('Female')),
                        ],
                        onChanged: (v) => setState(() => _selectedGender = v),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Doctor-specific fields
                    if (_selectedRole == 'doctor') ...[
                      _buildField(
                        'Specialty',
                        TextFormField(
                          controller: _specialtyController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Endocrinologist',
                            prefixIcon: Icon(Icons.medical_services_outlined,
                                color: AppColors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildField(
                        'Degree',
                        TextFormField(
                          controller: _degreeController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            hintText: 'e.g. MD, PhD',
                            prefixIcon: Icon(Icons.school_outlined,
                                color: AppColors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildField(
                        'Hospital Name',
                        TextFormField(
                          controller: _hospitalController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            hintText: 'Hospital / Clinic name',
                            prefixIcon: Icon(Icons.local_hospital_outlined,
                                color: AppColors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Password with strong policy
                    _buildField(
                      'Password',
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: 'Strong password required',
                          prefixIcon: const Icon(Icons.lock_outline,
                              color: AppColors.primary),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppColors.textHint,
                            ),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a password';
                          }
                          return AuthService.validatePassword(value);
                        },
                      ),
                    ),

                    // Password strength hints
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _passwordHint('At least 8 characters',
                              _passwordController.text.length >= 8),
                          _passwordHint('One uppercase letter (A-Z)',
                              RegExp(r'[A-Z]').hasMatch(_passwordController.text)),
                          _passwordHint('One lowercase letter (a-z)',
                              RegExp(r'[a-z]').hasMatch(_passwordController.text)),
                          _passwordHint('One number (0-9)',
                              RegExp(r'[0-9]').hasMatch(_passwordController.text)),
                          _passwordHint('One special character (!@#\$%^&*)',
                              RegExp(r'[!@#$%^&*(),.?":{}|<>]')
                                  .hasMatch(_passwordController.text)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Confirm password
                    _buildField(
                      'Confirm Password',
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirm,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _handleRegister(),
                        decoration: InputDecoration(
                          hintText: 'Re-enter password',
                          prefixIcon: const Icon(Icons.lock_outline,
                              color: AppColors.primary),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppColors.textHint,
                            ),
                            onPressed: () => setState(
                                () => _obscureConfirm = !_obscureConfirm),
                          ),
                        ),
                        validator: (value) {
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Sign Up button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleRegister,
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white),
                              )
                            : const Text('Sign Up'),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Navigate to login
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Already have an account? ',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 14)),
                        GestureDetector(
                          onTap: () => Navigator.pushReplacementNamed(
                              context, '/login'),
                          child: const Text(
                            'Sign In',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Reusable widgets ───

  Widget _buildHeader(Size size) {
    return ClipPath(
      clipper: _HeaderClipper(),
      child: Container(
        height: size.height * 0.22,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primary, AppColors.primaryDark],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.favorite, size: 32, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text('KHOTAA',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 4)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.inputBorder),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _roleTab('Patient', 'patient', Icons.person_outline),
          _roleTab('Doctor', 'doctor', Icons.medical_services_outlined),
        ],
      ),
    );
  }

  Widget _roleTab(String label, String role, IconData icon) {
    final isSelected = _selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 20,
                  color:
                      isSelected ? Colors.white : AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, Widget field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        field,
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withAlpha(76)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: AppColors.error, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _passwordHint(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.circle_outlined,
            size: 14,
            color: met ? AppColors.success : AppColors.textHint,
          ),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                  fontSize: 12,
                  color: met ? AppColors.success : AppColors.textHint)),
        ],
      ),
    );
  }
}

class _HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..lineTo(0, size.height - 30)
      ..quadraticBezierTo(
          size.width / 2, size.height + 15, size.width, size.height - 30)
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
