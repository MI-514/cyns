import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/firestore_collections.dart';
import '../../core/services/location_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/widgets/app_network_image.dart';
import '../../data/models/message_model.dart';
import '../../data/models/service_request_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/service_request_provider.dart';
import '../customer/rating_review_screen.dart';
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
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  File? _selectedImage;
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

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

    _scrollToBottom();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (picked != null) {
        setState(() => _selectedImage = File(picked.path));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not access camera or gallery.'),
            backgroundColor: AppColors.statusRejected,
          ),
        );
      }
    }
  }

  void _showBidDialog() {
    final bidController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start Bid / Propose Fare'),
        content: TextField(
          controller: bidController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Enter Fare Amount (PKR)',
            prefixText: 'PKR ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryNavy,
            ),
            onPressed: () {
              final amount = bidController.text.trim();
              if (amount.isNotEmpty) {
                Navigator.pop(ctx);
                _messageController.text =
                    '[BID OFFER] Proposed Fare: PKR $amount. Please confirm if agreed.';
                _sendMessage();
              }
            },
            child: const Text('Send Offer in Chat'),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveJobActionBanner(
      BuildContext context, ServiceRequestModel req, String userRole) {
    final requestProvider =
        Provider.of<ServiceRequestProvider>(context, listen: false);

    double cLat = req.customerLat;
    double cLng = req.customerLng;
    double wLat = req.workerLat ?? (cLat + 0.015);
    double wLng = req.workerLng ?? (cLng + 0.015);

    double dist = LocationService.calculateDistanceKm(wLat, wLng, cLat, cLng);
    String distFormatted = LocationService.formatDistance(dist);
    String etaFormatted = LocationService.calculateETA(dist);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.dividerColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryNavy.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Live GPS Location Card
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryNavy.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: AppColors.primaryNavy,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live Location: $distFormatted away',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    Text(
                      'ETA: ~$etaFormatted • Doorstep: ${req.customerAddress}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accentBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  req.status.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accentBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Dynamic Action Buttons
          if (req.status == AppConstants.statusPending) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.statusRejected,
                      side: const BorderSide(color: AppColors.statusRejected),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 14),
                    label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Cancel', style: TextStyle(fontSize: 11))),
                    onPressed: () async {
                      await requestProvider.updateStatus(
                        requestId: req.id,
                        status: AppConstants.statusCancelled,
                        customerId: req.customerId,
                        workerId: req.workerId,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryNavy,
                      side: const BorderSide(color: AppColors.primaryNavy),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    icon: const Icon(Icons.monetization_on_outlined, size: 14),
                    label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Start Bid', style: TextStyle(fontSize: 11))),
                    onPressed: _showBidDialog,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.availableGreen,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 14),
                    label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Accept Deal', style: TextStyle(fontSize: 11))),
                    onPressed: () async {
                      await requestProvider.updateStatus(
                        requestId: req.id,
                        status: AppConstants.statusAccepted,
                        customerId: req.customerId,
                        workerId: req.workerId,
                      );
                    },
                  ),
                ),
              ],
            ),
          ] else if (req.status == AppConstants.statusAccepted) ...[
            if (userRole == 'worker')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.map_rounded, size: 18),
                  label: const Text(
                      'Start Route to Customer (Open In-App Live Map)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    await requestProvider.updateStatus(
                      requestId: req.id,
                      status: AppConstants.statusOnTheWay,
                      customerId: req.customerId,
                      workerId: req.workerId,
                    );
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MapTrackingScreen(request: req),
                        ),
                      );
                    }
                  },
                ),
              )
            else
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Deal Agreed! Worker starting route to your doorstep...',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryNavy,
                      side: const BorderSide(color: AppColors.primaryNavy),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    icon: const Icon(Icons.map_rounded, size: 14),
                    label: const Text('Open In-App Map', style: TextStyle(fontSize: 11)),
                    onPressed: _openLiveMapTracking,
                  ),
                ],
              ),
          ] else if (req.status == AppConstants.statusOnTheWay) ...[
            if (userRole == 'worker')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryNavy,
                        side: const BorderSide(color: AppColors.primaryNavy),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.map_rounded, size: 16),
                      label: const Text('Open In-App Map',
                          style: TextStyle(fontSize: 11)),
                      onPressed: _openLiveMapTracking,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryNavy,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.location_on_rounded, size: 16),
                      label: const Text('I Have Arrived',
                          style: TextStyle(fontSize: 11)),
                      onPressed: () async {
                        await requestProvider.updateStatus(
                          requestId: req.id,
                          status: AppConstants.statusArrived,
                          customerId: req.customerId,
                          workerId: req.workerId,
                        );
                      },
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Worker is on the way ($distFormatted away • ETA ~$etaFormatted)',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryNavy,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.map_rounded, size: 14),
                    label: const Text('Track Live Map', style: TextStyle(fontSize: 11)),
                    onPressed: _openLiveMapTracking,
                  ),
                ],
              ),
          ] else if (req.status == AppConstants.statusArrived) ...[
            if (userRole == 'customer')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.availableGreen,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.doorbell_rounded, size: 18),
                  label: const Text('Worker Arrived - Acknowledge & Start Service',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    HapticFeedback.heavyImpact();
                    SystemSound.play(SystemSoundType.click);
                    await requestProvider.updateStatus(
                      requestId: req.id,
                      status: AppConstants.statusInProgress,
                      customerId: req.customerId,
                      workerId: req.workerId,
                    );
                  },
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.availableGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Arrived at doorstep! Waiting for customer to acknowledge and click "Start Service".',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.availableGreen,
                  ),
                ),
              ),
          ] else if (req.status == AppConstants.statusInProgress) ...[
            if (userRole == 'worker')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.task_alt_rounded, size: 16),
                  label: const Text('Work Done / Complete Service',
                      style: TextStyle(fontSize: 12)),
                  onPressed: () async {
                    await requestProvider.updateStatus(
                      requestId: req.id,
                      status: 'Work Done Pending Confirmation',
                      customerId: req.customerId,
                      workerId: req.workerId,
                    );
                  },
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryNavy.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Worker is currently working on your job...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryNavy,
                  ),
                ),
              ),
          ] else if (req.status == 'Work Done Pending Confirmation') ...[
            if (userRole == 'customer')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.starGold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.star_rounded, size: 18),
                  label: const Text('Confirm Work Done & Rate Worker',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RatingReviewScreen(request: req),
                      ),
                    );
                  },
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.starGold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Work completed! Waiting for customer cross-verification & review.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  void _showAttachmentModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.pureWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Attach Photo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryNavy,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Take a fresh photo with camera or choose from gallery',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _MediaOptionTile(
                    icon: Icons.camera_alt_rounded,
                    title: 'Take Photo',
                    subtitle: 'Camera',
                    gradientColors: const [
                      AppColors.accentBlue,
                      AppColors.primaryNavy,
                    ],
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _MediaOptionTile(
                    icon: Icons.photo_library_rounded,
                    title: 'Choose Photo',
                    subtitle: 'Gallery',
                    gradientColors: const [
                      AppColors.primaryNavy,
                      AppColors.lightNavy,
                    ],
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
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
            SafeArea(
              child: IconButton(
                padding: const EdgeInsets.all(16),
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _formatTimestamp(DateTime dateTime) {
    final hour = dateTime.hour == 0
        ? 12
        : (dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final requestProvider = Provider.of<ServiceRequestProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        toolbarHeight: 64,
        elevation: 2,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.pureWhite,
              child: Icon(
                widget.peerRole == 'worker'
                    ? Icons.engineering_rounded
                    : Icons.person_rounded,
                color: AppColors.primaryNavy,
                size: 22,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.peerName,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.pureWhite,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.availableGreen,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${widget.peerRole.toUpperCase()} • Online',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.pureWhite.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: const Icon(Icons.phone_in_talk_rounded, size: 20),
            tooltip: 'Audio Call',
            onPressed: _makeInAppVoiceCall,
          ),
          IconButton(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: const Icon(Icons.videocam_rounded, size: 22),
            tooltip: 'Video Call',
            onPressed: _startInAppVideoCall,
          ),
          IconButton(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: const Icon(Icons.map_rounded, size: 20),
            tooltip: 'Live GPS Map',
            onPressed: _openLiveMapTracking,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Secure Communication Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accentBlue.withValues(alpha: 0.08),
                border: const Border(
                  bottom: BorderSide(color: AppColors.dividerColor, width: 0.8),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline_rounded,
                      size: 14, color: AppColors.primaryNavy),
                  SizedBox(width: 6),
                  Text(
                    'Direct chat & media sharing active',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                ],
              ),
            ),

            // Live Interactive Job Action Banner & Bidding Bar
            StreamBuilder<ServiceRequestModel?>(
              stream: requestProvider.getRequestStream(widget.requestId),
              builder: (context, snapshot) {
                final req = snapshot.data;
                if (req == null) return const SizedBox.shrink();
                return _buildLiveJobActionBanner(
                  context,
                  req,
                  auth.userModel?.role ?? (widget.peerRole == 'worker' ? 'customer' : 'worker'),
                );
              },
            ),

            // Message Stream List
            Expanded(
              child: StreamBuilder<List<MessageModel>>(
                stream: chatProvider.getMessages(widget.requestId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final messages = snapshot.data ?? [];
                  if (messages.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: AppColors.primaryNavy.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 52,
                                color: AppColors.primaryNavy,
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Start Conversation',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: AppColors.primaryNavy,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Send a text, capture issue photos via camera, or select photos from gallery.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
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
                            maxWidth:
                                MediaQuery.of(context).size.width * 0.78,
                          ),
                          decoration: BoxDecoration(
                            color: isMe
                                ? AppColors.primaryNavy
                                : AppColors.pureWhite,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(20),
                              topRight: const Radius.circular(20),
                              bottomLeft: Radius.circular(isMe ? 20 : 4),
                              bottomRight: Radius.circular(isMe ? 4 : 20),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
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
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    height: 1.3,
                                  ),
                                ),
                              if (msg.attachmentUrl != null) ...[
                                if (msg.message.isNotEmpty)
                                  const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: () =>
                                      _viewFullImage(msg.attachmentUrl!),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: AppNetworkImage(
                                      imageUrl: msg.attachmentUrl!,
                                      height: 180,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Text(
                                  _formatTimestamp(msg.timestamp),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: isMe
                                        ? AppColors.pureWhite
                                            .withValues(alpha: 0.7)
                                        : AppColors.textLight,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Image Selected Banner Preview
            if (_selectedImage != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.pureWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.accentBlue.withValues(alpha: 0.4)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryNavy.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_selectedImage!,
                          height: 52, width: 52, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Photo Attached',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.primaryNavy,
                            ),
                          ),
                          Text(
                            'Ready to send with message',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel_rounded,
                          color: AppColors.statusRejected, size: 24),
                      onPressed: () => setState(() => _selectedImage = null),
                    )
                  ],
                ),
              ),

            // Bottom Input & Media Toolbar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: const BoxDecoration(
                color: AppColors.pureWhite,
                border: Border(
                  top: BorderSide(color: AppColors.dividerColor, width: 0.8),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0C0F172A),
                    blurRadius: 12,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Camera Quick Button
                  IconButton(
                    padding: const EdgeInsets.all(8),
                    constraints:
                        const BoxConstraints(minWidth: 38, minHeight: 38),
                    icon: const Icon(Icons.camera_alt_rounded,
                        color: AppColors.primaryNavy, size: 22),
                    tooltip: 'Take Photo',
                    onPressed: () => _pickImage(ImageSource.camera),
                  ),

                  // Gallery Attachment Sheet Launcher
                  IconButton(
                    padding: const EdgeInsets.all(8),
                    constraints:
                        const BoxConstraints(minWidth: 38, minHeight: 38),
                    icon: const Icon(Icons.photo_library_rounded,
                        color: AppColors.accentBlue, size: 22),
                    tooltip: 'Attach Media',
                    onPressed: _showAttachmentModal,
                  ),

                  const SizedBox(width: 4),

                  // Text Input
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
                        style: const TextStyle(fontSize: 14),
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Type message...',
                          hintStyle: TextStyle(
                              color: AppColors.textLight, fontSize: 13),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Send Action Button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isSending ? null : _sendMessage,
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: AppColors.primaryNavy,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppColors.primaryNavy.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: _isSending
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: AppColors.pureWhite,
                                size: 18,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _MediaOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.offWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.dividerColor, width: 1.0),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: gradientColors.first.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: AppColors.pureWhite, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryNavy,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
