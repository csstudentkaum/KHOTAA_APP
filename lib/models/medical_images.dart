import 'package:cloud_firestore/cloud_firestore.dart';
import 'image_analysis.dart';

class MedicalImages {
  final String imageID;
  final DateTime uploadedAt;
  final String filePath;

  // Relationships
  final String patientId; // FK → Patient (Patient UPLOADS MedicalImages)

  // Relationship: MedicalImages HAS ImageAnalysis (1 to 1)
  ImageAnalysis? analysis;

  MedicalImages({
    required this.imageID,
    required this.uploadedAt,
    required this.filePath,
    required this.patientId,
    this.analysis,
  });

  factory MedicalImages.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MedicalImages(
      imageID: doc.id,
      uploadedAt: (data['uploadedAt'] as Timestamp).toDate(),
      filePath: data['filePath'] ?? '',
      patientId: data['patientId'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'filePath': filePath,
      'patientId': patientId, // FK → Patient
    };
  }

  // Fetch analysis for this image
  static Future<ImageAnalysis?> fetchAnalysis(
    FirebaseFirestore db,
    String imageId,
  ) async {
    final snapshot = await db
        .collection('image_analysis')
        .where('imageId', isEqualTo: imageId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return ImageAnalysis.fromFirestore(snapshot.docs.first);
  }

  // Load image WITH its analysis in one call
  static Future<MedicalImages> withAnalysis(
    FirebaseFirestore db,
    DocumentSnapshot doc,
  ) async {
    final image = MedicalImages.fromFirestore(doc);
    image.analysis = await fetchAnalysis(db, doc.id);
    return image;
  }

  bool get hasAnalysis => analysis != null;
}
