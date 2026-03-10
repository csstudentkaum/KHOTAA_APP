import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../models/patient_model.dart';
import '../../models/doctor_model.dart';
import '../../models/device_model.dart';
import '../../models/alert.dart';
import '../../models/sensor_reading.dart';
import '../../models/medical_images.dart';
import '../../models/image_analysis.dart';
import '../../models/consultation.dart';
import '../../models/treatment_plan.dart';
import '../../models/weekly_report.dart';
import '../../models/preventive_recommendation.dart';

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
  CollectionReference get _alertsCollection => _db.collection('alerts');
  CollectionReference get _sensorReadingsCollection => _db.collection('sensor_readings');
  CollectionReference get _medicalImagesCollection => _db.collection('medical_images');
  CollectionReference get _imageAnalysisCollection => _db.collection('image_analysis');
  CollectionReference get _consultationsCollection => _db.collection('consultations');
  CollectionReference get _treatmentPlansCollection => _db.collection('treatment_plans');
  CollectionReference get _weeklyReportsCollection => _db.collection('weekly_reports');
  CollectionReference get _preventiveRecommendationsCollection => _db.collection('preventive_recommendations');

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

  // ==================== ALERT OPERATIONS ====================

  /// Create a new alert
  Future<void> createAlert(Alert alert) async {
    await _alertsCollection.doc(alert.alertID).set(alert.toFirestore());
  }

  /// Get an alert by ID
  Future<Alert?> getAlert(String alertId) async {
    final doc = await _alertsCollection.doc(alertId).get();
    if (!doc.exists) return null;
    return Alert.fromFirestore(doc);
  }

  /// Get all alerts for a patient
  Future<List<Alert>> getAlertsForPatient(String patientId) async {
    final snapshot = await _alertsCollection
        .where('patientId', isEqualTo: patientId)
        .orderBy('raisedAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => Alert.fromFirestore(doc)).toList();
  }

  /// Get unviewed alerts for a patient
  Future<List<Alert>> getUnviewedAlertsForPatient(String patientId) async {
    final snapshot = await _alertsCollection
        .where('patientId', isEqualTo: patientId)
        .where('viewed', isEqualTo: false)
        .get();
    return snapshot.docs.map((doc) => Alert.fromFirestore(doc)).toList();
  }

  /// Mark alert as viewed
  Future<void> markAlertAsViewed(String alertId) async {
    await _alertsCollection.doc(alertId).update({'viewed': true});
  }

  /// Stream alerts for a patient
  Stream<List<Alert>> streamAlertsForPatient(String patientId) {
    return _alertsCollection
        .where('patientId', isEqualTo: patientId)
        .orderBy('raisedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Alert.fromFirestore(doc)).toList());
  }

  // ==================== SENSOR READING OPERATIONS ====================

  /// Create a new sensor reading
  Future<void> createSensorReading(SensorReading reading) async {
    await _sensorReadingsCollection
        .doc(reading.sensorReadingID)
        .set(reading.toFirestore());
  }

  /// Get sensor readings for a patient
  Future<List<SensorReading>> getSensorReadingsForPatient(
      String patientId) async {
    final snapshot = await _sensorReadingsCollection
        .where('patientId', isEqualTo: patientId)
        .orderBy('timestamp', descending: true)
        .get();
    return snapshot.docs.map((doc) => SensorReading.fromFirestore(doc)).toList();
  }

  /// Get sensor readings for a device
  Future<List<SensorReading>> getSensorReadingsForDevice(
      String deviceId) async {
    final snapshot = await _sensorReadingsCollection
        .where('deviceId', isEqualTo: deviceId)
        .orderBy('timestamp', descending: true)
        .get();
    return snapshot.docs.map((doc) => SensorReading.fromFirestore(doc)).toList();
  }

  /// Stream sensor readings for a patient
  Stream<List<SensorReading>> streamSensorReadingsForPatient(String patientId) {
    return _sensorReadingsCollection
        .where('patientId', isEqualTo: patientId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => SensorReading.fromFirestore(doc)).toList());
  }

  // ==================== MEDICAL IMAGES OPERATIONS ====================

  /// Upload a medical image record
  Future<void> createMedicalImage(MedicalImages image) async {
    await _medicalImagesCollection.doc(image.imageID).set(image.toFirestore());
  }

  /// Get a medical image by ID
  Future<MedicalImages?> getMedicalImage(String imageId) async {
    final doc = await _medicalImagesCollection.doc(imageId).get();
    if (!doc.exists) return null;
    return MedicalImages.fromFirestore(doc);
  }

  /// Get all medical images for a patient
  Future<List<MedicalImages>> getMedicalImagesForPatient(
      String patientId) async {
    final snapshot = await _medicalImagesCollection
        .where('patientId', isEqualTo: patientId)
        .orderBy('uploadedAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => MedicalImages.fromFirestore(doc)).toList();
  }

  /// Stream medical images for a patient
  Stream<List<MedicalImages>> streamMedicalImagesForPatient(String patientId) {
    return _medicalImagesCollection
        .where('patientId', isEqualTo: patientId)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => MedicalImages.fromFirestore(doc)).toList());
  }

  // ==================== IMAGE ANALYSIS OPERATIONS ====================

  /// Create an image analysis
  Future<void> createImageAnalysis(ImageAnalysis analysis) async {
    await _imageAnalysisCollection
        .doc(analysis.analysisID)
        .set(analysis.toFirestore());
  }

  /// Get analysis for a specific image
  Future<ImageAnalysis?> getAnalysisForImage(String imageId) async {
    final snapshot = await _imageAnalysisCollection
        .where('imageId', isEqualTo: imageId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return ImageAnalysis.fromFirestore(snapshot.docs.first);
  }

  /// Get all analyses for a patient
  Future<List<ImageAnalysis>> getAnalysesForPatient(String patientId) async {
    final snapshot = await _imageAnalysisCollection
        .where('patientId', isEqualTo: patientId)
        .get();
    return snapshot.docs.map((doc) => ImageAnalysis.fromFirestore(doc)).toList();
  }

  // ==================== CONSULTATION OPERATIONS ====================

  /// Create a consultation
  Future<void> createConsultation(Consultation consultation) async {
    await _consultationsCollection
        .doc(consultation.consultationID)
        .set(consultation.toMap());
  }

  /// Get a consultation by ID
  Future<Consultation?> getConsultation(String consultationId) async {
    final doc = await _consultationsCollection.doc(consultationId).get();
    if (!doc.exists) return null;
    return Consultation.fromDocument(doc);
  }

  /// Get consultations for a patient
  Future<List<Consultation>> getConsultationsForPatient(
      String patientId) async {
    final snapshot = await _consultationsCollection
        .where('patientID', isEqualTo: patientId)
        .orderBy('consultationDate', descending: true)
        .get();
    return snapshot.docs.map((doc) => Consultation.fromDocument(doc)).toList();
  }

  /// Get consultations for a doctor
  Future<List<Consultation>> getConsultationsForDoctor(String doctorId) async {
    final snapshot = await _consultationsCollection
        .where('doctorID', isEqualTo: doctorId)
        .orderBy('consultationDate', descending: true)
        .get();
    return snapshot.docs.map((doc) => Consultation.fromDocument(doc)).toList();
  }

  /// Update a consultation
  Future<void> updateConsultation(
      String consultationId, Map<String, dynamic> data) async {
    await _consultationsCollection.doc(consultationId).update(data);
  }

  /// Stream consultations for a patient
  Stream<List<Consultation>> streamConsultationsForPatient(String patientId) {
    return _consultationsCollection
        .where('patientID', isEqualTo: patientId)
        .orderBy('consultationDate', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Consultation.fromDocument(doc)).toList());
  }

  // ==================== TREATMENT PLAN OPERATIONS ====================

  /// Create a treatment plan
  Future<void> createTreatmentPlan(TreatmentPlan plan) async {
    await _treatmentPlansCollection.doc(plan.treatmentPlanID).set(plan.toMap());
  }

  /// Get a treatment plan by ID
  Future<TreatmentPlan?> getTreatmentPlan(String planId) async {
    final doc = await _treatmentPlansCollection.doc(planId).get();
    if (!doc.exists) return null;
    return TreatmentPlan.fromDocument(doc);
  }

  /// Get treatment plan for a consultation
  Future<TreatmentPlan?> getTreatmentPlanForConsultation(
      String consultationId) async {
    final snapshot = await _treatmentPlansCollection
        .where('consultationID', isEqualTo: consultationId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return TreatmentPlan.fromDocument(snapshot.docs.first);
  }

  /// Update a treatment plan
  Future<void> updateTreatmentPlan(
      String planId, Map<String, dynamic> data) async {
    data['lastUpdated'] = FieldValue.serverTimestamp();
    await _treatmentPlansCollection.doc(planId).update(data);
  }

  // ==================== WEEKLY REPORT OPERATIONS ====================

  /// Create a weekly report
  Future<void> createWeeklyReport(WeeklyReport report) async {
    await _weeklyReportsCollection.doc(report.reportID).set(report.toMap());
  }

  /// Get a weekly report by ID
  Future<WeeklyReport?> getWeeklyReport(String reportId) async {
    final doc = await _weeklyReportsCollection.doc(reportId).get();
    if (!doc.exists) return null;
    return WeeklyReport.fromDocument(doc);
  }

  /// Get weekly reports for a patient
  Future<List<WeeklyReport>> getWeeklyReportsForPatient(
      String patientId) async {
    final snapshot = await _weeklyReportsCollection
        .where('patientID', isEqualTo: patientId)
        .orderBy('weekStart', descending: true)
        .get();
    return snapshot.docs.map((doc) => WeeklyReport.fromDocument(doc)).toList();
  }

  /// Stream weekly reports for a patient
  Stream<List<WeeklyReport>> streamWeeklyReportsForPatient(String patientId) {
    return _weeklyReportsCollection
        .where('patientID', isEqualTo: patientId)
        .orderBy('weekStart', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => WeeklyReport.fromDocument(doc)).toList());
  }

  // ==================== PREVENTIVE RECOMMENDATION OPERATIONS ====================

  /// Create a preventive recommendation
  Future<void> createPreventiveRecommendation(
      PreventiveRecommendation recommendation) async {
    await _preventiveRecommendationsCollection
        .doc(recommendation.recID)
        .set(recommendation.toMap());
  }

  /// Get a preventive recommendation by ID
  Future<PreventiveRecommendation?> getPreventiveRecommendation(
      String recId) async {
    final doc = await _preventiveRecommendationsCollection.doc(recId).get();
    if (!doc.exists) return null;
    return PreventiveRecommendation.fromDocument(doc);
  }

  /// Get preventive recommendations for a patient
  Future<List<PreventiveRecommendation>> getPreventiveRecommendationsForPatient(
      String patientId) async {
    final snapshot = await _preventiveRecommendationsCollection
        .where('patientID', isEqualTo: patientId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => PreventiveRecommendation.fromDocument(doc))
        .toList();
  }

  /// Get unviewed recommendations for a patient
  Future<List<PreventiveRecommendation>>
      getUnviewedRecommendationsForPatient(String patientId) async {
    final snapshot = await _preventiveRecommendationsCollection
        .where('patientID', isEqualTo: patientId)
        .where('viewed', isEqualTo: false)
        .get();
    return snapshot.docs
        .map((doc) => PreventiveRecommendation.fromDocument(doc))
        .toList();
  }

  /// Mark recommendation as viewed
  Future<void> markRecommendationAsViewed(String recId) async {
    await _preventiveRecommendationsCollection
        .doc(recId)
        .update({'viewed': true});
  }

  /// Stream recommendations for a patient
  Stream<List<PreventiveRecommendation>>
      streamPreventiveRecommendationsForPatient(String patientId) {
    return _preventiveRecommendationsCollection
        .where('patientID', isEqualTo: patientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PreventiveRecommendation.fromDocument(doc))
            .toList());
  }
}
