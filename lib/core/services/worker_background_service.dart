import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../constants/firestore_collections.dart';
import 'audio_alert_service.dart';

class WorkerBackgroundService with WidgetsBindingObserver {
  static final WorkerBackgroundService instance = WorkerBackgroundService._();
  WorkerBackgroundService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<QuerySnapshot>? _requestsSubscription;
  StreamSubscription<DocumentSnapshot>? _workerDocSubscription;

  String? _workerId;
  bool _isOnline = false;
  bool _isForeground = true;
  bool _isInitialized = false;

  final Set<String> _knownRequestIds = {};
  VoidCallback? onNewJobInForeground;

  bool get isOnline => _isOnline;
  bool get isForeground => _isForeground;
  String? get monitoredWorkerId => _workerId;

  /// Initialize notification channels, audio, and lifecycle observer
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    WidgetsBinding.instance.addObserver(this);
    await AudioAlertService.initialize();

    // Setup Local Notifications for Android, iOS, Windows
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    // FIX: Await local notifications permission request directly for Android 13+
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Stop loud alarm immediately upon tapping notification
        AudioAlertService.stopAlarmAlert();
      },
    );

    // Create high-importance Alarm Channel & Background Presence Channel
    await _createNotificationChannels();
  }

  Future<void> _createNotificationChannels() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      // 1. High-Priority Alarm Channel (for screen-off / background lock screen)
      final AndroidNotificationChannel alarmChannel =
          AndroidNotificationChannel(
        'cyn_job_alarm_channel_v2',
        'Urgent Job Request Alarm',
        description:
            'Loud continuous alarm and vibration when screen is off or app is closed',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList(
            [0, 1000, 500, 1000, 500, 1000, 500, 1000, 500, 1000]),
      );

      // 2. Ongoing Online Presence Channel
      const AndroidNotificationChannel presenceChannel =
          AndroidNotificationChannel(
        'cyn_worker_presence_channel',
        'Worker Online Background Status',
        description: 'Keeps background service alive while worker is online',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
      );

      // 3. Foreground message chime channel
      const AndroidNotificationChannel chimeChannel =
          AndroidNotificationChannel(
        'cyn_job_chime_channel',
        'In-App Job Notifications',
        description: 'Gentle message chime when actively using app',
        importance: Importance.high,
        playSound: true,
        enableVibration: false,
      );

      await androidPlugin.createNotificationChannel(alarmChannel);
      await androidPlugin.createNotificationChannel(presenceChannel);
      await androidPlugin.createNotificationChannel(chimeChannel);
    }
  }

  /// Start background service for a worker
  /// Continuously watches their isAvailable status in Firestore
  void startMonitoring(String workerId) {
    if (workerId.isEmpty) return;
    _workerId = workerId;

    _workerDocSubscription?.cancel();
    _workerDocSubscription = FirebaseFirestore.instance
        .collection(FirestoreCollections.workers)
        .doc(workerId)
        .snapshots()
        .listen((doc) {
      if (!doc.exists || doc.data() == null) return;
      final data = doc.data() as Map<String, dynamic>;
      final bool isAvailable =
          data['isAvailable'] == true || data['isAvailable'] == 'true';

      if (isAvailable && !_isOnline) {
        _enableOnlineBackgroundMode(workerId);
      } else if (!isAvailable && _isOnline) {
        _disableOnlineBackgroundMode();
      }
    });
  }

  /// Stop all monitoring and clear background state
  void stopMonitoring() {
    _disableOnlineBackgroundMode();
    _workerDocSubscription?.cancel();
    _workerDocSubscription = null;
    _workerId = null;
  }

  /// Check if the incoming request is new and alert if needed
  void processIncomingBackgroundRequest(Map<String, dynamic> data, String requestId) {
    if (_isOnline) {
      if (!_knownRequestIds.contains(requestId)) {
        _knownRequestIds.add(requestId);
        _handleIncomingRequestAlert(data, requestId);
      }
    }
  }

  /// Worker went ONLINE: Start background request listener & show presence notification
  void _enableOnlineBackgroundMode(String workerId) {
    _isOnline = true;

    // Show ongoing status notification so system knows worker is actively waiting
    _showOnlinePresenceNotification();

    // Listen to incoming Pending requests for this worker in real-time
    _requestsSubscription?.cancel();
    _requestsSubscription = FirebaseFirestore.instance
        .collection(FirestoreCollections.serviceRequests)
        .where('workerId', isEqualTo: workerId)
        .where('status', isEqualTo: AppConstants.statusPending)
        .snapshots()
        .listen((snapshot) {
      final now = DateTime.now();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final createdAt = data['createdAt'];
        DateTime? dt;
        if (createdAt is Timestamp) dt = createdAt.toDate();
        if (dt != null &&
            now.difference(dt).inSeconds > AppConstants.requestTimeoutSeconds) {
          // Stale request older than timeout - mark missed and don't alert
          FirebaseFirestore.instance
              .collection(FirestoreCollections.serviceRequests)
              .doc(doc.id)
              .update({'status': AppConstants.statusMissed});
          continue;
        }
        if (!_knownRequestIds.contains(doc.id)) {
          _knownRequestIds.add(doc.id);
          _handleIncomingRequestAlert(doc.data(), doc.id);
        }
      }
    });
  }

  /// Worker went OFFLINE: Stop background listener & cancel alarm
  void _disableOnlineBackgroundMode() {
    _isOnline = false;
    _requestsSubscription?.cancel();
    _requestsSubscription = null;
    _knownRequestIds.clear();

    // Silence any ringing alarm
    AudioAlertService.stopAlarmAlert();

    // Cancel sticky presence notification safely
    try {
      _localNotifications.cancel(id: 1001);
    } catch (_) {}
  }

  /// Handles incoming request based on lifecycle state (Screen Off vs Inside App)
  void _handleIncomingRequestAlert(
      Map<String, dynamic> data, String requestId) async {
    final String customerName = data['customerName'] ?? 'Customer';
    final String categoryName = data['categoryName'] ?? 'Service Request';

    if (_isForeground) {
      // 📱 IN FOREGROUND (Worker is looking at screen):
      // Play simple notification message beep (no continuous loud alarm)
      await AudioAlertService.playMessageBeep();

      // Trigger callback if registered
      onNewJobInForeground?.call();
    } else {
      // 🚨 IN BACKGROUND / SCREEN OFF:
      // Play loud repeating alarm buzzer + continuous pulse vibration
      await AudioAlertService.playAlarmAlert();

      // Fire High-Priority Heads-Up / Lock-Screen Notification safely
      await _showBackgroundAlarmNotification(
        requestId: requestId,
        customerName: customerName,
        categoryName: categoryName,
      );
    }
  }

  /// Shows high-priority lock-screen notification when screen is off
  Future<void> _showBackgroundAlarmNotification({
    required String requestId,
    required String customerName,
    required String categoryName,
  }) async {
    try {
      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'cyn_job_alarm_channel_v2',
        'Urgent Job Request Alarm',
        channelDescription:
            'Loud continuous alarm and vibration when screen is off or app is closed',
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: false, // Prevents Android 14 SecurityException
        category: AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList(
            [0, 1000, 500, 1000, 500, 1000, 500, 1000, 500, 1000]),
        color: AppColors.statusPending,
        visibility: NotificationVisibility.public,
        ongoing: true, // Keep notification until worker acts
        actions: const [
          AndroidNotificationAction(
            'open_app',
            'Open & Accept Job',
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            'dismiss_alarm',
            'Stop Alarm',
            showsUserInterface: false,
          ),
        ],
      );

      final NotificationDetails notificationDetails =
          NotificationDetails(android: androidDetails);

      await _localNotifications.show(
        id: requestId.hashCode,
        title: '🚨 NEW 30s JOB OFFER: $categoryName',
        body:
            'Immediate hire request from $customerName! Tap to view & accept before it rotates.',
        notificationDetails: notificationDetails,
      );
    } catch (_) {}
  }

  /// Shows persistent notification indicating worker is online and listening
  Future<void> _showOnlinePresenceNotification() async {
    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'cyn_worker_presence_channel',
        'Worker Online Background Status',
        channelDescription:
            'Keeps background service alive while worker is online',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        color: AppColors.availableGreen,
        showWhen: false,
      );

      const NotificationDetails notificationDetails =
          NotificationDetails(android: androidDetails);

      await _localNotifications.show(
        id: 1001,
        title: '🟢 CYN Worker Online',
        body: 'Ready to receive nearby customer requests in background.',
        notificationDetails: notificationDetails,
      );
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = (state == AppLifecycleState.resumed);

    // If worker returns to app, stop loud alarm sound automatically
    if (_isForeground) {
      AudioAlertService.stopAlarmAlert();
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stopMonitoring();
  }
}
