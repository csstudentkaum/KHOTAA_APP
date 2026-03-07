import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/patient_model.dart';
import '../../models/doctor_model.dart';
import '../../models/user_model.dart';

/// Firebase Authentication service using **Phone + OTP + Password**.
///
/// Flow:
///   Registration:
///     1. User fills form (phone, password, name, etc.)
///     2. OTP is sent to their phone via Firebase Phone Auth
///     3. User enters OTP → verified → Firebase Auth user created
///     4. Password hash + profile saved to Firestore
///
///   Login:
///     1. User enters phone + password
///     2. Password verified against Firestore hash
///     3. OTP sent to phone for identity verification
///     4. User enters OTP → signed in
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ==================== AUTH STATE ====================

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  bool get isLoggedIn => _auth.currentUser != null;

  // ==================== PASSWORD HASHING ====================

  /// Hash a password using SHA-256
  /// In production, consider using bcrypt via a Cloud Function
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verify a password against a stored hash
  bool _verifyPassword(String password, String storedHash) {
    return _hashPassword(password) == storedHash;
  }

  // ==================== PASSWORD VALIDATION ====================

  /// Validate password strength according to requirements:
  /// - At least 8 characters
  /// - At least one uppercase letter
  /// - At least one lowercase letter
  /// - At least one digit
  /// - At least one special character
  static String? validatePassword(String password) {
    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Password must contain at least one number';
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      return 'Password must contain at least one special character (!@#\$%^&*)';
    }
    return null; // Valid
  }

  // ==================== PHONE OTP VERIFICATION ====================

  /// Send OTP to a phone number.
  /// [onCodeSent] is called with the verificationId to use later.
  /// [onError] is called if something goes wrong.
  /// [onAutoVerified] is called if the device auto-verifies (Android).
  Future<void> sendOTP({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(String error) onError,
    Function(PhoneAuthCredential credential)? onAutoVerified,
    int? forceResendingToken,
  }) async {
    // Ensure app verification is disabled for testing on simulator
    // This MUST be set right before verifyPhoneNumber to avoid race conditions
    if (kDebugMode) {
      await _auth.setSettings(appVerificationDisabledForTesting: true);
      debugPrint('  appVerificationDisabledForTesting set to true before OTP');
    }

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      forceResendingToken: forceResendingToken,
      verificationCompleted: (PhoneAuthCredential credential) {
        // Android auto-verification
        debugPrint('Phone auto-verified');
        onAutoVerified?.call(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        debugPrint('Phone verification failed: ${e.code} - ${e.message}');
        onError(getErrorMessage(e.code));
      },
      codeSent: (String verificationId, int? resendToken) {
        debugPrint('OTP code sent to $phoneNumber');
        onCodeSent(verificationId, resendToken);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        debugPrint('OTP auto-retrieval timeout');
      },
    );
  }

  /// Verify the OTP code and sign in.
  /// Returns the [UserCredential] on success.
  Future<UserCredential> verifyOTP({
    required String verificationId,
    required String otp,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: otp,
    );
    return await _auth.signInWithCredential(credential);
  }

  // ==================== REGISTRATION ====================

  /// Complete patient registration after OTP verification.
  /// Call this AFTER [verifyOTP] succeeds.
  Future<void> completePatientRegistration({
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    DateTime? dateOfBirth,
    String? gender,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    final patient = PatientModel(
      id: user.uid,
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      phone: phone.trim(),
      dateOfBirth: dateOfBirth,
      gender: gender,
      createdAt: DateTime.now(),
    );

    final data = patient.toMap();
    data['passwordHash'] = _hashPassword(password);

    await _db.collection('users').doc(user.uid).set(data);
    await user.updateDisplayName('$firstName $lastName');
  }

  /// Complete doctor registration after OTP verification.
  /// Call this AFTER [verifyOTP] succeeds.
  Future<void> completeDoctorRegistration({
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    DateTime? dateOfBirth,
    String? gender,
    String? specialtyLevel,
    String? degree,
    String? hospitalName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    final doctor = DoctorModel(
      id: user.uid,
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      phone: phone.trim(),
      dateOfBirth: dateOfBirth,
      gender: gender,
      specialtyLevel: specialtyLevel,
      degree: degree,
      hospitalName: hospitalName,
      createdAt: DateTime.now(),
    );

    final data = doctor.toMap();
    data['passwordHash'] = _hashPassword(password);

    await _db.collection('users').doc(user.uid).set(data);
    await user.updateDisplayName('$firstName $lastName');
  }

  // ==================== LOGIN ====================

  /// Look up a user's role by phone number (before OTP is sent).
  /// Returns 'doctor' or 'patient', or null if not found.
  Future<String?> lookupUserRole(String phone) async {
    final snapshot = await _db
        .collection('users')
        .where('phone', isEqualTo: phone.trim())
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final data = snapshot.docs.first.data();
    return data['role'] as String?;
  }

  /// Verify password for login (before sending OTP).
  /// Returns the user document data if password matches, null otherwise.
  Future<Map<String, dynamic>?> verifyPasswordForLogin({
    required String phone,
    required String password,
  }) async {
    // Find user by phone number
    final snapshot = await _db
        .collection('users')
        .where('phone', isEqualTo: phone.trim())
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final data = snapshot.docs.first.data();
    final storedHash = data['passwordHash'] as String?;

    if (storedHash == null) return null;
    if (!_verifyPassword(password, storedHash)) return null;

    return data;
  }

  // ==================== UID MIGRATION ====================

  /// After login, ensure the user's Firestore doc lives at `users/{currentUID}`.
  /// If the phone-auth UID changed (common with debug/test auth), this copies
  /// the old doc to the new UID key and deletes the old one.  It also patches
  /// every `consultations` document that referenced the stale UID.
  Future<void> migrateUserDocIfNeeded() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final phone = user.phoneNumber;
    if (phone == null || phone.isEmpty) return;

    // 1. Check if a doc already exists at the current UID
    final currentDoc = await _db.collection('users').doc(uid).get();
    if (currentDoc.exists) return; // nothing to migrate

    // 2. Look up the old doc by phone number
    final snap = await _db
        .collection('users')
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return; // brand-new user, nothing to migrate

    final oldDoc = snap.docs.first;
    final oldUid = oldDoc.id;
    if (oldUid == uid) return; // same key, nothing to do

    debugPrint('🔄 Migrating user doc from $oldUid → $uid');

    // 3. Copy data to the new UID key
    final data = oldDoc.data();
    await _db.collection('users').doc(uid).set(data);

    // 4. Delete the old document
    await _db.collection('users').doc(oldUid).delete();

    // 5. Determine role and patch consultations that referenced the old UID
    final role = data['role'] as String?;
    final idField = role == 'doctor' ? 'doctorID' : 'patientID';

    final consultations = await _db
        .collection('consultations')
        .where(idField, isEqualTo: oldUid)
        .get();

    final batch = _db.batch();
    for (final doc in consultations.docs) {
      batch.update(doc.reference, {idField: uid});
    }
    if (consultations.docs.isNotEmpty) {
      await batch.commit();
      debugPrint(
        '🔄 Updated ${consultations.docs.length} consultation(s) '
        '$idField: $oldUid → $uid',
      );
    }

    debugPrint('✅ Migration complete');
  }

  // ==================== SIGN OUT ====================

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ==================== USER PROFILE ====================

  Future<String?> getCurrentUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _db.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;

    final data = doc.data() as Map<String, dynamic>;
    return data['role'] as String?;
  }

  Future<UserModel?> getCurrentUserModel() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _db.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;

    return UserModel.fromFirestore(doc);
  }

  /// Check if a phone number is already registered
  Future<bool> isPhoneRegistered(String phone) async {
    final snapshot = await _db
        .collection('users')
        .where('phone', isEqualTo: phone.trim())
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  // ==================== ERROR HELPERS ====================

  static String getErrorMessage(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return 'Please enter a valid phone number with country code.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      case 'invalid-verification-code':
        return 'Invalid OTP code. Please try again.';
      case 'session-expired':
        return 'OTP expired. Please request a new code.';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later.';
      case 'invalid-credential':
        return 'Invalid verification. Please try again.';
      case 'credential-already-in-use':
        return 'This phone number is already linked to another account.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
