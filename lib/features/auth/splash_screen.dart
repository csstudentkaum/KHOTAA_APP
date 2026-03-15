import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import '../../services/firebase/auth_service.dart';
import '../../shared/widgets/khotaa_logo.dart';

/// Splash screen — teal background with the KHOTAA logo.
/// Auto-navigates after 2.5 s: if logged in → appropriate home based on role, else → login.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;

    if (_authService.isLoggedIn) {
      // Determine role and navigate to the correct home
      try {
        final role = await _authService.getCurrentUserRole();
        if (!mounted) return;
        if (role == 'doctor') {
          Navigator.pushReplacementNamed(context, '/doctor-home');
        } else {
          Navigator.pushReplacementNamed(context, '/patient-home');
        }
      } catch (_) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
      }
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var children = [
      // Logo
      const KhotaaLogo(size: 90, padding: 12),
      const SizedBox(height: 16),
      // KHOTAA text
      const Text(
        'K H O T A A',
        style: TextStyle(fontSize: 28, color: Colors.white, letterSpacing: 6),
      ),
      const SizedBox(height: 8),
      Text(
        'Smart Diabetic Foot Care',
        style: TextStyle(
          letterSpacing: 1.5,
          fontSize: 14,
          fontWeight: FontWeight.w300,
          color: Colors.white.withAlpha(180),
        ),
      ),
      const SizedBox(height: 40),
    ];
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primary, Color(0xFF467EA1)],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}
