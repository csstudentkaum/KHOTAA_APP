import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

/// Patient model class - extends UserModel
/// Represents a patient in the system with medical-specific attributes.
/// Maps to the 'users' collection (role='patient') with a subcollection 'devices'.
///
/// Relationships (from UML):
/// - Patient undergoes 0..* Consultations
/// - Patient has 1..* Devices
/// - Patient receives 0..* PreventiveRecommendations
/// - Patient obtains 0..* WeeklyReports
/// - Patient (as User) uploads 0..* MedicalImages
class PatientModel extends UserModel {
  final String? medicationHistory;
  final double? height;
  final double? weight;
  final double? bmi;
  final int? diabetesType;
  final int? diabetesDuration;
  final List<String> deviceIds; // References to Device documents

  PatientModel({
    required super.id,
    required super.firstName,
    required super.lastName,
    super.dateOfBirth,
    super.age,
    super.gender,
    required super.phone,
    super.password,
    super.createdAt,
    super.updatedAt,
    this.medicationHistory,
    this.height,
    this.weight,
    this.bmi,
    this.diabetesType,
    this.diabetesDuration,
    this.deviceIds = const [],
  }) : super(role: 'patient');

  /// Calculate BMI from height and weight
  double? calculateBMI() {
    if (height != null && weight != null && height! > 0) {
      // height in cm, weight in kg
      final heightInMeters = height! / 100;
      return weight! / (heightInMeters * heightInMeters);
    }
    return null;
  }

  /// Create a PatientModel from Firestore document snapshot
  factory PatientModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PatientModel(
      id: doc.id,
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      dateOfBirth: data['dateOfBirth'] != null
          ? (data['dateOfBirth'] as Timestamp).toDate()
          : null,
      age: (data['age'] as num?)?.toInt(),
      gender: data['gender'],
      phone: data['phone'] ?? '',
      password: data['password'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      medicationHistory: data['medicationHistory'],
      height: (data['height'] as num?)?.toDouble(),
      weight: (data['weight'] as num?)?.toDouble(),
      bmi: (data['bmi'] as num?)?.toDouble(),
      diabetesType: data['diabetesType'],
      diabetesDuration: data['diabetesDuration'],
      deviceIds: List<String>.from(data['deviceIds'] ?? []),
    );
  }

  /// Create a PatientModel from a Map
  factory PatientModel.fromMap(Map<String, dynamic> data, String id) {
    return PatientModel(
      id: id,
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      dateOfBirth: data['dateOfBirth'] != null
          ? (data['dateOfBirth'] as Timestamp).toDate()
          : null,
      age: (data['age'] as num?)?.toInt(),
      gender: data['gender'],
      phone: data['phone'] ?? '',
      password: data['password'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      medicationHistory: data['medicationHistory'],
      height: (data['height'] as num?)?.toDouble(),
      weight: (data['weight'] as num?)?.toDouble(),
      bmi: (data['bmi'] as num?)?.toDouble(),
      diabetesType: data['diabetesType'],
      diabetesDuration: data['diabetesDuration'],
      deviceIds: List<String>.from(data['deviceIds'] ?? []),
    );
  }

  /// Convert PatientModel to a Map for Firestore
  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll({
      'medicationHistory': medicationHistory,
      'height': height,
      'weight': weight,
      'bmi': bmi ?? calculateBMI(),
      'diabetesType': diabetesType,
      'diabetesDuration': diabetesDuration,
      'deviceIds': deviceIds,
    });
    return map;
  }

  /// Create a copy with updated fields
  PatientModel copyWithPatient({
    String? id,
    String? firstName,
    String? lastName,
    DateTime? dateOfBirth,
    int? age,
    String? gender,
    String? phone,
    String? password,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? medicationHistory,
    double? height,
    double? weight,
    double? bmi,
    int? diabetesType,
    int? diabetesDuration,
    List<String>? deviceIds,
  }) {
    return PatientModel(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      phone: phone ?? this.phone,
      password: password ?? this.password,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      medicationHistory: medicationHistory ?? this.medicationHistory,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      bmi: bmi ?? this.bmi,
      diabetesType: diabetesType ?? this.diabetesType,
      diabetesDuration: diabetesDuration ?? this.diabetesDuration,
      deviceIds: deviceIds ?? this.deviceIds,
    );
  }

  @override
  String toString() {
    return 'PatientModel(id: $id, name: $fullName, diabetesType: $diabetesType, BMI: ${bmi ?? calculateBMI()})';
  }
}
