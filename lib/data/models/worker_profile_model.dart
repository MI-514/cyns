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
    List<String> parseStringList(dynamic val) {
      if (val is List) {
        return val
            .map((e) => e?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
      } else if (val is String && val.isNotEmpty) {
        return [val];
      }
      return [];
    }

    int parseInt(dynamic val, [int defaultValue = 0]) {
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? defaultValue;
      return defaultValue;
    }

    double parseDouble(dynamic val, [double defaultValue = 0.0]) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? defaultValue;
      return defaultValue;
    }

    double? parseNullableDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      if (val is String && val.isNotEmpty) return double.tryParse(val);
      return null;
    }

    return WorkerProfileModel(
      workerId: docId,
      username: map['username']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      fatherName: map['fatherName']?.toString() ?? '',
      phoneNumber: map['phoneNumber']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      cnicNumber: map['cnicNumber']?.toString() ?? '',
      profilePicUrl: map['profilePicUrl']?.toString() ?? '',
      profession: map['profession']?.toString() ?? '',
      categoryIds: parseStringList(map['categoryIds']),
      skills: parseStringList(map['skills']),
      experienceYears: parseInt(map['experienceYears'], 1),
      serviceDescription: map['serviceDescription']?.toString() ?? '',
      workingArea: (map['workingArea'] ?? map['address'])?.toString() ?? '',
      isAvailable: map['isAvailable'] == true ||
          map['isAvailable'] == null ||
          map['isAvailable'] == 'true',
      latitude: parseNullableDouble(map['latitude']),
      longitude: parseNullableDouble(map['longitude']),
      rating: parseDouble(map['rating'], 0.0),
      reviewCount: parseInt(map['reviewCount'], 0),
      completedJobsCount: parseInt(map['completedJobsCount'], 0),
      isApproved: map['isApproved'] != false && map['isApproved'] != 'false',
      createdAt: _parseDate(map['createdAt']),
    );
  }
}
