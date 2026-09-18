import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String id;
  final String requestId;
  final String workerId;
  final String customerId;
  final String customerName;
  final String customerProfilePic;
  final double rating;
  final String reviewText;
  final DateTime createdAt;

  ReviewModel({
    required this.id,
    required this.requestId,
    required this.workerId,
    required this.customerId,
    required this.customerName,
    this.customerProfilePic = '',
    required this.rating,
    required this.reviewText,
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
      'id': id,
      'requestId': requestId,
      'workerId': workerId,
      'customerId': customerId,
      'customerName': customerName,
      'customerProfilePic': customerProfilePic,
      'rating': rating,
      'reviewText': reviewText,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory ReviewModel.fromMap(Map<String, dynamic> map, String docId) {
    return ReviewModel(
      id: docId,
      requestId: map['requestId'] ?? '',
      workerId: map['workerId'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerProfilePic: map['customerProfilePic'] ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
      reviewText: map['reviewText'] ?? '',
      createdAt: _parseDate(map['createdAt']),
    );
  }
}
