import 'package:cloud_firestore/cloud_firestore.dart';
import 'medical_images.dart';

/// The four classes produced by the ulcer-classification model.
enum UlcerClass { none, infection, ischaemia, both }

/// Helper to convert between [UlcerClass] and the string stored in Firestore.
extension UlcerClassX on UlcerClass {
  String get label => switch (this) {
        UlcerClass.none => 'None',
        UlcerClass.infection => 'Infection',
        UlcerClass.ischaemia => 'Ischaemia',
        UlcerClass.both => 'Both',
      };

  static UlcerClass fromString(String s) => switch (s.toLowerCase()) {
        'infection' => UlcerClass.infection,
        'ischaemia' => UlcerClass.ischaemia,
        'both' => UlcerClass.both,
        _ => UlcerClass.none,
      };
}

class ImageAnalysis {
  final String analysisID;
  final UlcerClass classification;
  final String notes;
  final double confidence;
  final String modelName;

  // Relationships
  final String imageId; // FK → MedicalImages (MedicalImages HAS ImageAnalysis)
  final String patientId; // FK → Patient

  // Loaded separately
  MedicalImages? image; // the parent image this analysis belongs to

  ImageAnalysis({
    required this.analysisID,
    required this.classification,
    required this.notes,
    required this.confidence,
    required this.modelName,
    required this.imageId,
    required this.patientId,
    this.image,
  });

  factory ImageAnalysis.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ImageAnalysis(
      analysisID: doc.id,
      classification:
          UlcerClassX.fromString(data['classification'] ?? 'None'),
      notes: data['notes'] ?? '',
      confidence: (data['confidence'] ?? 0.0).toDouble(),
      modelName: data['model_name'] ?? '',
      imageId: data['imageId'] ?? '', // FK → MedicalImages
      patientId: data['patientId'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'classification': classification.label,
      'notes': notes,
      'confidence': confidence,
      'model_name': modelName,
      'imageId': imageId, // FK → MedicalImages
      'patientId': patientId, // FK → Patient
    };
  }

  // Load analysis WITH its parent image
  static Future<ImageAnalysis> withImage(
    FirebaseFirestore db,
    DocumentSnapshot doc,
  ) async {
    final analysis = ImageAnalysis.fromFirestore(doc);
    final imageDoc =
        await db.collection('medical_images').doc(analysis.imageId).get();
    if (imageDoc.exists) {
      analysis.image = MedicalImages.fromFirestore(imageDoc);
    }
    return analysis;
  }

  // Get all analyses for a patient ordered by date
  static Stream<List<ImageAnalysis>> streamPatientAnalyses(
    FirebaseFirestore db,
    String patientId,
  ) {
    return db
        .collection('image_analysis')
        .where('patientId', isEqualTo: patientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((doc) => ImageAnalysis.fromFirestore(doc)).toList(),
        );
  }

  // ── Derived helpers ───────────────────────────────────────────────

  /// Human-readable classification label.
  String get classificationLabel => classification.label;

  /// Risk level derived from the classification.
  String get riskLevel => switch (classification) {
        UlcerClass.none => 'Low',
        UlcerClass.infection => 'High',
        UlcerClass.ischaemia => 'High',
        UlcerClass.both => 'Critical',
      };

  /// Whether the patient should urgently see a doctor.
  bool get shouldConsultDoctor =>
      classification != UlcerClass.none;

  /// Whether this is a critical / emergency case.
  bool get isCritical => classification == UlcerClass.both;

  /// Short patient-friendly summary of the result.
  String get patientSummary => switch (classification) {
        UlcerClass.none =>
          'Good news — no signs of infection or blood flow problems were '
              'found in your wound. Your ulcer appears stable. Keep taking '
              'good care of your feet and continue to watch for any new '
              'changes like redness, swelling, or unusual colour.',
        UlcerClass.infection =>
          'Signs of infection have been found in your wound. This may '
              'include redness spreading around the wound (especially if it '
              'extends more than 2 cm), warmth, swelling, or discharge. '
              'Wound infections in diabetic feet can progress quickly and '
              'usually require antibiotics prescribed by your doctor. '
              'Do not delay getting medical help.',
        UlcerClass.ischaemia =>
          'Signs of reduced blood flow have been found in your wound. '
              'This means your foot may not be getting enough blood to heal '
              'properly. Nearly half of diabetic foot ulcers involve some '
              'level of poor blood flow. Your doctor may need to check the '
              'circulation in your legs using simple tests like measuring '
              'the pressure at your ankle. Early treatment can help '
              'improve healing.',
        UlcerClass.both =>
          'Your wound shows signs of both infection and reduced blood '
              'flow. This combination is the most serious type of diabetic '
              'foot ulcer and carries the highest risk of complications, '
              'including tissue loss. Without prompt treatment, the wound '
              'can get much worse very quickly. Please seek medical '
              'attention immediately — do not wait.',
      };

  /// Actionable recommendation for the patient.
  String get recommendation => switch (classification) {
        UlcerClass.none =>
          '• Keep your wound clean and covered with a moist dressing — '
              'this helps it heal faster\n'
              '• Change the dressing regularly or as your doctor advised\n'
              '• Check your feet every day — look for new redness, '
              'blisters, or colour changes\n'
              '• Never walk barefoot — always wear well-fitting, '
              'closed shoes\n'
              '• Control your blood sugar — high sugar levels slow '
              'wound healing\n'
              '• Keep attending your regular check-ups',
        UlcerClass.infection =>
          '• See your doctor as soon as possible — infected wounds '
              'usually need antibiotics\n'
              '• Do not apply honey, herbs, or home remedies on the '
              'wound — they can make it worse\n'
              '• Watch for danger signs: redness spreading beyond the '
              'wound edge, bad smell, pus, or fever\n'
              '• Let your doctor clean the wound — do not try to remove '
              'dead tissue yourself\n'
              '• Keep the wound covered with a clean, moist dressing '
              'and change it daily\n'
              '• You can request a consultation with a doctor through '
              'this app for quick guidance',
        UlcerClass.ischaemia =>
          '• Visit your doctor for a blood flow check — a simple '
              'ankle pressure test can help\n'
              '• If you smoke, stop now — smoking is one of the biggest '
              'causes of poor blood flow in the legs\n'
              '• Avoid tight socks, stockings, or shoes that squeeze '
              'your feet or legs\n'
              '• Keep your feet warm naturally — do not use hot water '
              'bottles or heating pads (you may not feel a burn)\n'
              '• Be extra careful to avoid cuts or injuries — wounds '
              'heal much slower with poor blood flow\n'
              '• You can request a consultation with a doctor through '
              'this app for further advice',
        UlcerClass.both =>
          '• Go to the nearest hospital or clinic today — this '
              'cannot wait\n'
              '• Do not try to treat this at home — you need '
              'professional medical care\n'
              '• Both the infection and the blood flow problem must '
              'be treated at the same time\n'
              '• Take this report with you — it will help your doctor '
              'understand your situation quickly\n'
              '• If the wound gets worse rapidly or you feel unwell, '
              'go to the emergency room immediately\n'
              '• You can also request an urgent consultation through '
              'this app right now',
      };

  /// Confidence as percentage string.
  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)}%';
}
