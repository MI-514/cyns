import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id; // requestId
  final String requestId;
  final String customerId;
  final String workerId;
  final String customerName;
  final String workerName;
  final String lastMessage;
  final DateTime lastMessageTime;

  ChatModel({
    required this.id,
    required this.requestId,
    required this.customerId,
    required this.workerId,
    required this.customerName,
    required this.workerName,
    this.lastMessage = '',
    DateTime? lastMessageTime,
  }) : lastMessageTime = lastMessageTime ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'requestId': requestId,
      'customerId': customerId,
      'workerId': workerId,
      'customerName': customerName,
      'workerName': workerName,
      'lastMessage': lastMessage,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
    };
  }

  factory ChatModel.fromMap(Map<String, dynamic> map, String docId) {
    return ChatModel(
      id: docId,
      requestId: map['requestId'] ?? docId,
      customerId: map['customerId'] ?? '',
      workerId: map['workerId'] ?? '',
      customerName: map['customerName'] ?? '',
      workerName: map['workerName'] ?? '',
      lastMessage: map['lastMessage'] ?? '',
      lastMessageTime: map['lastMessageTime'] != null
          ? (map['lastMessageTime'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
