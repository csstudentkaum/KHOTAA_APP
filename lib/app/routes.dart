import 'package:flutter/material.dart';
import '../features/auth/splash_screen.dart';
import '../features/auth/patient/patient_login_screen.dart';
import '../features/auth/patient/patient_register_screen.dart';
import '../features/auth/patient/otp_screen.dart';
import '../features/auth/patient/registration_success_screen.dart';
import '../features/auth/doctor/doctor_login_screen.dart';
import '../features/doctor/home_screen.dart' as doctor;
import '../features/patient/patient_shell.dart';

/// Application routes configuration
class AppRoutes {
  AppRoutes._();

  /// Global navigator key for navigation from outside widget tree
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // Route names
  static const String splash = '/';
  static const String login = '/login';
  static const String patientRegister = '/patient/register';
  static const String patientOtp = '/patient/otp';
  static const String registrationSuccess = '/registration-success';
  static const String doctorLogin = '/doctor/login';
  static const String patientHome = '/patient-home';
  static const String doctorHome = '/doctor-home';

  /// Route map used by MaterialApp's `routes` parameter
  static Map<String, WidgetBuilder> get routes => {
    splash: (_) => const SplashScreen(),
    login: (_) => const PatientLoginScreen(),
    patientRegister: (_) => const PatientRegisterScreen(),
    patientOtp: (_) => const OtpScreen(),
    registrationSuccess: (_) => const RegistrationSuccessScreen(),
    doctorLogin: (_) => const DoctorLoginScreen(),
    patientHome: (_) => const PatientShell(),
    doctorHome: (_) => const doctor.DHomeScreen(),
  };
}
