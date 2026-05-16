import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../models/medical_images.dart';
import '../../models/image_analysis.dart';

/// Handles the full image-analysis pipeline:
///   1. Upload photo → Firebase Storage
///   2. Save MedicalImages doc → Firestore
///   3. Run classification
///   4. Save ImageAnalysis doc → Firestore
class ImageAnalysisService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Set to `true` to save images & records to Firebase Storage + Firestore.
  static const bool persistData = true;

  String? get _uid => _auth.currentUser?.uid;

  // ── 1. Upload image file ──────────────────────────────────────────

  Future<MedicalImages> uploadImage(File file) async {
    final uid = _uid ?? 'demo-user';

    if (!persistData) {
      // Local-only mode — no network calls
      await Future.delayed(const Duration(milliseconds: 1200));
      final id = 'demo_${DateTime.now().millisecondsSinceEpoch}';
      return MedicalImages(
        imageID: id,
        uploadedAt: DateTime.now(),
        filePath: file.path,
        patientId: uid,
      );
    }

    // Upload image to Firebase Storage at: medical_images/{uid}/{timestamp}.jpg
    final ext = file.path.split('.').last.toLowerCase();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final ref = _storage.ref().child('medical_images').child(uid).child(fileName);

    final metadata = SettableMetadata(
      contentType: _mimeType(ext),
      customMetadata: {'patientId': uid},
    );

    final task = await ref.putFile(file, metadata);
    final imageUrl = await task.ref.getDownloadURL();

    // Save record to Firestore medical_images collection
    final id = _db.collection('medical_images').doc().id;
    final record = MedicalImages(
      imageID: id,
      uploadedAt: DateTime.now(),
      filePath: imageUrl, // Firebase Storage download URL
      patientId: uid,
    );

    await _db.collection('medical_images').doc(id).set(record.toFirestore());
    return record;
  }

  String _mimeType(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  // ── 2. Analyse the image ──────────────────────────────────────────

  Future<ImageAnalysis> analyse(MedicalImages image) async {
    final uid = _uid ?? 'demo-user';

    // ── Classification (simulated or real) ──
    late UlcerClass classification;
    late double confidence;
    late String notes;

    final modelUrl = dotenv.env['MODEL_URL'] ?? '';
    if (modelUrl.isEmpty) throw Exception('MODEL_URL not set in .env');

    // Download image bytes from Firebase Storage URL
    final imageResp = await http.get(Uri.parse(image.filePath));
    if (imageResp.statusCode != 200) {
      throw Exception('Failed to fetch image for inference');
    }

    // Send as multipart file upload
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$modelUrl/predict'),
    );
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      imageResp.bodyBytes,
      filename: 'image.jpg',
      contentType: MediaType('image', 'jpeg'),
    ));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception('Model inference failed: ${response.body}');
    }

    final result = jsonDecode(response.body);
    classification = UlcerClassX.fromString(result['prediction'] as String);
    confidence = (result['confidence'] as num).toDouble();
    notes = _noteFor(classification);

    if (!persistData) {
      // Return without saving to Firestore
      return ImageAnalysis(
        analysisID: 'demo_a_${DateTime.now().millisecondsSinceEpoch}',
        classification: classification,
        notes: notes,
        confidence: confidence,
        modelName: 'efficientnetv2s',
        imageId: image.imageID,
        patientId: uid,
      );
    }

    // Save analysis record to Firestore
    final id = _db.collection('image_analysis').doc().id;
    final analysis = ImageAnalysis(
      analysisID: id,
      classification: classification,
      notes: notes,
      confidence: confidence,
      modelName: 'efficientnetv2s',
      imageId: image.imageID,
      patientId: uid,
    );

    await _db.collection('image_analysis').doc(id).set({
      ...analysis.toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return analysis;
  }

  // ── 3. Convenience: upload + analyse in one call ──────────────────

  Future<({MedicalImages image, ImageAnalysis analysis})> uploadAndAnalyse(
    File file,
  ) async {
    final img = await uploadImage(file);
    final res = await analyse(img);
    return (image: img, analysis: res);
  }

  // ── 4. History streams ────────────────────────────────────────────

  Stream<List<ImageAnalysis>> historyStream() {
    if (!persistData) return Stream.value([]);
    final uid = _uid;
    if (uid == null) return Stream.value([]);
    return _db
        .collection('image_analysis')
        .where('patientId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(ImageAnalysis.fromFirestore).toList());
  }

  String _noteFor(UlcerClass cls) => switch (cls) {
        UlcerClass.none =>
          'No clinical signs of infection or ischaemia detected. '
              'Wound appears stable. Continue routine wound care and monitoring.',
        UlcerClass.infection =>
          'Infection indicators detected: peri-wound erythema, possible purulence '
              'or swelling. Evaluate for systemic signs. Consider empirical '
              'antibiotic therapy and wound debridement as appropriate.',
        UlcerClass.ischaemia =>
          'Ischaemic indicators detected: pallor, delayed capillary refill, '
              'or tissue changes suggesting reduced perfusion. Vascular '
              'assessment (ABI / toe pressure) recommended.',
        UlcerClass.both =>
          'Combined infection and ischaemia indicators detected. '
              'High-risk presentation — urgent multidisciplinary evaluation '
              'recommended. Assess for limb-threatening involvement.',
      };
}
