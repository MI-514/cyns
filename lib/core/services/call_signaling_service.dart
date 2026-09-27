import 'package:cloud_firestore/cloud_firestore.dart';

/// Real-time call signaling via Firestore.
/// When a user initiates a call, a signal document is created.
/// The receiving user listens for incoming call signals and can accept/reject.
class CallSignalingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _callSignalsCollection = 'call_signals';

  /// Initiate a call — creates a signal document in Firestore
  static Future<String> initiateCall({
    required String callerId,
    required String callerName,
    required String receiverId,
    required String receiverName,
    required String channelId,
    required bool isVideo,
  }) async {
    DocumentReference ref =
        await _firestore.collection(_callSignalsCollection).add({
      'callerId': callerId,
      'callerName': callerName,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'channelId': channelId,
      'isVideo': isVideo,
      'status': 'ringing', // ringing | accepted | rejected | ended
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Accept an incoming call
  static Future<void> acceptCall(String signalId) async {
    await _firestore.collection(_callSignalsCollection).doc(signalId).update({
      'status': 'accepted',
    });
  }

  /// Reject an incoming call
  static Future<void> rejectCall(String signalId) async {
    await _firestore.collection(_callSignalsCollection).doc(signalId).update({
      'status': 'rejected',
    });
  }

  /// End an active call
  static Future<void> endCall(String signalId) async {
    await _firestore.collection(_callSignalsCollection).doc(signalId).update({
      'status': 'ended',
    });
  }

  /// Listen for incoming calls for a specific user
  static Stream<QuerySnapshot> listenForIncomingCalls(String userId) {
    return _firestore
        .collection(_callSignalsCollection)
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: 'ringing')
        .snapshots();
  }

  /// Listen to a specific call signal (for status updates like accepted/rejected/ended)
  static Stream<DocumentSnapshot> listenToCallSignal(String signalId) {
    return _firestore
        .collection(_callSignalsCollection)
        .doc(signalId)
        .snapshots();
  }

  /// Clean up old/stale call signals (older than 2 minutes)
  static Future<void> cleanupStaleSignals(String userId) async {
    try {
      DateTime cutoff = DateTime.now().subtract(const Duration(minutes: 2));
      QuerySnapshot stale = await _firestore
          .collection(_callSignalsCollection)
          .where('receiverId', isEqualTo: userId)
          .where('status', isEqualTo: 'ringing')
          .get();

      for (var doc in stale.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final createdAt = data['createdAt'];
        if (createdAt is Timestamp && createdAt.toDate().isBefore(cutoff)) {
          await doc.reference.update({'status': 'ended'});
        }
      }
    } catch (_) {}
  }
}
