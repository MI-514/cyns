import 'package:flutter/material.dart';
import '../data/models/chat_model.dart';
import '../data/models/message_model.dart';
import '../data/repositories/chat_repository.dart';

class ChatProvider extends ChangeNotifier {
  final ChatRepository _repository = ChatRepository();

  Stream<List<ChatModel>> getUserChats(String userId, String role) {
    return _repository.getUserChats(userId, role);
  }

  Stream<List<MessageModel>> getMessages(String chatId) {
    return _repository.getMessages(chatId);
  }

  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String message,
    String? attachmentUrl,
    String? audioUrl,
    int? audioDurationSec,
  }) async {
    await _repository.sendMessage(
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      senderRole: senderRole,
      message: message,
      attachmentUrl: attachmentUrl,
      audioUrl: audioUrl,
      audioDurationSec: audioDurationSec,
    );
  }
}
