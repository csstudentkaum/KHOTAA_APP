import 'dart:io';
import 'dart:math' as math;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/medical_images.dart';
import '../../models/image_analysis.dart';

/// Handles the full image-analysis pipeline:
///   1. Upload photo → Firebase Storage
///   2. Save MedicalImages doc → Firestore
///   3. Run classification (simulated until ML endpoint is ready)
///   4. Save ImageAnalysis doc → Firestore
class ImageAnalysisService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Toggle this to `false` once Firebase Storage is enabled.
  static const bool demoMode = true;

  String? get _uid => _auth.currentUser?.uid;

  // ── 1. Upload image file ──────────────────────────────────────────

  Future<MedicalImages> uploadImage(File file) async {
    final uid = _uid ?? 'demo-user';

    if (demoMode) {
      await Future.delayed(const Duration(milliseconds: 1200));
      final id = 'demo_${DateTime.now().millisecondsSinceEpoch}';
      return MedicalImages(
        imageID: id,
        uploadedAt: DateTime.now(),
        filePath: file.path,
        patientId: uid,
      );
    }

    final id = _db.collection('medical_images').doc().id;
    final ref = _storage.ref('medical_images/$uid/$id.jpg');

    await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    final url = await ref.getDownloadURL();

    final record = MedicalImages(
      imageID: id,
      uploadedAt: DateTime.now(),
      filePath: url,
      patientId: uid,
    );

    await _db.collection('medical_images').doc(id).set(record.toFirestore());
    return record;
  }

  // ── 2. Analyse the image ──────────────────────────────────────────

  /// Currently returns a simulated ulcer-classification result.
  /// Replace the body with an HTTP call to your deployed model.
  Future<ImageAnalysis> analyse(MedicalImages image) async {
    final uid = _uid ?? 'demo-user';

    final sim = _simulate();

    if (demoMode) {
      await Future.delayed(const Duration(milliseconds: 1500));
      return ImageAnalysis(
        analysisID: 'demo_a_${DateTime.now().millisecondsSinceEpoch}',
        classification: sim.classification,
        notes: sim.notes,
        confidence: sim.confidence,
        modelName: 'DFU-Classify-v1',
        imageId: image.imageID,
        patientId: uid,
      );
    }

    // ── TODO: real call ──
    // final response = await http.post(Uri.parse('YOUR_MODEL_ENDPOINT'), ...);
    // Parse response for: classification, confidence

    final id = _db.collection('image_analysis').doc().id;
    final analysis = ImageAnalysis(
      analysisID: id,
      classification: sim.classification,
      notes: sim.notes,
      confidence: sim.confidence,
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
    if (demoMode) return Stream.value([]);
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
