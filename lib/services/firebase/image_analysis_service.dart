import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
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
///   3. Run classification (simulated until ML endpoint is ready)
///   4. Save ImageAnalysis doc → Firestore
class ImageAnalysisService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Set to `false` once your real ML model endpoint is deployed.
  static const bool useSimulatedAI = false;

  /// Set to `true` to save images & records to Firebase Storage + Firestore.
  static const bool persistData = true;

  String? get _uid => _auth.currentUser?.uid;

  // ── 1. Upload image file ──────────────────────────────────────────

  Future<MedicalImages> uploadImage(File file) async {
    return uploadImageBytes(
      await file.readAsBytes(),
      file.path.split('.').last.toLowerCase(),
    );
  }

  Future<MedicalImages> uploadImageBytes(
    Uint8List bytes, [
    String ext = 'jpg',
  ]) async {
    final uid = _uid ?? 'demo-user';

    if (!persistData) {
      await Future.delayed(const Duration(milliseconds: 1200));
      final id = 'demo_${DateTime.now().millisecondsSinceEpoch}';
      return MedicalImages(
        imageID: id,
        uploadedAt: DateTime.now(),
        filePath: kIsWeb ? '' : id,
        patientId: uid,
      );
    }

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final ref = _storage
        .ref()
        .child('medical_images')
        .child(uid)
        .child(fileName);

    final metadata = SettableMetadata(
      contentType: _mimeType(ext),
      customMetadata: {'patientId': uid},
    );

    final task = await ref.putData(bytes, metadata);
    final imageUrl = await task.ref.getDownloadURL();

    final id = _db.collection('medical_images').doc().id;
    final record = MedicalImages(
      imageID: id,
      uploadedAt: DateTime.now(),
      filePath: imageUrl,
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

  /// Returns a simulated result when useSimulatedAI is true.
  /// Replace the simulation with an HTTP call to your deployed model.
  /// [imageBytes] can be supplied directly (e.g. on web) to avoid
  /// re-downloading the image from Firebase Storage (CORS issue).
  Future<ImageAnalysis> analyse(
    MedicalImages image, {
    Uint8List? imageBytes,
  }) async {
    final uid = _uid ?? 'demo-user';

    // ── Classification (simulated or real) ──
    late UlcerClass classification;
    late double confidence;
    late String notes;

    if (useSimulatedAI) {
      // Simulated — remove once real model is deployed
      await Future.delayed(const Duration(milliseconds: 1500));
      final sim = _simulate();
      classification = sim.classification;
      confidence = sim.confidence;
      notes = sim.notes;
    } else {
      final modelUrl = dotenv.env['MODEL_URL'] ?? '';
      if (modelUrl.isEmpty) throw Exception('MODEL_URL not set in .env');

      // Use provided bytes, or on web use Firebase Storage SDK (avoids CORS),
      // or on native fetch from the download URL.
      late Uint8List bytes;
      if (imageBytes != null) {
        bytes = imageBytes;
      } else if (kIsWeb) {
        // On web: use Firebase Storage SDK ref.getData() which handles CORS internally
        final ref = _storage.refFromURL(image.filePath);
        final data = await ref.getData();
        if (data == null) throw Exception('Failed to fetch image from Storage');
        bytes = data;
      } else {
        final imageResp = await http.get(Uri.parse(image.filePath));
        if (imageResp.statusCode != 200) {
          throw Exception('Failed to fetch image for inference');
        }
        bytes = imageResp.bodyBytes;
      }

      // Send as multipart file upload
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$modelUrl/predict'),
      );
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: 'image.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      );
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode != 200) {
        throw Exception('Model inference failed: ${response.body}');
      }

      final result = jsonDecode(response.body);
      classification = UlcerClassX.fromString(result['prediction'] as String);
      confidence = (result['confidence'] as num).toDouble();
      notes = _noteFor(classification);
    }

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

  Future<({MedicalImages image, ImageAnalysis analysis})> uploadAndAnalyseBytes(
    Uint8List bytes, [
    String ext = 'jpg',
  ]) async {
    final img = await uploadImageBytes(bytes, ext);
    final res = await analyse(img, imageBytes: bytes);
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

  // ── Simulation (remove once real endpoint is wired) ───────────────

  _SimResult _simulate() {
    final r = math.Random();
    // Weighted distribution: None 45%, Infection 25%, Ischaemia 20%, Both 10%
    final weights = [45, 25, 20, 10];
    final classes = [
      UlcerClass.none,
      UlcerClass.infection,
      UlcerClass.ischaemia,
      UlcerClass.both,
    ];

    var pick = r.nextInt(weights.reduce((a, b) => a + b));
    UlcerClass cls = UlcerClass.none;
    for (var i = 0; i < weights.length; i++) {
      pick -= weights[i];
      if (pick < 0) {
        cls = classes[i];
        break;
      }
    }

    return _SimResult(
      classification: cls,
      confidence: 0.82 + r.nextDouble() * 0.17,
      notes: _noteFor(cls),
    );
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

class _SimResult {
  final UlcerClass classification;
  final double confidence;
  final String notes;
  const _SimResult({
    required this.classification,
    required this.confidence,
    required this.notes,
  });
}
