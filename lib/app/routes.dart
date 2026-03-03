import 'package:flutter/material.dart';
import '../features/auth/splash_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/otp_screen.dart';
import '../features/auth/registration_success_screen.dart';
import '../features/patient/patient_shell.dart';
import '../features/doctor/doctor_shell.dart';
import '../features/patient/weekly_report_screen.dart';

/// Application routes configuration
class AppRoutes {
  AppRoutes._();

  // Route names
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String otp = '/otp';
  static const String registrationSuccess = '/registration-success';
  static const String patientHome = '/patient-home';
  static const String doctorHome = '/doctor-home';
  static const String weeklyReport = '/weekly-report';

  /// Route map used by MaterialApp's `routes` parameter
  static Map<String, WidgetBuilder> get routes => {
        splash: (_) => const SplashScreen(),
        login: (_) => const LoginScreen(),
        register: (_) => const RegisterScreen(),
        otp: (_) => const OtpScreen(),
        registrationSuccess: (_) => const RegistrationSuccessScreen(),
        patientHome: (_) => const PatientShell(),
        doctorHome: (_) => const DoctorShell(),
        weeklyReport: (_) => const WeeklyReportScreen(),
      };
}
