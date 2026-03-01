import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import '../../services/firebase/auth_service.dart';
import '../../shared/formatters/phone_formatter.dart';

/// Login screen — Phone number → OTP verification (passwordless).
///
/// Flow:
///   1. User enters phone number
///   2. Phone is checked against Firestore (must be registered)
///   3. OTP is sent to the phone number
///   4. Navigates to OTP screen for verification
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  // [PASSWORD_FEATURE] final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  // [PASSWORD_FEATURE] bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    // [PASSWORD_FEATURE] _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Step 1: Check if phone is registered in Firestore
      final localNumber = _phoneController.text.trim().replaceAll(RegExp(r'\s'), '');
      final phone = '+966$localNumber';

      if (phone.isEmpty) {
        setState(() {
          _errorMessage = 'Please enter a valid phone number.';
          _isLoading = false;
        });
        return;
      }

      final userData = await _authService.findUserByPhone(
        phone: phone,
      );

      // [PASSWORD_FEATURE] Uncomment below to re-enable password verification:
      // final userData = await _authService.verifyPasswordForLogin(
      //   phone: phone,
      //   password: _passwordController.text,
      // );

      if (userData == null) {
        setState(() {
          _errorMessage = 'This phone number is not registered.';
          _isLoading = false;
        });
        return;
      }

      if (!mounted) return;

      // Step 2: Send OTP to the phone number
      await _authService.sendOTP(
        phoneNumber: phone,
        onCodeSent: (verificationId, resendToken) {
          if (!mounted) return;
          setState(() => _isLoading = false);

          // Navigate to OTP screen
          Navigator.pushNamed(
            context,
            '/otp',
            arguments: {
              'verificationId': verificationId,
              'phoneNumber': phone,
              'isLogin': true,
              'role': userData['role'],
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
      debugPrint('Login error: $e');
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
                    const SizedBox(height: 32),
                    const Text(
                      'Welcome Back',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Sign in with your phone number',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Error banner
                    if (_errorMessage != null) ...[
                      _buildErrorBanner(_errorMessage!),
                      const SizedBox(height: 16),
                    ],

                    // Phone field
                    _buildLabel('Phone Number'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [SaudiPhoneFormatter()],
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: '5X XXX XXXX',
                        prefixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(width: 16),
                            const Text('\u{1F1F8}\u{1F1E6}', style: TextStyle(fontSize: 16, height: 1)),
                            const SizedBox(width: 8),
                            Text('+966 ',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.textPrimary,
                                  height: 1,
                                )),
                          ],
                        ),
                        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your phone number';
                        }
                        final cleaned =
                            value.trim().replaceAll(RegExp(r'\s'), '');
                        if (!RegExp(r'^5\d{8}$').hasMatch(cleaned)) {
                          return 'Enter a valid Saudi number (e.g. 5XXXXXXXX)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),

                    // [PASSWORD_FEATURE] Password field — uncomment to re-enable.
                    // _buildLabel('Password'),
                    // const SizedBox(height: 8),
                    // TextFormField(
                    //   controller: _passwordController,
                    //   obscureText: _obscurePassword,
                    //   textInputAction: TextInputAction.done,
                    //   onFieldSubmitted: (_) => _handleLogin(),
                    //   decoration: InputDecoration(
                    //     hintText: 'Enter your password',
                    //     prefixIcon: const Icon(Icons.lock_outline,
                    //         color: AppColors.primary),
                    //     suffixIcon: IconButton(
                    //       icon: Icon(
                    //         _obscurePassword
                    //             ? Icons.visibility_off_outlined
                    //             : Icons.visibility_outlined,
                    //         color: AppColors.textHint,
                    //       ),
                    //       onPressed: () => setState(
                    //           () => _obscurePassword = !_obscurePassword),
                    //     ),
                    //   ),
                    //   validator: (v) =>
                    //       v == null || v.isEmpty ? 'Please enter your password' : null,
                    // ),
                    // const SizedBox(height: 28),

                    // Sign In button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white),
                              )
                            : const Text('Sign In'),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Navigate to register
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don't have an account? ",
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 14)),
                        GestureDetector(
                          onTap: () => Navigator.pushReplacementNamed(
                              context, '/register'),
                          child: const Text(
                            'Sign Up',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Size size) {
    return ClipPath(
      clipper: _HeaderClipper(),
      child: Container(
        height: size.height * 0.32,
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
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite, size: 44, color: Colors.white),
              ),
              const SizedBox(height: 12),
              const Text(
                'KHOTAA',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(text,
      style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: AppColors.textPrimary));

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
}

class _HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..lineTo(0, size.height - 40)
      ..quadraticBezierTo(
          size.width / 2, size.height + 20, size.width, size.height - 40)
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
