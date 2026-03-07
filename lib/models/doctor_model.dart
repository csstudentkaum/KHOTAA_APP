import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

/// Doctor model class - extends UserModel
/// Represents a doctor in the system with professional attributes.
/// Maps to the 'users' collection (role='doctor').
///
/// Relationships (from UML):
/// - Doctor conducts 0..* Consultations
/// - Doctor (as User) uploads 0..* MedicalImages
class DoctorModel extends UserModel {
  final String? specialtyLevel;
  final String? degree;
  final String? hospitalName;
  final List<String> patientIds; // References to Patient documents

  DoctorModel({
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
    this.specialtyLevel,
    this.degree,
    this.hospitalName,
    this.patientIds = const [],
  }) : super(role: 'doctor');

  /// Create a DoctorModel from Firestore document snapshot
  factory DoctorModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DoctorModel(
      id: doc.id,
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      dateOfBirth: data['dateOfBirth'] != null
          ? (data['dateOfBirth'] as Timestamp).toDate()
          : null,
      age: data['age'],
      gender: data['gender'],
      phone: data['phone'] ?? '',
      password: data['password'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      specialtyLevel: data['specialtyLevel'],
      degree: data['degree'],
      hospitalName: data['hospitalName'],
      patientIds: List<String>.from(data['patientIds'] ?? []),
    );
  }

  /// Create a DoctorModel from a Map
  factory DoctorModel.fromMap(Map<String, dynamic> data, String id) {
    return DoctorModel(
      id: id,
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      dateOfBirth: data['dateOfBirth'] != null
          ? (data['dateOfBirth'] as Timestamp).toDate()
          : null,
      age: data['age'],
      gender: data['gender'],
      phone: data['phone'] ?? '',
      password: data['password'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      specialtyLevel: data['specialtyLevel'],
      degree: data['degree'],
      hospitalName: data['hospitalName'],
      patientIds: List<String>.from(data['patientIds'] ?? []),
    );
  }

  /// Convert DoctorModel to a Map for Firestore
  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll({
      'specialtyLevel': specialtyLevel,
      'degree': degree,
      'hospitalName': hospitalName,
      'patientIds': patientIds,
    });
    return map;
  }

  /// Create a copy with updated fields
  DoctorModel copyWithDoctor({
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
    String? specialtyLevel,
    String? degree,
    String? hospitalName,
    List<String>? patientIds,
  }) {
    return DoctorModel(
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
      specialtyLevel: specialtyLevel ?? this.specialtyLevel,
      degree: degree ?? this.degree,
      hospitalName: hospitalName ?? this.hospitalName,
      patientIds: patientIds ?? this.patientIds,
    );
  }

  @override
  String toString() {
    return 'DoctorModel(id: $id, name: $fullName, specialty: $specialtyLevel, hospital: $hospitalName)';
  }
}
