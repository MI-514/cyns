import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String username;
  final String fullName;
  final String phoneNumber;
  final String role; // customer, worker
  final String profilePicUrl;
  final bool isVerified;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.username,
    required this.fullName,
    required this.phoneNumber,
    required this.role,
    this.profilePicUrl = '',
    this.isVerified = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  static DateTime _parseDate(dynamic val) {
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
    return DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'username': username.trim().toLowerCase(),
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'role': role,
      'profilePicUrl': profilePicUrl,
      'isVerified': isVerified,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String docId) {
    return UserModel(
      uid: docId,
      email: map['email']?.toString() ?? '',
      username: map['username']?.toString() ?? '',
      fullName: map['fullName']?.toString() ?? '',
      phoneNumber: map['phoneNumber']?.toString() ?? '',
      role: map['role']?.toString() ?? 'customer',
      profilePicUrl: map['profilePicUrl']?.toString() ?? '',
      isVerified: map['isVerified'] == true || map['isVerified'] == 'true',
      createdAt: _parseDate(map['createdAt']),
    );
  }
}
