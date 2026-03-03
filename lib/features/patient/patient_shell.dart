import 'package:flutter/material.dart';
// ...existing code...
import 'patient_home_page.dart';

/// Patient shell - bottom tabs holder
/// TODO: Implement patient shell with bottom navigation
class PatientShell extends StatelessWidget {
  const PatientShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const PatientHomePage();
  }
}
