import 'package:cloud_firestore/cloud_firestore.dart';
import 'medical_images.dart';

class ImageAnalysis {
  final String analysisID;
  final int wagnerGrade;
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
    required this.wagnerGrade,
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
      wagnerGrade: data['wagner_grade'] ?? 0,
      notes: data['notes'] ?? '',
      confidence: (data['confidence'] ?? 0.0).toDouble(),
      modelName: data['model_name'] ?? '',
      imageId: data['imageId'] ?? '', // FK → MedicalImages
      patientId: data['patientId'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'wagner_grade': wagnerGrade,
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
    final imageDoc = await db
        .collection('medical_images')
        .doc(analysis.imageId)
        .get();
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

  // Wagner grade label
  String get wagnerGradeLabel {
    switch (wagnerGrade) {
      case 0:
        return 'Grade 0 - No Ulcer';
      case 1:
        return 'Grade 1 - Superficial Ulcer';
      case 2:
        return 'Grade 2 - Deep Ulcer';
      case 3:
        return 'Grade 3 - Deep Ulcer with Infection';
      case 4:
        return 'Grade 4 - Partial Foot Gangrene';
      case 5:
        return 'Grade 5 - Full Foot Gangrene';
      default:
        return 'Unknown';
    }
  }

  // Severity level
  String get severityLevel {
    if (wagnerGrade <= 1) return 'Low';
    if (wagnerGrade <= 3) return 'Medium';
    return 'High';
  }

  // Confidence as percentage string
  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)}%';

  // Whether result needs urgent attention
  bool get isUrgent => wagnerGrade >= 4;
}
