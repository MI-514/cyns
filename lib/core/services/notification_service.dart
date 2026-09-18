import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';

import '../constants/firestore_collections.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handles high-priority FCM background notifications when screen is locked/off
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Initialize FCM Service, Request Permissions & Create High-Priority Notification Channel
  static Future<void> initializeNotificationService(String userId) async {
    try {
      // Request Push Notification permissions
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        criticalAlert: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        
        // Enable Foreground & Lock Screen Heads-Up Banners
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

        // Save FCM Device Token in Firestore
        String? token = await _messaging.getToken();
        if (token != null && userId.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection(FirestoreCollections.users)
              .doc(userId)
              .set({'fcmToken': token}, SetOptions(merge: true));
        }
      }
    } catch (_) {}
  }

  /// Trigger 30-Second Job Offer Notification in Cloud Firestore
  static Future<void> sendJobOfferNotification({
    required String workerId,
    required String customerName,
    required String categoryName,
    required String requestId,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.notifications)
          .add({
        'userId': workerId,
        'title': '🚨 New 30s Job Offer: $categoryName',
        'body': 'Immediate hiring request from $customerName! Tap to accept before 30s expires.',
        'type': 'job_offer',
        'relatedId': requestId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Send an in-app notification document to Firestore
  static Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? relatedId,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.notifications)
          .add({
        'userId': userId,
        'title': title,
        'body': body,
        'type': type,
        'relatedId': relatedId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Trigger audible alert beep sound for incoming job offer
  static void playIncomingJobAlertBeep() {
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }
}
