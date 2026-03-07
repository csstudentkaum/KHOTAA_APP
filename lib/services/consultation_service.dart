import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/consultation.dart';
import '../models/doctor_model.dart';
import 'notification_service.dart';

/// Service class for consultation operations
/// Uses the 'consultations' Firestore collection exclusively
class ConsultationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Collection references
  CollectionReference get _consultationsRef =>
      _firestore.collection('consultations');
  CollectionReference get _usersRef => _firestore.collection('users');

  // ── Doctor queries ──

  /// Get all doctors (deduplicated by phone number)
  Future<List<DoctorModel>> getAllDoctors() async {
    final snapshot = await _usersRef.where('role', isEqualTo: 'doctor').get();
    final allDoctors = snapshot.docs
        .map((doc) => DoctorModel.fromFirestore(doc))
        .toList();

    // Deduplicate by phone — keep the first occurrence per phone number
    final seen = <String>{};
    final unique = <DoctorModel>[];
    for (final doctor in allDoctors) {
      final key = doctor.phone.isNotEmpty ? doctor.phone : doctor.id;
      if (!seen.contains(key)) {
        seen.add(key);
        unique.add(doctor);
      }
    }
    return unique;
  }

  /// Search doctors by name or specialty
  Future<List<DoctorModel>> searchDoctors(String query) async {
    final allDoctors = await getAllDoctors();
    final lowerQuery = query.toLowerCase();

    return allDoctors.where((doctor) {
      final fullName = '${doctor.firstName} ${doctor.lastName}'.toLowerCase();
      final specialty = (doctor.specialtyLevel ?? '').toLowerCase();
      return fullName.contains(lowerQuery) || specialty.contains(lowerQuery);
    }).toList();
  }

  /// Get doctor by ID
  Future<DoctorModel?> getDoctorById(String doctorId) async {
    final doc = await _usersRef.doc(doctorId).get();
    if (doc.exists) {
      return DoctorModel.fromFirestore(doc);
    }
    return null;
  }

  // ── Consultation CRUD ──

  /// Check if a patient has an active (non-completed) consultation
  Future<bool> hasActiveConsultation(String patientID) async {
    final snapshot = await _consultationsRef
        .where('patientID', isEqualTo: patientID)
        .where('status', whereIn: ['accepted', 'pending'])
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  /// Create a new consultation (booking)
  Future<Consultation> createConsultation({
    required String patientID,
    required String doctorID,
    required String patientName,
    required String doctorName,
    required DateTime consultationDate,
    required String timeSlot,
    String? reason,
  }) async {
    final docRef = _consultationsRef.doc();
    final now = DateTime.now();

    final consultation = Consultation(
      consultationID: docRef.id,
      patientID: patientID,
      doctorID: doctorID,
      patientName: patientName,
      doctorName: doctorName,
      consultationDate: consultationDate,
      timeSlot: timeSlot,
      status: 'accepted',
      reason: reason,
      createdAt: now,
    );

    await docRef.set(consultation.toMap());

    // Notify the doctor about the new booking
    final dateStr =
        '${consultationDate.day}/${consultationDate.month}/${consultationDate.year}';
    await NotificationService().notifyDoctorNewBooking(
      doctorID: doctorID,
      patientName: patientName,
      date: dateStr,
      timeSlot: timeSlot,
      consultationID: docRef.id,
    );

    return consultation;
  }

  /// Get consultations for a patient
  Future<List<Consultation>> getPatientConsultations(String patientID) async {
    final snapshot = await _consultationsRef
        .where('patientID', isEqualTo: patientID)
        .orderBy('consultationDate', descending: true)
        .get();

    return snapshot.docs.map((doc) => Consultation.fromDocument(doc)).toList();
  }

  /// Get consultations for a doctor
  Future<List<Consultation>> getDoctorConsultations(String doctorID) async {
    final snapshot = await _consultationsRef
        .where('doctorID', isEqualTo: doctorID)
        .orderBy('consultationDate', descending: true)
        .get();

    return snapshot.docs.map((doc) => Consultation.fromDocument(doc)).toList();
  }

  /// Get booked time slots for a doctor on a specific date
  Future<List<String>> getBookedTimeSlots(
    String doctorID,
    DateTime date,
  ) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _consultationsRef
        .where('doctorID', isEqualTo: doctorID)
        .where(
          'consultationDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where('consultationDate', isLessThan: Timestamp.fromDate(endOfDay))
        .where('status', whereIn: ['pending', 'accepted'])
        .get();

    return snapshot.docs
        .map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['timeSlot'] as String? ?? '';
        })
        .where((slot) => slot.isNotEmpty)
        .toList();
  }

  /// Update consultation status
  Future<void> updateStatus(String consultationID, String status) async {
    await _consultationsRef.doc(consultationID).update({
      'status': status,
      'updatedAt': Timestamp.now(),
    });
  }

  /// Accept a consultation
  Future<void> acceptConsultation(String consultationID) async {
    await updateStatus(consultationID, 'accepted');
  }

  /// Reject a consultation
  Future<void> rejectConsultation(String consultationID) async {
    await updateStatus(consultationID, 'rejected');
  }

  /// Delete a consultation entirely from Firestore
  Future<void> deleteConsultation(String consultationID) async {
    await _consultationsRef.doc(consultationID).delete();
  }

  /// Complete a consultation
  Future<void> completeConsultation(String consultationID) async {
    await updateStatus(consultationID, 'completed');
  }

  /// Get available time slots for a doctor on a specific date
  Future<List<String>> getAvailableTimeSlots(
    String doctorID,
    DateTime date,
  ) async {
    // Map weekday number to day name
    const dayNames = [
      '', // 0 unused
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final dayName = dayNames[date.weekday];

    // Try to load doctor's working hours from Firestore
    List<String> allSlots;
    try {
      final doctorDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(doctorID)
          .get();

      final workingHours =
          doctorDoc.data()?['workingHours'] as Map<String, dynamic>?;

      if (workingHours != null) {
        final dayData = workingHours[dayName] as Map<String, dynamic>?;

        // If the day is disabled, return empty
        if (dayData == null || dayData['enabled'] != true) {
          return [];
        }

        final startStr = dayData['start'] as String? ?? '09:00 AM';
        final endStr = dayData['end'] as String? ?? '05:00 PM';

        allSlots = _generateSlots(startStr, endStr);
      } else {
        // Fallback: default slots
        allSlots = [
          '09:00 AM',
          '09:30 AM',
          '10:00 AM',
          '10:30 AM',
          '11:00 AM',
          '11:30 AM',
          '12:00 PM',
          '02:00 PM',
          '02:30 PM',
          '03:00 PM',
          '03:30 PM',
          '04:00 PM',
          '04:30 PM',
        ];
      }
    } catch (_) {
      allSlots = [
        '09:00 AM',
        '09:30 AM',
        '10:00 AM',
        '10:30 AM',
        '11:00 AM',
        '11:30 AM',
        '12:00 PM',
        '02:00 PM',
        '02:30 PM',
        '03:00 PM',
        '03:30 PM',
        '04:00 PM',
        '04:30 PM',
      ];
    }

    final bookedSlots = await getBookedTimeSlots(doctorID, date);
    return allSlots.where((slot) => !bookedSlots.contains(slot)).toList();
  }

  /// Generate 30-minute slots between [startStr] and [endStr]
  /// e.g. _generateSlots('09:00 AM', '05:00 PM')
  List<String> _generateSlots(String startStr, String endStr) {
    int toMinutes(String time) {
      final parts = time.split(' ');
      final hm = parts[0].split(':');
      int h = int.parse(hm[0]);
      final int m = int.parse(hm[1]);
      final period = parts[1].toUpperCase();
      if (period == 'PM' && h != 12) h += 12;
      if (period == 'AM' && h == 12) h = 0;
      return h * 60 + m;
    }

    String toTimeStr(int minutes) {
      int h = minutes ~/ 60;
      final m = minutes % 60;
      final period = h >= 12 ? 'PM' : 'AM';
      if (h == 0) h = 12;
      if (h > 12) h -= 12;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
    }

    final startMin = toMinutes(startStr);
    final endMin = toMinutes(endStr);
    final slots = <String>[];

    for (int t = startMin; t < endMin; t += 30) {
      slots.add(toTimeStr(t));
    }
    return slots;
  }

  // ── Streams (real-time) ──

  /// Stream of patient consultations – soonest date first
  Stream<List<Consultation>> streamPatientConsultations(String patientID) {
    return _consultationsRef
        .where('patientID', isEqualTo: patientID)
        .orderBy('consultationDate', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Consultation.fromDocument(doc))
              .toList(),
        );
  }

  /// Stream of doctor consultations (all) – soonest date first
  Stream<List<Consultation>> streamDoctorConsultations(String doctorID) {
    return _consultationsRef
        .where('doctorID', isEqualTo: doctorID)
        .orderBy('consultationDate', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Consultation.fromDocument(doc))
              .toList(),
        );
  }

  /// Stream of pending consultation requests for doctor
  Stream<List<Consultation>> streamPendingRequests(String doctorID) {
    return _consultationsRef
        .where('doctorID', isEqualTo: doctorID)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Consultation.fromDocument(doc))
              .toList(),
        );
  }

  /// Stream of today's consultations for doctor
  Stream<List<Consultation>> streamTodaysConsultations(String doctorID) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _consultationsRef
        .where('doctorID', isEqualTo: doctorID)
        .where('status', whereIn: ['pending', 'accepted'])
        .where(
          'consultationDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where('consultationDate', isLessThan: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Consultation.fromDocument(doc))
              .toList(),
        );
  }
}
