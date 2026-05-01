import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../models/chat_message.dart';
import '../../models/consultation.dart';
import '../../models/treatment_plan.dart';

class ConsultationChatService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;

  // ── Collections ──

  CollectionReference<Map<String, dynamic>> _messages(String consultationId) =>
      _db.collection('consultations').doc(consultationId).collection('messages');

  DocumentReference<Map<String, dynamic>> _consultation(String consultationId) =>
      _db.collection('consultations').doc(consultationId);

  // ── Streams ──

  Stream<List<ChatMessage>> streamMessages(String consultationId) {
    return _messages(consultationId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ChatMessage.fromDocument(d)).toList());
  }

  Stream<Consultation?> streamConsultation(String consultationId) {
    return _consultation(consultationId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return Consultation.fromDocument(snap);
    });
  }

  Stream<List<Consultation>> streamConsultationsForPatient(String patientId) {
    return _db
        .collection('consultations')
        .where('patientID', isEqualTo: patientId)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((d) => Consultation.fromDocument(d)).toList();
          // Sort client-side to avoid requiring a composite index
          list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
          return list;
        });
  }

  Stream<List<Consultation>> streamConsultationsForDoctor(String doctorId) {
    return _db
        .collection('consultations')
        .where('doctorID', isEqualTo: doctorId)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((d) => Consultation.fromDocument(d)).toList();
          list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
          return list;
        });
  }

  // ── Sending messages ──

  Future<void> sendText(String consultationId, String text) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final msg = ChatMessage.text(
      senderID: user.uid,
      senderName: user.displayName,
      text: text,
    );
    await _addMessage(consultationId, msg);
  }

  Future<void> sendImage(String consultationId, File imageFile) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final url = await _uploadFile(consultationId, imageFile, 'images');
    final msg = ChatMessage.image(
      senderID: user.uid,
      senderName: user.displayName,
      fileUrl: url,
    );
    await _addMessage(consultationId, msg);
  }

  Future<void> sendFile(
      String consultationId, File file, String fileName) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final url = await _uploadFile(consultationId, file, 'files');
    final msg = ChatMessage.file(
      senderID: user.uid,
      senderName: user.displayName,
      fileUrl: url,
      fileName: fileName,
    );
    await _addMessage(consultationId, msg);
  }

  Future<void> sendVoice(
      String consultationId, File audioFile, int durationSeconds) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final url = await _uploadFile(consultationId, audioFile, 'voice');
    final msg = ChatMessage.voice(
      senderID: user.uid,
      senderName: user.displayName,
      fileUrl: url,
      duration: durationSeconds,
    );
    await _addMessage(consultationId, msg);
  }

  Future<void> sendSystemMessage(String consultationId, String text) async {
    final msg = ChatMessage.system(text: text);
    await _addMessage(consultationId, msg);
  }

  // ── Consultation status ──

  Future<void> activateSession(String consultationId) async {
    await _consultation(consultationId).update({
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await sendSystemMessage(consultationId, 'Session started.');
  }

  Future<void> completeSession(
      String consultationId, {
      String? notes,
      String? diagnosis,
      String? prescription,
    }) async {
    await _consultation(consultationId).update({
      'status': 'completed',
      'notes': notes,
      'diagnosis': diagnosis,
      'prescription': prescription,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await sendSystemMessage(consultationId, 'Session completed.');
  }

  /// Complete consultation with full summary + treatment plan.
  /// If a treatment plan already exists (e.g. from a follow-up), it updates it.
  Future<void> completeWithSummary({
    required String consultationId,
    required String diagnosis,
    required String notes,
    required String prescription,
    required List<Map<String, String>> medications,
    required String treatmentNotes,
  }) async {
    final consultDoc = await _consultation(consultationId).get();
    final consultData = consultDoc.data() ?? {};

    // Create or update treatment plan
    final existingPlanId = consultData['treatmentPlanID'] as String?;
    final planRef = existingPlanId != null && existingPlanId.isNotEmpty
        ? _db.collection('treatment_plans').doc(existingPlanId)
        : _db.collection('treatment_plans').doc();

    final plan = TreatmentPlan(
      treatmentPlanID: planRef.id,
      consultationID: consultationId,
      doctorId: _auth.currentUser?.uid ?? '',
      patientId: consultData['patientID'] as String? ?? '',
      patientName: consultData['patientName'] as String? ?? '',
      diagnosis: diagnosis,
      medications: medications,
      notes: treatmentNotes,
      status: 'active',
      createdAt: DateTime.now(),
    );
    await planRef.set(plan.toMap());

    // Update consultation
    await _consultation(consultationId).update({
      'status': 'completed',
      'diagnosis': diagnosis,
      'notes': notes,
      'prescription': prescription,
      'treatmentPlanID': planRef.id,
      'endTime': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await sendSystemMessage(consultationId,
        'Session completed. Treatment plan is available.');
  }

  /// Set follow-up with treatment plan + tasks.
  Future<void> setFollowUpWithPlan({
    required String consultationId,
    required String diagnosis,
    required String notes,
    required String prescription,
    required List<Map<String, String>> medications,
    required String treatmentNotes,
    required int followUpDays,
    required List<Map<String, dynamic>> followUpTasks,
    String? followUpInstructions,
  }) async {
    final consultDoc = await _consultation(consultationId).get();
    final consultData = consultDoc.data() ?? {};

    // Create or update treatment plan
    final existingPlanId = consultData['treatmentPlanID'] as String?;
    final planRef = existingPlanId != null && existingPlanId.isNotEmpty
        ? _db.collection('treatment_plans').doc(existingPlanId)
        : _db.collection('treatment_plans').doc();

    final plan = TreatmentPlan(
      treatmentPlanID: planRef.id,
      consultationID: consultationId,
      doctorId: _auth.currentUser?.uid ?? '',
      patientId: consultData['patientID'] as String? ?? '',
      patientName: consultData['patientName'] as String? ?? '',
      diagnosis: diagnosis,
      medications: medications,
      notes: treatmentNotes,
      status: 'active',
      createdAt: DateTime.now(),
    );
    await planRef.set(plan.toMap());

    final dueDate = DateTime.now().add(Duration(days: followUpDays));

    await _consultation(consultationId).update({
      'status': 'followUp',
      'diagnosis': diagnosis,
      'notes': notes,
      'prescription': prescription,
      'treatmentPlanID': planRef.id,
      'followUpDueDate': Timestamp.fromDate(dueDate),
      'followUpTasks': followUpTasks,
      'followUpInstructions': followUpInstructions,
      'followUpCheckIn': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final dueStr = '${dueDate.day}/${dueDate.month}/${dueDate.year}';
    await sendSystemMessage(consultationId,
        'Follow-up care started. Treatment plan is available. Next review: $dueStr');
  }

  /// Patient submits follow-up check-in.
  Future<void> submitCheckIn({
    required String consultationId,
    required Map<String, dynamic> responses,
  }) async {
    await _consultation(consultationId).update({
      'followUpCheckIn': responses,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await sendSystemMessage(consultationId,
        'Patient submitted their follow-up check-in.');
  }

  /// Get treatment plan for a consultation.
  Future<TreatmentPlan?> getTreatmentPlan(String consultationId) async {
    final snap = await _db
        .collection('treatment_plans')
        .where('consultationID', isEqualTo: consultationId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return TreatmentPlan.fromDocument(snap.docs.first);
  }

  /// Stream treatment plan for a consultation.
  Stream<TreatmentPlan?> streamTreatmentPlan(String consultationId) {
    return _db
        .collection('treatment_plans')
        .where('consultationID', isEqualTo: consultationId)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      return TreatmentPlan.fromDocument(snap.docs.first);
    });
  }

  Future<void> scheduleFollowUp(String consultationId) async {
    await _consultation(consultationId).update({
      'status': 'followUp',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await sendSystemMessage(
        consultationId, 'Follow-up requested. A new appointment will be scheduled.');
  }

  Future<void> postVideoCallMessage(
      String consultationId, String initiatorName) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final msg = ChatMessage.videoCall(
      senderID: user.uid,
      senderName: initiatorName,
      text: '$initiatorName started a video call',
    );
    await _addMessage(consultationId, msg);
  }

  // ── Read receipts ──

  Future<void> markMessagesAsRead(
      String consultationId, String currentUserId) async {
    final snap = await _messages(consultationId)
        .where('isRead', isEqualTo: false)
        .get();
    if (snap.docs.isEmpty) return;
    final batch = _db.batch();
    int count = 0;
    for (final doc in snap.docs) {
      if (doc.data()['senderID'] != currentUserId) {
        batch.update(doc.reference, {'isRead': true});
        count++;
      }
    }
    if (count > 0) await batch.commit();
  }

  // ── Helpers ──

  Future<void> _addMessage(
      String consultationId, ChatMessage msg) async {
    final ref = _messages(consultationId).doc();
    await ref.set({...msg.toMap(), 'messageID': ref.id});
  }

  /// Uploads a file to Firebase Storage and returns the download URL.
  /// Path: consultations/{consultationId}/{folder}/{timestamp}.{ext}
  /// Access is controlled by Firebase Storage rules.
  Future<String> _uploadFile(
      String consultationId, File file, String folder) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final ext = file.path.split('.').last.toLowerCase();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final mimeType = _mimeType(ext);

    final ref = _storage
        .ref()
        .child('consultations')
        .child(consultationId)
        .child(folder)
        .child(fileName);

    final metadata = SettableMetadata(
      contentType: mimeType,
      customMetadata: {
        'consultationId': consultationId,
        'senderId': user.uid,
      },
    );

    final task = await ref.putFile(file, metadata);
    return task.ref.getDownloadURL();
  }

  /// Returns the URL to play/display a chat file.
  /// Firebase Storage download URLs already contain an embedded access token,
  /// so they are directly usable by Image.network() and audio players.
  Future<String> getFileUrl(String url) async => url;

  String _mimeType(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png':  return 'image/png';
      case 'webp': return 'image/webp';
      case 'm4a':  return 'audio/m4a';
      case 'aac':  return 'audio/aac';
      case 'mp3':  return 'audio/mpeg';
      case 'pdf':  return 'application/pdf';
      default:     return 'application/octet-stream';
    }
  }
}
