import 'package:flutter/material.dart';
import '../features/auth/splash_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/otp_screen.dart';
import '../features/doctor/home_screen.dart' as doctor;
import '../features/patient/patient_shell.dart';

/// Application routes configuration
class AppRoutes {
  AppRoutes._();

  // Route names
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String otp = '/otp';
  static const String patientHome = '/patient-home';
  static const String doctorHome = '/doctor-home';

  /// Route map used by MaterialApp's `routes` parameter
  static Map<String, WidgetBuilder> get routes => {
    splash: (_) => const SplashScreen(),
    login: (_) => const LoginScreen(),
    register: (_) => const RegisterScreen(),
    otp: (_) => const OtpScreen(),
    patientHome: (_) => const PatientShell(),
    doctorHome: (_) => const doctor.DHomeScreen(),
  };
}
