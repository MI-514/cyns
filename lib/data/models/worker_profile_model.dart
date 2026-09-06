import 'package:cloud_firestore/cloud_firestore.dart';

class WorkerProfileModel {
  final String workerId;
  final String name;
  final String phoneNumber;
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
    required this.name,
    required this.phoneNumber,
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

  Map<String, dynamic> toMap() {
    return {
      'workerId': workerId,
      'name': name,
      'phoneNumber': phoneNumber,
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
      name: map['name'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      profilePicUrl: map['profilePicUrl'] ?? '',
      profession: map['profession'] ?? '',
      categoryIds: List<String>.from(map['categoryIds'] ?? []),
      skills: List<String>.from(map['skills'] ?? []),
      experienceYears: map['experienceYears'] ?? 1,
      serviceDescription: map['serviceDescription'] ?? '',
      workingArea: map['workingArea'] ?? '',
      isAvailable: map['isAvailable'] ?? true,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: map['reviewCount'] ?? 0,
      completedJobsCount: map['completedJobsCount'] ?? 0,
      isApproved: map['isApproved'] ?? true,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
