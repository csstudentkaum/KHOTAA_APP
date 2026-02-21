import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../models/patient_model.dart';
import '../../models/doctor_model.dart';
import '../../models/device_model.dart';

/// Firestore service for managing User, Patient, Doctor, and Device data.
///
/// Firestore Structure:
/// ┌─────────────────────────────────────────────────┐
/// │ users (collection)                              │
/// │   ├── {userId} (document)                       │
/// │   │   ├── firstName, lastName, phone, role ...  │
/// │   │   ├── specialtyLevel, degree (if doctor)    │
/// │   │   ├── height, weight, bmi (if patient)      │
/// │   │   └── deviceIds[] (if patient)              │
/// │   │                                             │
/// │ devices (collection)                            │
/// │   ├── {deviceId} (document)                     │
/// │   │   ├── patientId, bluetoothStatus ...        │
/// └─────────────────────────────────────────────────┘
///
/// Relationships:
/// - User is the base for Doctor and Patient (role field distinguishes them)
/// - Patient has 1..* Devices (via deviceIds[] array + devices collection)
/// - Doctor conducts 0..* Consultations (future: consultations collection)
/// - Patient undergoes 0..* Consultations (future: consultations collection)
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ==================== Collection References ====================
  CollectionReference get _usersCollection => _db.collection('users');
  CollectionReference get _devicesCollection => _db.collection('devices');

  // ==================== USER OPERATIONS ====================

  /// Get a user by ID (returns UserModel regardless of role)
  Future<UserModel?> getUser(String userId) async {
    final doc = await _usersCollection.doc(userId).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  /// Update user profile
  Future<void> updateProfile(String userId, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _usersCollection.doc(userId).update(data);
  }

  // ==================== PATIENT OPERATIONS ====================

  /// Create a new patient in Firestore
  Future<void> createPatient(PatientModel patient) async {
    await _usersCollection.doc(patient.id).set(patient.toMap());
  }

  /// Get a patient by ID
  Future<PatientModel?> getPatient(String patientId) async {
    final doc = await _usersCollection.doc(patientId).get();
    if (!doc.exists) return null;
    final data = doc.data() as Map<String, dynamic>;
    if (data['role'] != 'patient') return null;
    return PatientModel.fromFirestore(doc);
  }

  /// Get all patients
  Future<List<PatientModel>> getAllPatients() async {
    final snapshot =
        await _usersCollection.where('role', isEqualTo: 'patient').get();
    return snapshot.docs.map((doc) => PatientModel.fromFirestore(doc)).toList();
  }

  /// Get patients assigned to a specific doctor
  Future<List<PatientModel>> getPatientsForDoctor(String doctorId) async {
    final doctor = await getDoctor(doctorId);
    if (doctor == null || doctor.patientIds.isEmpty) return [];

    // Firestore 'whereIn' supports up to 10 items, so we batch if needed
    final List<PatientModel> patients = [];
    final batches = _batchList(doctor.patientIds, 10);

    for (final batch in batches) {
      final snapshot = await _usersCollection
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      patients
          .addAll(snapshot.docs.map((doc) => PatientModel.fromFirestore(doc)));
    }
    return patients;
  }

  /// Update patient data
  Future<void> updatePatient(
      String patientId, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _usersCollection.doc(patientId).update(data);
  }

  /// Stream of a patient's data (real-time updates)
  Stream<PatientModel?> streamPatient(String patientId) {
    return _usersCollection.doc(patientId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return PatientModel.fromFirestore(doc);
    });
  }

  // ==================== DOCTOR OPERATIONS ====================

  /// Create a new doctor in Firestore
  Future<void> createDoctor(DoctorModel doctor) async {
    await _usersCollection.doc(doctor.id).set(doctor.toMap());
  }

  /// Get a doctor by ID
  Future<DoctorModel?> getDoctor(String doctorId) async {
    final doc = await _usersCollection.doc(doctorId).get();
    if (!doc.exists) return null;
    final data = doc.data() as Map<String, dynamic>;
    if (data['role'] != 'doctor') return null;
    return DoctorModel.fromFirestore(doc);
  }

  /// Get all doctors
  Future<List<DoctorModel>> getAllDoctors() async {
    final snapshot =
        await _usersCollection.where('role', isEqualTo: 'doctor').get();
    return snapshot.docs.map((doc) => DoctorModel.fromFirestore(doc)).toList();
  }

  /// Update doctor data
  Future<void> updateDoctor(
      String doctorId, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _usersCollection.doc(doctorId).update(data);
  }

  /// Assign a patient to a doctor (creates the relationship)
  Future<void> assignPatientToDoctor(
      String doctorId, String patientId) async {
    // Add patientId to doctor's patientIds array
    await _usersCollection.doc(doctorId).update({
      'patientIds': FieldValue.arrayUnion([patientId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Remove a patient from a doctor
  Future<void> removePatientFromDoctor(
      String doctorId, String patientId) async {
    await _usersCollection.doc(doctorId).update({
      'patientIds': FieldValue.arrayRemove([patientId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stream of a doctor's data (real-time updates)
  Stream<DoctorModel?> streamDoctor(String doctorId) {
    return _usersCollection.doc(doctorId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return DoctorModel.fromFirestore(doc);
    });
  }

  // ==================== DEVICE OPERATIONS ====================

  /// Add a new device and link it to a patient
  Future<void> addDevice(DeviceModel device) async {
    // Create the device document
    await _devicesCollection.doc(device.deviceId).set(device.toMap());

    // Add deviceId to the patient's deviceIds array
    await _usersCollection.doc(device.patientId).update({
      'deviceIds': FieldValue.arrayUnion([device.deviceId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get a device by ID
  Future<DeviceModel?> getDevice(String deviceId) async {
    final doc = await _devicesCollection.doc(deviceId).get();
    if (!doc.exists) return null;
    return DeviceModel.fromFirestore(doc);
  }

  /// Get all devices for a specific patient
  Future<List<DeviceModel>> getDevicesForPatient(String patientId) async {
    final snapshot = await _devicesCollection
        .where('patientId', isEqualTo: patientId)
        .get();
    return snapshot.docs.map((doc) => DeviceModel.fromFirestore(doc)).toList();
  }

  /// Update device Bluetooth status
  Future<void> updateDeviceStatus(
      String deviceId, bool bluetoothStatus) async {
    await _devicesCollection.doc(deviceId).update({
      'bluetoothStatus': bluetoothStatus,
      'lastConnected':
          bluetoothStatus ? FieldValue.serverTimestamp() : null,
    });
  }

  /// Remove a device from a patient
  Future<void> removeDevice(String deviceId, String patientId) async {
    // Remove deviceId from patient's deviceIds array
    await _usersCollection.doc(patientId).update({
      'deviceIds': FieldValue.arrayRemove([deviceId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Delete the device document
    await _devicesCollection.doc(deviceId).delete();
  }

  /// Stream devices for a patient (real-time updates)
  Stream<List<DeviceModel>> streamDevicesForPatient(String patientId) {
    return _devicesCollection
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => DeviceModel.fromFirestore(doc)).toList());
  }

  // ==================== HELPER METHODS ====================

  /// Split a list into batches of a given size
  List<List<T>> _batchList<T>(List<T> list, int batchSize) {
    final List<List<T>> batches = [];
    for (int i = 0; i < list.length; i += batchSize) {
      final end = (i + batchSize < list.length) ? i + batchSize : list.length;
      batches.add(list.sublist(i, end));
    }
    return batches;
  }

  /// Delete a user and all related data
  Future<void> deleteUser(String userId) async {
    final doc = await _usersCollection.doc(userId).get();
    if (!doc.exists) return;

    final data = doc.data() as Map<String, dynamic>;

    // If patient, remove all associated devices
    if (data['role'] == 'patient') {
      final devices = await getDevicesForPatient(userId);
      for (final device in devices) {
        await _devicesCollection.doc(device.deviceId).delete();
      }
    }

    // If doctor, no cascading deletes needed for patients (they exist independently)

    // Delete the user document
    await _usersCollection.doc(userId).delete();
  }
}
