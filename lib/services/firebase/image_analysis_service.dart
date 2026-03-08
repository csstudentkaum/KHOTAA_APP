import 'dart:io';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../app/config.dart';
import '../../models/medical_images.dart';
import '../../models/image_analysis.dart';

/// Handles the full image-analysis pipeline:
///   1. Upload photo → Vercel Blob (via server API)
///   2. Save MedicalImages doc → Firestore
///   3. Run classification (simulated until ML endpoint is ready)
///   4. Save ImageAnalysis doc → Firestore
class ImageAnalysisService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Set to `false` once your real ML model endpoint is deployed.
  static const bool useSimulatedAI = true;

  /// Set to `true` to save images & records to Vercel Blob + Firestore.
  static const bool persistData = true;

  /// Your Vercel server base URL — read from AppConfig (never hardcoded).
  String get _serverUrl => AppConfig.serverUrl;

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

    // Upload image to Vercel Blob via server API
    final imageBytes = await file.readAsBytes();
    final response = await http.post(
      Uri.parse('$_serverUrl/api/upload-image?patientId=$uid'),
      headers: {'Content-Type': 'image/jpeg'},
      body: imageBytes,
    );

    if (response.statusCode != 200) {
      throw Exception('Image upload failed: ${response.body}');
    }

    final json = jsonDecode(response.body);
    final imageUrl = json['url'] as String;

    // Save record to Firestore medical_images collection
    final id = _db.collection('medical_images').doc().id;
    final record = MedicalImages(
      imageID: id,
      uploadedAt: DateTime.now(),
      filePath: imageUrl, // Vercel Blob URL
      patientId: uid,
    );

    await _db.collection('medical_images').doc(id).set(record.toFirestore());
    return record;
  }

  // ── 2. Analyse the image ──────────────────────────────────────────

  /// Returns a simulated result when useSimulatedAI is true.
  /// Replace the simulation with an HTTP call to your deployed model.
  Future<ImageAnalysis> analyse(MedicalImages image) async {
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
      // TODO: Real ML model call
      // final response = await http.post(Uri.parse('YOUR_MODEL_ENDPOINT'), ...);
      // final json = jsonDecode(response.body);
      // classification = UlcerClass.values.byName(json['classification']);
      // confidence = json['confidence'];
      // notes = _noteFor(classification);
      throw UnimplementedError('Real ML endpoint not configured yet');
    }

    if (!persistData) {
      // Return without saving to Firestore
      return ImageAnalysis(
        analysisID: 'demo_a_${DateTime.now().millisecondsSinceEpoch}',
        classification: classification,
        notes: notes,
        confidence: confidence,
        modelName: 'DFU-Classify-v1',
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
      modelName: 'DFU-Classify-v1',
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
