import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/patient_model.dart';
import '../../models/doctor_model.dart';
import '../../models/user_model.dart';

/// Firebase Authentication service using **Phone + OTP** (passwordless for patients)
/// and **Email + Password** (for doctors).
///
/// Patient Flow:
///   Registration:
///     1. Patient fills form (phone, name, etc.)
///     2. OTP is sent to their phone via Firebase Phone Auth
///     3. Patient enters OTP → verified → Firebase Auth user created
///     4. Profile saved to Firestore
///
///   Login:
///     1. Patient enters phone number
///     2. Phone checked against Firestore (must be registered)
///     3. OTP sent to phone for identity verification
///     4. Patient enters OTP → signed in
///
/// Doctor Flow:
///   - Doctors are pre-registered by admin
///   - They sign in with email + password
///   - Forgot Password sends a reset email
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Web-only: stores the result from signInWithPhoneNumber so verifyOTP can confirm it.
  // Static so it survives navigation between screens (each screen creates a new AuthService instance).
  static ConfirmationResult? _webConfirmationResult;

  // ==================== AUTH STATE ====================

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  bool get isLoggedIn => _auth.currentUser != null;

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
    if (kIsWeb) {
      // ── Web flow ──────────────────────────────────────────────────────────
      // Firebase web phone auth requires signInWithPhoneNumber + RecaptchaVerifier.
      // verifyPhoneNumber() is mobile-only and throws invalid-app-credential on web.
      try {
        // signInWithPhoneNumber creates an invisible RecaptchaVerifier
        // internally when no verifier is passed, avoiding direct use of
        // RecaptchaVerifier (which requires FirebaseAuthPlatform, a private
        // internal type not accessible from outside firebase_auth).
        _webConfirmationResult = await _auth.signInWithPhoneNumber(phoneNumber);
        debugPrint('OTP sent to $phoneNumber (web)');
        onCodeSent(_webConfirmationResult!.verificationId, null);
      } on FirebaseAuthException catch (e) {
        debugPrint('Web OTP send failed: ${e.code} - ${e.message}');
        onError(getErrorMessage(e.code));
      } catch (e) {
        debugPrint('Web OTP send error: $e');
        onError('Something went wrong. Please try again.');
      }
      return;
    }

    // ── Mobile flow ───────────────────────────────────────────────────────
    // Ensure app verification is disabled for testing on simulator (mobile only).
    if (kDebugMode) {
      await _auth.setSettings(appVerificationDisabledForTesting: true);
      debugPrint('  appVerificationDisabledForTesting set to true before OTP (mobile)');
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
    if (kIsWeb) {
      // Web: confirm the code against the ConfirmationResult stored by sendOTP.
      if (_webConfirmationResult == null) {
        throw FirebaseAuthException(
          code: 'session-expired',
          message: 'No active OTP session. Please request a new code.',
        );
      }
      final result = await _webConfirmationResult!.confirm(otp);
      _webConfirmationResult = null; // clear after use
      return result;
    }

    // Mobile: use the verificationId returned by verifyPhoneNumber.
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

    await _db.collection('users').doc(user.uid).set(data);
    await user.updateDisplayName('$firstName $lastName');
  }

  /// Complete doctor registration after OTP verification.
  /// Call this AFTER [verifyOTP] succeeds.
  Future<void> completeDoctorRegistration({
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

    await _db.collection('users').doc(user.uid).set(data);
    await user.updateDisplayName('$firstName $lastName');
  }

  // ==================== LOGIN ====================

  /// Find a user by phone number for login (before sending OTP).
  /// Returns the user document data if phone is registered, null otherwise.
  Future<Map<String, dynamic>?> findUserByPhone({required String phone}) async {
    final snapshot = await _db
        .collection('users')
        .where('phone', isEqualTo: phone.trim())
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first.data();
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

  // ==================== EMAIL/PASSWORD AUTH (FOR DOCTORS) ====================

  /// Sign in with email and password (used for doctor accounts).
  /// Returns the User on success, null on failure.
  Future<User?> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('Email sign-in failed: ${e.code} - ${e.message}');
      rethrow;
    }
  }

  /// Send a password reset email (Firebase default — for "Forgot Password").
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ==================== DOCTOR ACCOUNT CREATION (ADMIN) ====================

  /// Create a doctor account in Firebase Auth + Firestore.
  /// This is called by admin. The doctor will receive an activation email
  /// via the external email service (Resend) to set their password.
  ///
  /// Returns the UID of the created doctor.
  ///
  /// Flow:
  ///   1. Create Firebase Auth user with email + random temp password
  ///   2. Save doctor profile to Firestore (isActive: false)
  ///   3. Sign the admin back in (creating a user signs them out)
  ///   4. Caller sends activation email via EmailService
  Future<String> createDoctorAccount({
    required String email,
    required String firstName,
    required String lastName,
    required String phone,
    String? specialtyLevel,
    String? degree,
    String? hospitalName,
    String? gender,
  }) async {
    try {
      // Create Firebase Auth user with a random temp password
      // Doctor will never know this — they set their own via activation email
      final tempPassword = _generateTempPassword();
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: tempPassword,
      );

      final uid = credential.user!.uid;

      // Save doctor profile to Firestore
      final doctor = DoctorModel(
        id: uid,
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        phone: phone.trim(),
        gender: gender,
        specialtyLevel: specialtyLevel,
        degree: degree,
        hospitalName: hospitalName,
        createdAt: DateTime.now(),
      );

      final data = doctor.toMap();
      data['email'] = email.trim();
      data['isActive'] = false; // Will be activated when doctor sets password

      await _db.collection('users').doc(uid).set(data);

      // Sign out the newly created user (Firebase auto-signs them in)
      await _auth.signOut();

      // NOTE: The admin needs to sign back in after this.
      // The caller should handle re-authentication.

      return uid;
    } catch (e) {
      debugPrint('Create doctor account error: $e');
      rethrow;
    }
  }

  /// Generate a random temporary password (doctor never sees this).
  String _generateTempPassword() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*';
    final random = DateTime.now().millisecondsSinceEpoch;
    final buffer = StringBuffer();
    for (var i = 0; i < 24; i++) {
      buffer.write(chars[(random + i * 37) % chars.length]);
    }
    return buffer.toString();
  }

  /// Get a user profile from Firestore by UID.
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return doc.data();
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
