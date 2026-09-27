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
  final List<String> tags;
  final int tipAmount;
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
    this.tags = const [],
    this.tipAmount = 0,
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
      'tags': tags,
      'tipAmount': tipAmount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory ReviewModel.fromMap(Map<String, dynamic> map, String docId) {
    List<String> parseTags(dynamic val) {
      if (val is List) {
        return val
            .map((e) => e?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
      }
      return [];
    }

    int parseTip(dynamic val) {
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    double parseRating(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 5.0;
      return 5.0;
    }

    return ReviewModel(
      id: docId,
      requestId: map['requestId']?.toString() ?? '',
      workerId: map['workerId']?.toString() ?? '',
      customerId: map['customerId']?.toString() ?? '',
      customerName: map['customerName']?.toString() ?? '',
      customerProfilePic: map['customerProfilePic']?.toString() ?? '',
      rating: parseRating(map['rating']),
      reviewText: map['reviewText']?.toString() ?? '',
      tags: parseTags(map['tags']),
      tipAmount: parseTip(map['tipAmount']),
      createdAt: _parseDate(map['createdAt']),
    );
  }
}
