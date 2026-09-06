import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/storage_service.dart';
import '../../data/models/message_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';

class ChatScreen extends StatefulWidget {
  final String requestId;
  final String peerName;
  final String peerRole;
  final String? peerPhone;

  const ChatScreen({
    super.key,
    required this.requestId,
    required this.peerName,
    required this.peerRole,
    this.peerPhone,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  File? _selectedImage;
  bool _isSending = false;

  Future<void> _makePhoneCall() async {
    final phone = widget.peerPhone ?? '';
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Phone number not available for this user.')),
      );
      return;
    }
    final Uri telUri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(telUri)) {
      await launchUrl(telUri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch phone call to $phone')),
      );
    }
  }

  void _startVideoCall() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon:
            const Icon(Icons.videocam, size: 48, color: AppColors.primaryNavy),
        title: Text('Video Call - ${widget.peerName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Show your problem live on video camera to explain the issue clearly to the worker!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            if (widget.peerPhone != null)
              Text(
                'Phone: ${widget.peerPhone}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.availableGreen),
            icon: const Icon(Icons.call),
            label: const Text('Call Direct'),
            onPressed: () {
              Navigator.pop(ctx);
              _makePhoneCall();
            },
          ),
        ],
      ),
    );
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _selectedImage == null) return;

    setState(() => _isSending = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    String? attachmentUrl;
    if (_selectedImage != null) {
      attachmentUrl = await StorageService.uploadImage(
        file: _selectedImage!,
        folder: 'chat_attachments',
        filename: 'chat_${DateTime.now().millisecondsSinceEpoch}',
      );
    }

    await chatProvider.sendMessage(
      chatId: widget.requestId,
      senderId: auth.userModel?.uid ?? '',
      senderName: auth.userModel?.fullName ?? 'User',
      senderRole: auth.userModel?.role ?? 'customer',
      message: text,
      attachmentUrl: attachmentUrl,
    );

    _messageController.clear();
    setState(() {
      _selectedImage = null;
      _isSending = false;
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chat with ${widget.peerName}'),
            const Text(
              'Tap phone/video icon to call & explain problem',
              style: TextStyle(fontSize: 10, color: AppColors.textLight),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_in_talk),
            tooltip: 'Phone Call',
            onPressed: _makePhoneCall,
          ),
          IconButton(
            icon: const Icon(Icons.videocam),
            tooltip: 'Video Call',
            onPressed: _startVideoCall,
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner for Verbal Explanation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.accentBlue.withValues(alpha: 0.1),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 18, color: AppColors.primaryNavy),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Worker unlettered or prefer voice? Tap phone or video icon above to call directly.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Message List
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: chatProvider.getMessages(widget.requestId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet. Send a message or call directly above!',
                      style: TextStyle(color: AppColors.textLight),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    bool isMe = msg.senderId == auth.userModel?.uid;

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: isMe
                              ? AppColors.primaryNavy
                              : AppColors.pureWhite,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(14),
                            topRight: const Radius.circular(14),
                            bottomLeft: Radius.circular(isMe ? 14 : 2),
                            bottomRight: Radius.circular(isMe ? 2 : 14),
                          ),
                          border: isMe
                              ? null
                              : Border.all(color: AppColors.dividerColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (msg.message.isNotEmpty)
                              Text(
                                msg.message,
                                style: TextStyle(
                                  color: isMe
                                      ? AppColors.pureWhite
                                      : AppColors.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                            if (msg.attachmentUrl != null) ...[
                              if (msg.message.isNotEmpty)
                                const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  msg.attachmentUrl!,
                                  height: 140,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          if (_selectedImage != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black12,
              child: Row(
                children: [
                  Image.file(_selectedImage!, height: 50, width: 50, fit: BoxFit.cover),
                  const SizedBox(width: 8),
                  const Text('Photo selected'),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _selectedImage = null),
                  )
                ],
              ),
            ),

          // Message Input Field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: AppColors.pureWhite,
              border: Border(top: BorderSide(color: AppColors.dividerColor)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file, color: AppColors.primaryNavy),
                  onPressed: _pickImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
                IconButton(
                  icon: _isSending
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send, color: AppColors.primaryNavy),
                  onPressed: _isSending ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
