import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/app_theme.dart';
import '../../../services/firebase/auth_service.dart';

/// OTP verification screen.
///
/// Receives route arguments:
///   - verificationId (String)
///   - phoneNumber (String)
///   - isLogin (bool) — true = login flow, false = registration flow
///   - role (String) — 'patient' or 'doctor'
///   - Registration-only fields: firstName, lastName, gender,
///     specialtyLevel, degree, hospitalName
///   [PASSWORD_FEATURE] Also receives: password
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _authService = AuthService();
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  String? _errorMessage;

  // Countdown for resend
  int _secondsLeft = 60;
  Timer? _timer;

  // Arguments from previous screen
  late String _verificationId;
  late String _phoneNumber;
  late bool _isLogin;
  late String _role;
  Map<String, dynamic> _registrationData = {};

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _verificationId = args['verificationId'] as String;
      _phoneNumber = args['phoneNumber'] as String;
      _isLogin = args['isLogin'] as bool? ?? false;
      _role = args['role'] as String? ?? 'patient';
      _registrationData = args;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft == 0) {
        timer.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  String _getOtpCode() {
    return _controllers.map((c) => c.text).join();
  }

  Future<void> _verifyOtp() async {
    final code = _getOtpCode();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter the full 6-digit code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Verify OTP → signs into Firebase Auth
      await _authService.verifyOTP(
        verificationId: _verificationId,
        otp: code,
      );

      if (!mounted) return;

      if (_isLogin) {
        // Login flow – user already exists, just navigate
        final role = _registrationData['role'] as String? ?? 'patient';
        _navigateToHome(role);
      } else {
        // Registration flow – save profile to Firestore
        await _completeRegistration();
      }
    } catch (e) {
      debugPrint('OTP verification error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = _parseError(e);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _completeRegistration() async {
    try {
      if (_role == 'doctor') {
        await _authService.completeDoctorRegistration(
          // [PASSWORD_FEATURE] password: _registrationData['password'] as String,
          firstName: _registrationData['firstName'] as String,
          lastName: _registrationData['lastName'] as String,
          phone: _phoneNumber,
          gender: _registrationData['gender'] as String?,
          specialtyLevel: _registrationData['specialtyLevel'] as String?,
          degree: _registrationData['degree'] as String?,
          hospitalName: _registrationData['hospitalName'] as String?,
        );
      } else {
        await _authService.completePatientRegistration(
          // [PASSWORD_FEATURE] password: _registrationData['password'] as String,
          firstName: _registrationData['firstName'] as String,
          lastName: _registrationData['lastName'] as String,
          phone: _phoneNumber,
          gender: _registrationData['gender'] as String?,
        );
      }

      if (!mounted) return;

      // After registration, sign out and show success screen
      // so the user logs in fresh with their new phone number.
      await _authService.signOut();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context, '/registration-success', (route) => false);
    } catch (e) {
      debugPrint('Registration completion error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToHome(String role) {
    final route = role == 'doctor' ? '/doctor-home' : '/patient-home';
    Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
  }

  Future<void> _resendOtp() async {
    if (_secondsLeft > 0) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Clear old code
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();

    try {
      await _authService.sendOTP(
        phoneNumber: _phoneNumber,
        onCodeSent: (verificationId, resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _isLoading = false;
          });
          _startCountdown();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('A new code has been sent.'),
              backgroundColor: AppColors.success,
            ),
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
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _parseError(dynamic e) {
    final msg = e.toString();
    if (msg.contains('invalid-verification-code')) {
      return 'Invalid code. Please check and try again.';
    }
    if (msg.contains('session-expired')) {
      return 'Code expired. Please request a new one.';
    }
    return 'Verification failed. Please try again.';
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
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  const Icon(Icons.sms_outlined,
                      size: 64, color: AppColors.primary),
                  const SizedBox(height: 16),
                  const Text(
                    'Verify Your Phone',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We sent a 6-digit code to\n$_phoneNumber',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ─── Error banner ───
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: AppColors.error.withAlpha(76)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppColors.error, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_errorMessage!,
                                style: const TextStyle(
                                    color: AppColors.error, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ─── OTP input boxes ───
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(6, (index) => _buildOtpBox(index)),
                  ),
                  const SizedBox(height: 32),

                  // ─── Verify button ───
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verifyOtp,
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Text('Verify'),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ─── Resend / countdown ───
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Didn't receive the code? ",
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 14)),
                      GestureDetector(
                        onTap: _secondsLeft == 0 ? _resendOtp : null,
                        child: Text(
                          _secondsLeft > 0
                              ? 'Resend in ${_secondsLeft}s'
                              : 'Resend',
                          style: TextStyle(
                            color: _secondsLeft > 0
                                ? AppColors.textHint
                                : AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ─── Back link ───
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Go Back'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 48,
      height: 56,
      child: TextFormField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: AppColors.inputFill,
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.inputBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
          // Auto-submit when all 6 digits entered
          if (_getOtpCode().length == 6) {
            _verifyOtp();
          }
        },
      ),
    );
  }

  Widget _buildHeader(Size size) {
    return ClipPath(
      clipper: _OtpHeaderClipper(),
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
          child: Stack(
            children: [
              Positioned(
                top: 4,
                left: 4,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/khotaa_logo_white.png',
                      width: 60,
                      height: 60,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'KHOTAA',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OtpHeaderClipper extends CustomClipper<Path> {
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
