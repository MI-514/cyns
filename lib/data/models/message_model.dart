import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final String senderRole; // customer / worker
  final String message;
  final String? attachmentUrl;
  final String? audioUrl;
  final int? audioDurationSec;
  final DateTime timestamp;

  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.message,
    this.attachmentUrl,
    this.audioUrl,
    this.audioDurationSec,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

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
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'message': message,
      'attachmentUrl': attachmentUrl,
      'audioUrl': audioUrl,
      'audioDurationSec': audioDurationSec,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map, String docId) {
    return MessageModel(
      id: docId,
      chatId: map['chatId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      senderRole: map['senderRole'] ?? '',
      message: map['message'] ?? '',
      attachmentUrl: map['attachmentUrl'],
      audioUrl: map['audioUrl'],
      audioDurationSec: (map['audioDurationSec'] as num?)?.toInt(),
      timestamp: _parseDate(map['timestamp']),
    );
  }
}
