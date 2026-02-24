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

  /// Currently returns a simulated Wagner-grade result.
  /// Replace the body with an HTTP call to your deployed model.
  Future<ImageAnalysis> analyse(MedicalImages image) async {
    final uid = _uid ?? 'demo-user';

    final sim = _simulate();

    if (demoMode) {
      await Future.delayed(const Duration(milliseconds: 1500));
      return ImageAnalysis(
        analysisID: 'demo_a_${DateTime.now().millisecondsSinceEpoch}',
        wagnerGrade: sim.grade,
        notes: sim.notes,
        confidence: sim.confidence,
        modelName: 'DFU-CNN-v1',
        imageId: image.imageID,
        patientId: uid,
      );
    }

    // ── TODO: real call ──

    final id = _db.collection('image_analysis').doc().id;
    final analysis = ImageAnalysis(
      analysisID: id,
      wagnerGrade: sim.grade,
      notes: sim.notes,
      confidence: sim.confidence,
      modelName: 'DFU-CNN-v1',
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
    final w = [40, 25, 15, 10, 7, 3]; // weighted distribution
    var pick = r.nextInt(w.reduce((a, b) => a + b));
    int grade = 0;
    for (var i = 0; i < w.length; i++) {
      pick -= w[i];
      if (pick < 0) {
        grade = i;
        break;
      }
    }
    return _SimResult(
      grade: grade,
      confidence: 0.85 + r.nextDouble() * 0.14,
      notes: _noteFor(grade),
    );
  }

  String _noteFor(int g) => switch (g) {
        0 => 'No ulceration detected. Skin appears intact.',
        1 => 'Superficial ulcer. Limited to skin surface.',
        2 => 'Deep ulcer reaching tendon or bone.',
        3 => 'Deep ulcer with abscess or osteomyelitis.',
        4 => 'Partial foot gangrene. Surgical consult needed.',
        5 => 'Extensive gangrene. Emergency care required.',
        _ => 'Consult a healthcare provider.',
      };
}

class _SimResult {
  final int grade;
  final double confidence;
  final String notes;
  const _SimResult({
    required this.grade,
    required this.confidence,
    required this.notes,
  });
}
