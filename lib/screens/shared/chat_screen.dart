import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import 'widgets/voice_note_bubble.dart';

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
import '../../providers/worker_provider.dart';
import '../customer/rating_review_screen.dart';
import 'agora_call_screen.dart';
import 'map_tracking_screen.dart';
import '../../core/services/call_signaling_service.dart';
import '../../core/services/notification_service.dart';

class ChatScreen extends StatefulWidget {
  final String requestId;
  final String peerName;
  final String peerRole;
  final String peerId;
  final String? peerPhone;

  const ChatScreen({
    super.key,
    required this.requestId,
    required this.peerName,
    required this.peerRole,
    required this.peerId,
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

  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  int _recordDurationSec = 0;
  Timer? _recordTimer;
  String? _recordedFilePath;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path =
            '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        _recordedFilePath = path;
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );
        HapticFeedback.mediumImpact();
        setState(() {
          _isRecording = true;
          _recordDurationSec = 0;
        });

        _recordTimer?.cancel();
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() => _recordDurationSec++);
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Microphone permission is required to send voice notes.'),
              backgroundColor: AppColors.statusRejected,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not start recording: $e'),
            backgroundColor: AppColors.statusRejected,
          ),
        );
      }
    }
  }

  Future<void> _cancelRecording() async {
    try {
      _recordTimer?.cancel();
      await _audioRecorder.stop();
      HapticFeedback.lightImpact();
      if (_recordedFilePath != null) {
        final f = File(_recordedFilePath!);
        if (await f.exists()) await f.delete();
      }
    } catch (_) {}
    setState(() {
      _isRecording = false;
      _recordDurationSec = 0;
      _recordedFilePath = null;
    });
  }

  Future<void> _stopRecordingAndSend() async {
    try {
      _recordTimer?.cancel();
      final path = await _audioRecorder.stop();
      final duration = _recordDurationSec;
      setState(() {
        _isRecording = false;
        _recordDurationSec = 0;
      });

      if (path != null && duration >= 1) {
        await _sendVoiceNote(path, duration);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Voice note was too short (hold to record).'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isRecording = false);
    }
  }

  Future<void> _sendVoiceNote(String localPath, int durationSec) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    setState(() => _isSending = true);
    try {
      final file = File(localPath);
      final audioUrl = await StorageService.uploadAudio(
        file: file,
        folder: 'voice_notes',
        filename: 'vn_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (audioUrl != null) {
        await chatProvider.sendMessage(
          chatId: widget.requestId,
          senderId: auth.userModel?.uid ?? '',
          senderName: auth.userModel?.fullName ?? 'User',
          senderRole: auth.userModel?.role ?? 'customer',
          message: '',
          audioUrl: audioUrl,
          audioDurationSec: durationSec,
        );

        await NotificationService.sendNotification(
          userId: widget.peerId,
          title: '🎤 Voice Note from ${auth.userModel?.fullName ?? 'User'}',
          body: 'Sent a voice note (${durationSec}s)',
          type: 'chat',
          relatedId: widget.requestId,
        );

        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send voice note.'),
            backgroundColor: AppColors.statusRejected,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _makeInAppVoiceCall() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    String callerId = auth.userModel?.uid ?? '';
    String callerName = auth.userModel?.fullName ?? 'User';

    String signalId = '';
    try {
      signalId = await CallSignalingService.initiateCall(
        callerId: callerId,
        callerName: callerName,
        receiverId: widget.peerId,
        receiverName: widget.peerName,
        channelId: widget.requestId,
        isVideo: false,
      );
      NotificationService.sendNotification(
        userId: widget.peerId,
        title: '📞 Incoming Voice Call from $callerName',
        body: 'Tap to answer call in CYN',
        type: 'call',
        relatedId: widget.requestId,
      );
    } catch (_) {}

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AgoraCallScreen(
          channelId: widget.requestId,
          peerName: widget.peerName,
          peerRole: widget.peerRole,
          isVideoCall: false,
          signalId: signalId,
        ),
      ),
    );
  }

  void _startInAppVideoCall() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    String callerId = auth.userModel?.uid ?? '';
    String callerName = auth.userModel?.fullName ?? 'User';

    String signalId = '';
    try {
      signalId = await CallSignalingService.initiateCall(
        callerId: callerId,
        callerName: callerName,
        receiverId: widget.peerId,
        receiverName: widget.peerName,
        channelId: widget.requestId,
        isVideo: true,
      );
      NotificationService.sendNotification(
        userId: widget.peerId,
        title: '📹 Incoming Video Call from $callerName',
        body: 'Tap to answer call in CYN',
        type: 'call',
        relatedId: widget.requestId,
      );
    } catch (_) {}

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AgoraCallScreen(
          channelId: widget.requestId,
          peerName: widget.peerName,
          peerRole: widget.peerRole,
          isVideoCall: true,
          signalId: signalId,
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Unable to load tracking data. Please try again.'),
        backgroundColor: AppColors.statusRejected,
      ),
    );
  }

  Future<void> _cancelServiceRequest(
      ServiceRequestModel req, String userRole) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Cancel Service Request?'),
        content: Text(
          userRole == 'worker'
              ? 'Are you sure you want to cancel this job? The customer will be informed and your availability will be restored.'
              : 'Are you sure you want to cancel this service request? The service provider will be notified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No, Keep It'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusRejected,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel Request'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      final requestProvider =
          Provider.of<ServiceRequestProvider>(context, listen: false);
      final workerProvider =
          Provider.of<WorkerProvider>(context, listen: false);

      await requestProvider.updateStatus(
        requestId: req.id,
        status: AppConstants.statusCancelled,
        customerId: req.customerId,
        workerId: req.workerId,
      );

      if (userRole == 'worker' || req.workerId.isNotEmpty) {
        workerProvider
            .toggleAvailability(req.workerId, true)
            .catchError((_) {});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service request cancelled.'),
            backgroundColor: AppColors.statusRejected,
          ),
        );
        Navigator.pop(context);
      }
    }
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

    // Background Chat Notification Alert (Uses FCM standard structure)
    await NotificationService.sendNotification(
      userId: widget.peerId,
      title: 'New Message from ${auth.userModel?.fullName ?? 'User'}',
      body: attachmentUrl != null ? '📷 Sent an image' : text,
      type: 'chat',
      relatedId: widget.requestId,
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
                        child:
                            Text('Start Bid', style: TextStyle(fontSize: 11))),
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
                        child: Text('Accept Deal',
                            style: TextStyle(fontSize: 11))),
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
              Column(
                children: [
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
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
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
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.statusRejected,
                        side: const BorderSide(
                            color: AppColors.statusRejected, width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('Cancel Request / Job',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () => _cancelServiceRequest(req, userRole),
                    ),
                  ),
                ],
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
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryNavy,
                      side: const BorderSide(color: AppColors.primaryNavy),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                    ),
                    icon: const Icon(Icons.map_rounded, size: 14),
                    label: const Text('Map', style: TextStyle(fontSize: 11)),
                    onPressed: _openLiveMapTracking,
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.statusRejected,
                      side: const BorderSide(color: AppColors.statusRejected),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 14),
                    label: const Text('Cancel', style: TextStyle(fontSize: 11)),
                    onPressed: () => _cancelServiceRequest(req, userRole),
                  ),
                ],
              ),
          ] else if (req.status == AppConstants.statusOnTheWay) ...[
            if (userRole == 'worker')
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryNavy,
                            side:
                                const BorderSide(color: AppColors.primaryNavy),
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
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.statusRejected,
                        side: const BorderSide(
                            color: AppColors.statusRejected, width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('Cancel Request / Job',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () => _cancelServiceRequest(req, userRole),
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
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryNavy,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                    ),
                    icon: const Icon(Icons.map_rounded, size: 14),
                    label: const Text('Map', style: TextStyle(fontSize: 11)),
                    onPressed: _openLiveMapTracking,
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.statusRejected,
                      side: const BorderSide(color: AppColors.statusRejected),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 14),
                    label: const Text('Cancel', style: TextStyle(fontSize: 11)),
                    onPressed: () => _cancelServiceRequest(req, userRole),
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
                  label: const Text(
                      'Worker Arrived - Acknowledge & Start Service',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                child: Column(
                  children: [
                    const Text(
                      'Worker is currently working on your job...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    if (req.completionOtp != null &&
                        req.completionOtp!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Your 4-Digit Verification Code: ${req.completionOtp}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ] else if (req.status == 'Work Done Pending Confirmation') ...[
            if (userRole == 'customer')
              Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.starGold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.starGold, width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cross-Verification Code:',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryNavy),
                            ),
                            Text(
                              'Share with worker to finalize job',
                              style: TextStyle(
                                  fontSize: 10, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.starGold,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            req.completionOtp ?? '••••',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RatingReviewScreen(request: req),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.starGold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Work completed! Ask customer for their 4-digit cross-verification code.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.statusCompleted,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.verified_user_rounded, size: 18),
                      label: const Text(
                        'Enter 4-Digit Code to Complete Job',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      onPressed: () =>
                          _showEnterCompletionOtpDialog(context, req),
                    ),
                  ),
                ],
              ),
          ] else if (req.status == AppConstants.statusCompleted) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.statusCompleted.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.statusCompleted.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.statusCompleted, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Job Completed Successfully! 🎉',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.statusCompleted,
                          ),
                        ),
                        Text(
                          userRole == 'customer'
                              ? 'Thank you for choosing CYN services.'
                              : 'Payment & job verified. Great job!',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (userRole == 'customer' && !req.hasBeenReviewed)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.starGold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RatingReviewScreen(request: req),
                          ),
                        );
                      },
                      child: const Text('Rate Worker',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                    )
                  else
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.statusCompleted,
                        side:
                            const BorderSide(color: AppColors.statusCompleted),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Exit Chat',
                          style: TextStyle(fontSize: 11)),
                    ),
                ],
              ),
            ),
          ] else if (req.status == AppConstants.statusCancelled) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.statusRejected.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.statusRejected.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cancel,
                      color: AppColors.statusRejected, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'This service request has been cancelled.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.statusRejected,
                      ),
                    ),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.statusRejected,
                      side: const BorderSide(color: AppColors.statusRejected),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => Navigator.pop(context),
                    child:
                        const Text('Exit Chat', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showEnterCompletionOtpDialog(
      BuildContext context, ServiceRequestModel req) async {
    final reqProvider =
        Provider.of<ServiceRequestProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Fetch fresh 4-digit OTP from Firestore to guarantee sync
    final expectedOtp = await reqProvider.ensureCompletionOtp(
      req.id,
      currentOtp: req.completionOtp,
    );

    if (!context.mounted) return;

    final codeController = TextEditingController();
    String enteredOtp = '';

    final bool? verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          icon: const Icon(Icons.verified_user_rounded,
              size: 46, color: AppColors.statusCompleted),
          title: const Text(
            'Enter Verification Code',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ask the customer for the 4-digit Cross-Verification code shown on their screen to complete this job.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                autofocus: true,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 10,
                  color: AppColors.primaryNavy,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '0000',
                  hintStyle: TextStyle(
                    letterSpacing: 10,
                    color: Colors.grey.shade400,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.statusCompleted, width: 2),
                  ),
                ),
                onChanged: (v) => enteredOtp = v.trim(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusCompleted,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                if (enteredOtp.trim() == expectedOtp.trim()) {
                  Navigator.pop(dCtx, true);
                } else {
                  ScaffoldMessenger.of(dCtx).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Incorrect code! Please verify the 4-digit code with customer.',
                      ),
                      backgroundColor: AppColors.statusRejected,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Text(
                'Verify & Done',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );

    if (verified == true) {
      await reqProvider.updateStatus(
        requestId: req.id,
        status: AppConstants.statusCompleted,
        customerId: req.customerId,
        workerId: req.workerId,
      );

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Job verified and successfully completed! 🎉',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.statusCompleted,
          duration: Duration(seconds: 4),
        ),
      );
    }
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
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 28),
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'Options',
            onSelected: (val) async {
              if (val == 'cancel_request') {
                final req = await requestProvider
                    .getRequestStream(widget.requestId)
                    .first;
                if (req != null && mounted) {
                  _cancelServiceRequest(
                      req, auth.userModel?.role ?? widget.peerRole);
                }
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'cancel_request',
                child: Row(
                  children: [
                    Icon(Icons.cancel_outlined,
                        color: AppColors.statusRejected, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Cancel Request',
                      style: TextStyle(
                          color: AppColors.statusRejected,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
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
                  auth.userModel?.role ??
                      (widget.peerRole == 'worker' ? 'customer' : 'worker'),
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
                                color: AppColors.primaryNavy
                                    .withValues(alpha: 0.08),
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
                            maxWidth: MediaQuery.of(context).size.width * 0.78,
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
                              if (msg.audioUrl != null)
                                VoiceNoteBubble(
                                  audioUrl: msg.audioUrl!,
                                  durationSec: msg.audioDurationSec ?? 0,
                                  isMe: isMe,
                                  timestampText:
                                      _formatTimestamp(msg.timestamp),
                                )
                              else ...[
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
              child: _isRecording
                  ? Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: AppColors.statusRejected, size: 26),
                          tooltip: 'Cancel Voice Note',
                          onPressed: _cancelRecording,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(_recordDurationSec ~/ 60).toString().padLeft(1, '0')}:${(_recordDurationSec % 60).toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryNavy,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Recording audio...',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _stopRecordingAndSend,
                            borderRadius: BorderRadius.circular(22),
                            child: Container(
                              padding: const EdgeInsets.all(11),
                              decoration: const BoxDecoration(
                                color: AppColors.availableGreen,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.send_rounded,
                                color: AppColors.pureWhite,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
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
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Send or Mic Action Button
                        if (_messageController.text.trim().isNotEmpty ||
                            _selectedImage != null)
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
                                      color: AppColors.primaryNavy
                                          .withValues(alpha: 0.3),
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
                          )
                        else
                          Material(
                            color: Colors.transparent,
                            child: GestureDetector(
                              onTap: _startRecording,
                              onLongPress: _startRecording,
                              child: Container(
                                padding: const EdgeInsets.all(11),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryNavy,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primaryNavy
                                          .withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.mic_rounded,
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
