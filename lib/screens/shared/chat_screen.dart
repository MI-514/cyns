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
            const Icon(Icons.videocam, size: 52, color: AppColors.primaryNavy),
        title: Text('Video Call - ${widget.peerName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Show your problem live on video camera to explain the issue clearly to the worker!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            if (widget.peerPhone != null)
              Text(
                'Phone: ${widget.peerPhone}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(fontSize: 15)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.availableGreen,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            icon: const Icon(Icons.call, size: 20),
            label: const Text('Call Direct', style: TextStyle(fontSize: 15)),
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

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  void _viewFullImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: Center(
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
            IconButton(
              padding: const EdgeInsets.all(16),
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chat with ${widget.peerName}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Tap phone or video icon to call directly',
              style: TextStyle(fontSize: 11, color: AppColors.textLight),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_in_talk, size: 26),
            tooltip: 'Phone Call',
            onPressed: _makePhoneCall,
          ),
          IconButton(
            icon: const Icon(Icons.videocam, size: 28),
            tooltip: 'Video Call',
            onPressed: _startVideoCall,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Banner for Verbal Explanation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.accentBlue.withValues(alpha: 0.1),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 20, color: AppColors.primaryNavy),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Send photos or tap phone/video icon above to call and explain issues verbally!',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
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
                      'No messages yet. Type a message, attach photo, or call directly above!',
                      style: TextStyle(color: AppColors.textLight, fontSize: 15),
                      textAlign: TextAlign.center,
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
                            horizontal: 16, vertical: 12),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.78,
                        ),
                        decoration: BoxDecoration(
                          color: isMe
                              ? AppColors.primaryNavy
                              : AppColors.pureWhite,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isMe ? 16 : 4),
                            bottomRight: Radius.circular(isMe ? 4 : 16),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
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
                                  fontSize: 16, // Larger readable font
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            if (msg.attachmentUrl != null) ...[
                              if (msg.message.isNotEmpty)
                                const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () => _viewFullImage(msg.attachmentUrl!),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    msg.attachmentUrl!,
                                    height: 180, // Larger image attachment preview
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
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

          // Selected Image Preview Banner
          if (_selectedImage != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.black12,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_selectedImage!,
                        height: 60, width: 60, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Photo Attached',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red, size: 24),
                    onPressed: () => setState(() => _selectedImage = null),
                  )
                ],
              ),
            ),

          // Larger Bottom Input & Buttons Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.pureWhite,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Camera Button
                IconButton(
                  icon: const Icon(Icons.add_a_photo,
                      color: AppColors.primaryNavy, size: 26),
                  tooltip: 'Take Photo',
                  onPressed: () => _pickImage(ImageSource.camera),
                ),
                // Gallery Button
                IconButton(
                  icon: const Icon(Icons.photo_library,
                      color: AppColors.primaryNavy, size: 26),
                  tooltip: 'Pick Gallery Photo',
                  onPressed: () => _pickImage(ImageSource.gallery),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.offWhite,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.dividerColor),
                    ),
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(fontSize: 16),
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Send Button Container
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.primaryNavy,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: _isSending
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send,
                            color: AppColors.pureWhite, size: 22),
                    onPressed: _isSending ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
