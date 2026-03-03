import 'package:flutter/material.dart';
import '../features/auth/splash_screen.dart';
import '../features/auth/patient/otp_screen.dart';
import '../features/auth/patient/registration_success_screen.dart';
import '../features/auth/patient/patient_login_screen.dart';
import '../features/auth/patient/patient_register_screen.dart';
import '../features/auth/doctor/doctor_login_screen.dart';
import '../features/patient/patient_shell.dart';
import '../features/doctor/doctor_shell.dart';

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

  // Patient auth routes
  static const String patientLogin = '/patient/login';
  static const String patientRegister = '/patient/register';
  static const String patientOtp = '/patient/otp';

  // Doctor auth routes
  static const String doctorLogin = '/doctor/login';

  /// Route map used by MaterialApp's `routes` parameter
  static Map<String, WidgetBuilder> get routes => {
        splash: (_) => const SplashScreen(),
        // Main login points to patient login (default)
        login: (_) => const PatientLoginScreen(),
        register: (_) => const PatientRegisterScreen(),
        otp: (_) => const OtpScreen(),
        registrationSuccess: (_) => const RegistrationSuccessScreen(),
        patientHome: (_) => const PatientShell(),
        doctorHome: (_) => const DoctorShell(),

        // Patient routes
        patientLogin: (_) => const PatientLoginScreen(),
        patientRegister: (_) => const PatientRegisterScreen(),
        patientOtp: (_) => const OtpScreen(), // Reuse existing OTP screen

        // Doctor routes
        doctorLogin: (_) => const DoctorLoginScreen(),
      };
}
