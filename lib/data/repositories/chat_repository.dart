import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firestore_collections.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

class ChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream of chat list for a specific user
  Stream<List<ChatModel>> getUserChats(String userId, String role) {
    String field = role == 'customer' ? 'customerId' : 'workerId';
    return _firestore
        .collection(FirestoreCollections.chats)
        .where(field, isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Stream of real-time messages for a given requestId/chatId
  Stream<List<MessageModel>> getMessages(String chatId) {
    return _firestore
        .collection(FirestoreCollections.chats)
        .doc(chatId)
        .collection(FirestoreCollections.messages)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MessageModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Send a chat message
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String message,
    String? attachmentUrl,
  }) async {
    MessageModel msg = MessageModel(
      id: '',
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      senderRole: senderRole,
      message: message,
      attachmentUrl: attachmentUrl,
    );

    // Add message
    await _firestore
        .collection(FirestoreCollections.chats)
        .doc(chatId)
        .collection(FirestoreCollections.messages)
        .add(msg.toMap());

    // Update last message in chat summary
    await _firestore.collection(FirestoreCollections.chats).doc(chatId).update({
      'lastMessage': message.isNotEmpty ? message : 'Sent an attachment',
      'lastMessageTime': FieldValue.serverTimestamp(),
    });
  }
}
