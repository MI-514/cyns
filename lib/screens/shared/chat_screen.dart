import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/firestore_collections.dart';
import '../../core/services/storage_service.dart';
import '../../core/widgets/app_network_image.dart';
import '../../data/models/message_model.dart';
import '../../data/models/service_request_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import 'agora_call_screen.dart';
import 'map_tracking_screen.dart';

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

  void _makeInAppVoiceCall() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AgoraCallScreen(
          channelId: widget.requestId,
          peerName: widget.peerName,
          peerRole: widget.peerRole,
          isVideoCall: false,
        ),
      ),
    );
  }

  void _startInAppVideoCall() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AgoraCallScreen(
          channelId: widget.requestId,
          peerName: widget.peerName,
          peerRole: widget.peerRole,
          isVideoCall: true,
        ),
      ),
    );
  }

  void _openLiveMapTracking() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.serviceRequests)
          .doc(widget.requestId)
          .get();

      if (doc.exists && doc.data() != null) {
        ServiceRequestModel req = ServiceRequestModel.fromMap(
            doc.data() as Map<String, dynamic>, doc.id);
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MapTrackingScreen(request: req),
          ),
        );
        return;
      }
    } catch (_) {}

    if (!mounted) return;
    ServiceRequestModel dummyReq = ServiceRequestModel(
      id: widget.requestId,
      customerId: 'c1',
      customerName: 'Customer',
      customerPhone: widget.peerPhone ?? '',
      workerId: 'w1',
      workerName: widget.peerName,
      workerPhone: widget.peerPhone ?? '',
      categoryId: 'cat',
      categoryName: 'Service',
      problemDescription: '',
      customerLat: 31.5204,
      customerLng: 74.3587,
      customerAddress: 'Gulberg III, Lahore',
      workerLat: 31.5050,
      workerLng: 74.3450,
      status: 'accepted',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapTrackingScreen(request: dummyReq),
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
                child: AppNetworkImage(imageUrl: imageUrl, fit: BoxFit.contain),
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
            tooltip: 'In-App Voice Call',
            onPressed: _makeInAppVoiceCall,
          ),
          IconButton(
            icon: const Icon(Icons.videocam, size: 28),
            tooltip: 'In-App Video Call',
            onPressed: _startInAppVideoCall,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Banner for Verbal Explanation & Live Map Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.accentBlue.withValues(alpha: 0.1),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 20, color: AppColors.primaryNavy),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'In-App Voice & Video calls ready! Tap call icon above to talk.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  icon: const Icon(Icons.map, size: 16),
                  label: const Text('Live Map', style: TextStyle(fontSize: 12)),
                  onPressed: _openLiveMapTracking,
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
                                  fontSize: 16,
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
                                  child: AppNetworkImage(
                                    imageUrl: msg.attachmentUrl!,
                                    height: 180,
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
