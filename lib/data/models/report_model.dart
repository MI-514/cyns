import 'package:cloud_firestore/cloud_firestore.dart';

class ReportModel {
  final String id;
  final String reporterId;
  final String reporterRole;
  final String reportedUserId;
  final String reportedUserName;
  final String? requestId;
  final String reason;
  final String details;
  final String status; // Pending, Resolved, Dismissed
  final DateTime createdAt;

  ReportModel({
    required this.id,
    required this.reporterId,
    required this.reporterRole,
    required this.reportedUserId,
    required this.reportedUserName,
    this.requestId,
    required this.reason,
    required this.details,
    this.status = 'Pending',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reporterId': reporterId,
      'reporterRole': reporterRole,
      'reportedUserId': reportedUserId,
      'reportedUserName': reportedUserName,
      'requestId': requestId,
      'reason': reason,
      'details': details,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory ReportModel.fromMap(Map<String, dynamic> map, String docId) {
    return ReportModel(
      id: docId,
      reporterId: map['reporterId'] ?? '',
      reporterRole: map['reporterRole'] ?? '',
      reportedUserId: map['reportedUserId'] ?? '',
      reportedUserName: map['reportedUserName'] ?? '',
      requestId: map['requestId'],
      reason: map['reason'] ?? '',
      details: map['details'] ?? '',
      status: map['status'] ?? 'Pending',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
