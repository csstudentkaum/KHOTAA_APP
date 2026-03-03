import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Service for sending doctor activation emails via the KHOTAA email server.
///
/// This service communicates with a Vercel-hosted backend that uses
/// Resend to send branded activation emails to doctors.
///
/// Flow:
///   1. Admin creates doctor account in Firebase
///   2. This service sends activation email via the backend
///   3. Doctor clicks link in email → sets password on branded web page
///   4. Doctor's account is activated (isActive: true) automatically
///   5. Doctor logs in via the app
class EmailService {
  // Read from .env file at runtime (no secrets in code!)
  static String get _baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'https://khotaa-email-server.vercel.app';

  static String get _apiSecret => dotenv.env['API_SECRET'] ?? '';

  /// Send a doctor activation email.
  ///
  /// [doctorName] — Doctor's full name (e.g., "Ahmed Ali")
  /// [doctorEmail] — Doctor's email address
  /// [uid] — Firebase Auth UID of the doctor
  ///
  /// Returns true on success, throws on failure.
  static Future<bool> sendActivationEmail({
    required String doctorName,
    required String doctorEmail,
    required String uid,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/send-activation'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiSecret',
        },
        body: jsonEncode({
          'doctorName': doctorName,
          'doctorEmail': doctorEmail,
          'uid': uid,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Activation email sent: ${data['emailId']}');
        return true;
      } else {
        final data = jsonDecode(response.body);
        final error = data['error'] ?? 'Unknown error';
        debugPrint('Failed to send activation email: $error');
        throw Exception(error);
      }
    } catch (e) {
      debugPrint('EmailService error: $e');
      rethrow;
    }
  }
}
