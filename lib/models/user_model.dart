import 'package:cloud_firestore/cloud_firestore.dart';

/// Base User model class
/// Represents the common attributes shared between Doctor and Patient.
/// Maps to the 'users' collection in Firestore.
class UserModel {
  final String id;
  final String firstName;
  final String lastName;
  final DateTime? dateOfBirth;
  final int? age;
  final String? gender;
  final String phone;
  // [PASSWORD_FEATURE] final String? password; // Uncomment to re-enable password support
  final String role; // 'doctor' or 'patient'
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.dateOfBirth,
    this.age,
    this.gender,
    required this.phone,
    // [PASSWORD_FEATURE] this.password,
    required this.role,
    this.createdAt,
    this.updatedAt,
  });

  /// Create a UserModel from Firestore document snapshot
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      dateOfBirth: data['dateOfBirth'] != null
          ? (data['dateOfBirth'] as Timestamp).toDate()
          : null,
      age: data['age'],
      gender: data['gender'],
      phone: data['phone'] ?? '',
      // [PASSWORD_FEATURE] password: data['password'],
      role: data['role'] ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Create a UserModel from a Map
  factory UserModel.fromMap(Map<String, dynamic> data, String id) {
    return UserModel(
      id: id,
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      dateOfBirth: data['dateOfBirth'] != null
          ? (data['dateOfBirth'] as Timestamp).toDate()
          : null,
      age: data['age'],
      gender: data['gender'],
      phone: data['phone'] ?? '',
      // [PASSWORD_FEATURE] password: data['password'],
      role: data['role'] ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Convert UserModel to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'dateOfBirth':
          dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
      'age': age,
      'gender': gender,
      'phone': phone,
      'role': role,
      'createdAt':
          createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Get the full name of the user
  String get fullName => '$firstName $lastName';

  /// Create a copy with updated fields
  UserModel copyWith({
    String? id,
    String? firstName,
    String? lastName,
    DateTime? dateOfBirth,
    int? age,
    String? gender,
    String? phone,
    // [PASSWORD_FEATURE] String? password,
    String? role,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      phone: phone ?? this.phone,
      // [PASSWORD_FEATURE] password: password ?? this.password,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, name: $fullName, role: $role, phone: $phone)';
  }
}
