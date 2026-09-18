import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceRequestModel {
  final String id;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String workerId;
  final String workerName;
  final String workerPhone;
  final String categoryId;
  final String categoryName;
  final String problemDescription;
  final String? attachmentUrl;
  final double customerLat;
  final double customerLng;
  final String customerAddress;
  final double? workerLat;
  final double? workerLng;
  final String status; // Pending, Accepted, Rejected, Cancelled, On the Way, Arrived, In Progress, Completed
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? estimatedArrivalTime;
  final double? distanceKm;
  final bool hasBeenReviewed;

  ServiceRequestModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.workerId,
    required this.workerName,
    required this.workerPhone,
    required this.categoryId,
    required this.categoryName,
    required this.problemDescription,
    this.attachmentUrl,
    required this.customerLat,
    required this.customerLng,
    required this.customerAddress,
    this.workerLat,
    this.workerLng,
    required this.status,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.estimatedArrivalTime,
    this.distanceKm,
    this.hasBeenReviewed = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  static DateTime _parseDate(dynamic val) {
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
    return DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'workerId': workerId,
      'workerName': workerName,
      'workerPhone': workerPhone,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'problemDescription': problemDescription,
      'attachmentUrl': attachmentUrl,
      'customerLat': customerLat,
      'customerLng': customerLng,
      'customerAddress': customerAddress,
      'workerLat': workerLat,
      'workerLng': workerLng,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'estimatedArrivalTime': estimatedArrivalTime,
      'distanceKm': distanceKm,
      'hasBeenReviewed': hasBeenReviewed,
    };
  }

  factory ServiceRequestModel.fromMap(Map<String, dynamic> map, String docId) {
    return ServiceRequestModel(
      id: docId,
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerPhone: map['customerPhone'] ?? '',
      workerId: map['workerId'] ?? '',
      workerName: map['workerName'] ?? '',
      workerPhone: map['workerPhone'] ?? '',
      categoryId: map['categoryId'] ?? '',
      categoryName: map['categoryName'] ?? '',
      problemDescription: map['problemDescription'] ?? '',
      attachmentUrl: map['attachmentUrl'],
      customerLat: (map['customerLat'] as num?)?.toDouble() ?? 0.0,
      customerLng: (map['customerLng'] as num?)?.toDouble() ?? 0.0,
      customerAddress: map['customerAddress'] ?? '',
      workerLat: (map['workerLat'] as num?)?.toDouble(),
      workerLng: (map['workerLng'] as num?)?.toDouble(),
      status: map['status'] ?? 'Pending',
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
      estimatedArrivalTime: map['estimatedArrivalTime'],
      distanceKm: (map['distanceKm'] as num?)?.toDouble(),
      hasBeenReviewed: map['hasBeenReviewed'] ?? false,
    );
  }
}
