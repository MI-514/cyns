import 'package:cloud_firestore/cloud_firestore.dart';

class WorkerProfileModel {
  final String workerId;
  final String username;
  final String name;
  final String fatherName;
  final String phoneNumber;
  final String address;
  final String cnicNumber;
  final String profilePicUrl;
  final String profession;
  final List<String> categoryIds;
  final List<String> skills;
  final int experienceYears;
  final String serviceDescription;
  final String workingArea;
  final bool isAvailable;
  final double? latitude;
  final double? longitude;
  final double rating;
  final int reviewCount;
  final int completedJobsCount;
  final bool isApproved;
  final DateTime createdAt;

  WorkerProfileModel({
    required this.workerId,
    this.username = '',
    required this.name,
    this.fatherName = '',
    required this.phoneNumber,
    this.address = '',
    this.cnicNumber = '',
    this.profilePicUrl = '',
    required this.profession,
    required this.categoryIds,
    required this.skills,
    this.experienceYears = 1,
    required this.serviceDescription,
    required this.workingArea,
    this.isAvailable = true,
    this.latitude,
    this.longitude,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.completedJobsCount = 0,
    this.isApproved = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  static DateTime _parseDate(dynamic val) {
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
    return DateTime.now();
  }

  WorkerProfileModel copyWith({
    String? workerId,
    String? username,
    String? name,
    String? fatherName,
    String? phoneNumber,
    String? address,
    String? cnicNumber,
    String? profilePicUrl,
    String? profession,
    List<String>? categoryIds,
    List<String>? skills,
    int? experienceYears,
    String? serviceDescription,
    String? workingArea,
    bool? isAvailable,
    double? latitude,
    double? longitude,
    double? rating,
    int? reviewCount,
    int? completedJobsCount,
    bool? isApproved,
    DateTime? createdAt,
  }) {
    return WorkerProfileModel(
      workerId: workerId ?? this.workerId,
      username: username ?? this.username,
      name: name ?? this.name,
      fatherName: fatherName ?? this.fatherName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      cnicNumber: cnicNumber ?? this.cnicNumber,
      profilePicUrl: profilePicUrl ?? this.profilePicUrl,
      profession: profession ?? this.profession,
      categoryIds: categoryIds ?? this.categoryIds,
      skills: skills ?? this.skills,
      experienceYears: experienceYears ?? this.experienceYears,
      serviceDescription: serviceDescription ?? this.serviceDescription,
      workingArea: workingArea ?? this.workingArea,
      isAvailable: isAvailable ?? this.isAvailable,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      completedJobsCount: completedJobsCount ?? this.completedJobsCount,
      isApproved: isApproved ?? this.isApproved,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'workerId': workerId,
      'username': username,
      'name': name,
      'fatherName': fatherName,
      'phoneNumber': phoneNumber,
      'address': address,
      'cnicNumber': cnicNumber,
      'profilePicUrl': profilePicUrl,
      'profession': profession,
      'categoryIds': categoryIds,
      'skills': skills,
      'experienceYears': experienceYears,
      'serviceDescription': serviceDescription,
      'workingArea': workingArea,
      'isAvailable': isAvailable,
      'latitude': latitude,
      'longitude': longitude,
      'rating': rating,
      'reviewCount': reviewCount,
      'completedJobsCount': completedJobsCount,
      'isApproved': isApproved,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory WorkerProfileModel.fromMap(Map<String, dynamic> map, String docId) {
    return WorkerProfileModel(
      workerId: docId,
      username: map['username'] ?? '',
      name: map['name'] ?? '',
      fatherName: map['fatherName'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      address: map['address'] ?? '',
      cnicNumber: map['cnicNumber'] ?? '',
      profilePicUrl: map['profilePicUrl'] ?? '',
      profession: map['profession'] ?? '',
      categoryIds: List<String>.from(map['categoryIds'] ?? []),
      skills: List<String>.from(map['skills'] ?? []),
      experienceYears: map['experienceYears'] ?? 1,
      serviceDescription: map['serviceDescription'] ?? '',
      workingArea: map['workingArea'] ?? map['address'] ?? '',
      isAvailable: map['isAvailable'] ?? true,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: map['reviewCount'] ?? 0,
      completedJobsCount: map['completedJobsCount'] ?? 0,
      isApproved: map['isApproved'] ?? true,
      createdAt: _parseDate(map['createdAt']),
    );
  }
}
