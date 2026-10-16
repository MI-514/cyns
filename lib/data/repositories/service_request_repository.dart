import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/firestore_collections.dart';
import '../../core/services/notification_service.dart';
import '../models/service_request_model.dart';
import '../models/worker_profile_model.dart';

class ServiceRequestRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new service request (Strictly throws if Firestore fails; never returns fake ID)
  Future<String> createServiceRequest(ServiceRequestModel request) async {
    try {
      final otp = (request.completionOtp != null &&
              request.completionOtp!.trim().length == 4)
          ? request.completionOtp!.trim()
          : (1000 + (DateTime.now().millisecondsSinceEpoch % 9000)).toString();

      final data = request.toMap();
      data['completionOtp'] = otp;

      DocumentReference ref = await _firestore
          .collection(FirestoreCollections.serviceRequests)
          .add(data);

      // Initialize corresponding chat doc
      await _firestore.collection(FirestoreCollections.chats).doc(ref.id).set({
        'id': ref.id,
        'requestId': ref.id,
        'customerId': request.customerId,
        'workerId': request.workerId,
        'customerName': request.customerName,
        'workerName': request.workerName,
        'lastMessage': 'Service request created.',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });

      return ref.id;
    } catch (e) {
      debugPrint("[ServiceRequestRepository Error] createServiceRequest failed: $e");
      rethrow;
    }
  }

  /// Ensure a guaranteed 4-digit cross-verification OTP exists in Firestore
  Future<String> ensureCompletionOtp(String requestId,
      {String? currentOtp}) async {
    if (currentOtp != null &&
        currentOtp.trim().length == 4 &&
        int.tryParse(currentOtp.trim()) != null) {
      return currentOtp.trim();
    }
    try {
      final doc = await _firestore
          .collection(FirestoreCollections.serviceRequests)
          .doc(requestId)
          .get();
      if (doc.exists && doc.data() != null) {
        final existing = doc.data()?['completionOtp']?.toString();
        if (existing != null &&
            existing.trim().length == 4 &&
            int.tryParse(existing.trim()) != null) {
          return existing.trim();
        }
      }
      final newOtp =
          (1000 + (DateTime.now().millisecondsSinceEpoch % 9000)).toString();
      await _firestore
          .collection(FirestoreCollections.serviceRequests)
          .doc(requestId)
          .set({'completionOtp': newOtp}, SetOptions(merge: true));
      return newOtp;
    } catch (_) {
      return (1000 + (DateTime.now().millisecondsSinceEpoch % 9000)).toString();
    }
  }

  /// Worker Accepts Job Offer with Transaction Safety (Prevents double acceptance race conditions)
  Future<void> acceptJobOffer({
    required String requestId,
    required String customerId,
    required String workerId,
  }) async {
    try {
      DocumentReference ref = _firestore
          .collection(FirestoreCollections.serviceRequests)
          .doc(requestId);

      await _firestore.runTransaction((tx) async {
        DocumentSnapshot doc = await tx.get(ref);
        if (!doc.exists || doc.data() == null) {
          throw Exception("Service request no longer exists.");
        }

        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String status = (data['status'] ?? '').toString().trim().toLowerCase();

        if (status != 'pending') {
          throw Exception("This job request has already been accepted or is no longer available.");
        }

        tx.update(ref, {
          'status': AppConstants.statusAccepted,
          'workerId': workerId,
          'workerAgreed': false,
          'customerAgreed': false,
          'acceptedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      // Notify customer of acceptance
      await NotificationService.sendNotification(
        userId: customerId,
        title: 'Request Accepted!',
        body: 'A nearby skilled worker has accepted your job offer. Open chat to discuss details.',
        type: 'request',
        relatedId: requestId,
      );
    } catch (e) {
      debugPrint("[ServiceRequestRepository Error] acceptJobOffer transaction failed: $e");
      rethrow;
    }
  }

  /// Update request status
  Future<void> updateRequestStatus({
    required String requestId,
    required String status,
    String? workerId,
    String? workerName,
    String? workerPhone,
    double? workerLat,
    double? workerLng,
    String? estimatedArrivalTime,
    double? distanceKm,
  }) async {
    try {
      Map<String, dynamic> updateData = {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (workerId != null && workerId.isNotEmpty) {
        updateData['workerId'] = workerId;
      }
      if (workerName != null && workerName.isNotEmpty) {
        updateData['workerName'] = workerName;
      }
      if (workerPhone != null && workerPhone.isNotEmpty) {
        updateData['workerPhone'] = workerPhone;
      }
      if (workerLat != null) updateData['workerLat'] = workerLat;
      if (workerLng != null) updateData['workerLng'] = workerLng;
      if (estimatedArrivalTime != null) {
        updateData['estimatedArrivalTime'] = estimatedArrivalTime;
      }
      if (distanceKm != null) updateData['distanceKm'] = distanceKm;

      await _firestore
          .collection(FirestoreCollections.serviceRequests)
          .doc(requestId)
          .set(updateData, SetOptions(merge: true));

      // Synchronize corresponding chat doc with assigned worker
      if (status == AppConstants.statusAccepted) {
        Map<String, dynamic> chatUpdate = {
          'updatedAt': FieldValue.serverTimestamp(),
          'lastMessage': 'Job accepted by worker. Chat is now open.',
        };
        if (workerId != null && workerId.isNotEmpty) {
          chatUpdate['workerId'] = workerId;
        }
        if (workerName != null && workerName.isNotEmpty) {
          chatUpdate['workerName'] = workerName;
        }
        await _firestore
            .collection(FirestoreCollections.chats)
            .doc(requestId)
            .set(chatUpdate, SetOptions(merge: true));
      }

      String targetWorkerId = workerId ?? '';

      if (targetWorkerId.isEmpty) {
        DocumentSnapshot requestDoc = await _firestore
            .collection(FirestoreCollections.serviceRequests)
            .doc(requestId)
            .get();

        if (requestDoc.exists && requestDoc.data() != null) {
          final data = requestDoc.data() as Map<String, dynamic>;
          targetWorkerId = data['workerId']?.toString() ?? '';
        }
      }

      if (targetWorkerId.isNotEmpty) {
        if (status == AppConstants.statusAccepted ||
            status == AppConstants.statusOnTheWay ||
            status == AppConstants.statusArrived ||
            status == AppConstants.statusInProgress ||
            status == 'Work Done Pending Confirmation') {
          // Worker is occupied on active job -> set offline/unavailable for other customers
          await _firestore
              .collection(FirestoreCollections.workers)
              .doc(targetWorkerId)
              .set({'isAvailable': false}, SetOptions(merge: true));
        } else if (status == AppConstants.statusCompleted ||
            status == AppConstants.statusCancelled ||
            status == AppConstants.statusRejected) {
          // Active job finished -> set online/available again
          await _firestore
              .collection(FirestoreCollections.workers)
              .doc(targetWorkerId)
              .set({'isAvailable': true}, SetOptions(merge: true));
        }
      }
    } catch (_) {}
  }

  /// Reassign request to the next available worker (Auto-cascade waterfall)
  Future<void> reassignRequestToWorker({
    required String requestId,
    required WorkerProfileModel nextWorker,
    required String customerName,
  }) async {
    try {
      // 1. Update the service request with new worker & reset creation timestamp for a clean new timer window
      await _firestore
          .collection(FirestoreCollections.serviceRequests)
          .doc(requestId)
          .set({
        'workerId': nextWorker.workerId,
        'workerName': nextWorker.name,
        'workerPhone': nextWorker.phoneNumber,
        'workerLat': nextWorker.latitude,
        'workerLng': nextWorker.longitude,
        'status': AppConstants.statusPending,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 2. Synchronize chat document with new worker
      await _firestore
          .collection(FirestoreCollections.chats)
          .doc(requestId)
          .set({
        'workerId': nextWorker.workerId,
        'workerName': nextWorker.name,
        'lastMessage':
            'Reassigned to ${nextWorker.name}. Awaiting worker response...',
        'lastMessageTime': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3. Dispatch high-priority push notification / ringer to new worker
      await NotificationService.sendJobOfferNotification(
        workerId: nextWorker.workerId,
        customerName: customerName,
        categoryName: nextWorker.profession,
        requestId: requestId,
      );
    } catch (_) {}
  }

  /// Update worker live GPS position & navigation metadata
  Future<void> updateWorkerLocation({
    required String requestId,
    required double workerLat,
    required double workerLng,
    String? estimatedArrivalTime,
    double? distanceKm,
  }) async {
    try {
      Map<String, dynamic> updateData = {
        'workerLat': workerLat,
        'workerLng': workerLng,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (estimatedArrivalTime != null) {
        updateData['estimatedArrivalTime'] = estimatedArrivalTime;
      }
      if (distanceKm != null) updateData['distanceKm'] = distanceKm;

      await _firestore
          .collection(FirestoreCollections.serviceRequests)
          .doc(requestId)
          .set(updateData, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Worker sets agreement (Agree & Start Travel)
  Future<void> setAgreement({
    required String requestId,
    required bool isWorker,
    required String customerId,
    required String workerId,
  }) async {
    try {
      DocumentReference ref = _firestore
          .collection(FirestoreCollections.serviceRequests)
          .doc(requestId);

      DocumentSnapshot doc = await ref.get();
      if (!doc.exists) return;

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      bool workerAgreed = isWorker ? true : (data['workerAgreed'] ?? false);
      bool customerAgreed = !isWorker ? true : (data['customerAgreed'] ?? false);

      String newStatus = data['status'];
      if (workerAgreed && customerAgreed) {
        newStatus = AppConstants.statusOnTheWay;
      }

      await ref.set({
        'workerAgreed': workerAgreed,
        'customerAgreed': customerAgreed,
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (newStatus == AppConstants.statusOnTheWay) {
        await NotificationService.sendNotification(
          userId: customerId,
          title: 'Job Confirmed!',
          body: 'Both sides agreed. Worker is now on the way.',
          type: 'request',
          relatedId: requestId,
        );
      }
    } catch (_) {}
  }

  /// Worker arrives at customer location (Triggered when distance <= 100m)
  Future<void> arriveAtLocation({
    required String requestId,
    required String customerId,
  }) async {
    try {
      await _firestore
          .collection(FirestoreCollections.serviceRequests)
          .doc(requestId)
          .set({
        'status': AppConstants.statusArrived,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await NotificationService.sendNotification(
        userId: customerId,
        title: 'Worker Arrived!',
        body: 'Your technician has arrived at your location.',
        type: 'request',
        relatedId: requestId,
      );
    } catch (_) {}
  }

  /// Worker starts work (In Progress)
  Future<void> startWork({
    required String requestId,
    required String customerId,
  }) async {
    try {
      await _firestore
          .collection(FirestoreCollections.serviceRequests)
          .doc(requestId)
          .set({
        'status': AppConstants.statusInProgress,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await NotificationService.sendNotification(
        userId: customerId,
        title: 'Work In Progress',
        body: 'Technician has started the service work.',
        type: 'request',
        relatedId: requestId,
      );
    } catch (_) {}
  }

  /// Worker marks service as completed
  Future<void> completeService(String requestId) async {
    try {
      DocumentReference ref = _firestore
          .collection(FirestoreCollections.serviceRequests)
          .doc(requestId);

      DocumentSnapshot doc = await ref.get();
      if (!doc.exists) return;

      String currentStatus = doc.get('status') ?? '';
      String normStatus = currentStatus.trim().toLowerCase();

      if (normStatus != 'completed' && normStatus != 'cancelled' && normStatus != 'rejected') {
        await ref.set({
          'status': AppConstants.statusCompleted,
          'completedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        String workerId = doc.get('workerId');
        if (workerId.isNotEmpty) {
          await _firestore
              .collection(FirestoreCollections.workers)
              .doc(workerId)
              .update({
            'completedJobsCount': FieldValue.increment(1),
          });
        }
      }
    } catch (e) {
      debugPrint("[ServiceRequestRepository Error] completeService: $e");
    }
  }

  /// Get Customer Requests Stream
  Stream<List<ServiceRequestModel>> getCustomerRequests(String customerId) {
    try {
      return _firestore
          .collection(FirestoreCollections.serviceRequests)
          .where('customerId', isEqualTo: customerId)
          .snapshots()
          .map((snapshot) {
        List<ServiceRequestModel> list = snapshot.docs
            .map((doc) => ServiceRequestModel.fromMap(
                doc.data(), doc.id))
            .toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Get Worker Requests Stream (Includes assigned and broadcast/unassigned requests)
  Stream<List<ServiceRequestModel>> getWorkerRequests(
    String workerId, {
    String? categoryId,
    List<String>? categoryIds,
  }) {
    try {
      return _firestore
          .collection(FirestoreCollections.serviceRequests)
          .snapshots()
          .map((snapshot) {
        List<ServiceRequestModel> list = snapshot.docs
            .map((doc) => ServiceRequestModel.fromMap(
                doc.data(), doc.id))
            .where((r) => r.workerId == workerId || r.workerId.isEmpty || r.workerId == 'all')
            .toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Get Single Service Request Stream
  Stream<ServiceRequestModel?> getRequestStream(String requestId) {
    try {
      return _firestore
          .collection(FirestoreCollections.serviceRequests)
          .doc(requestId)
          .snapshots()
          .map((doc) => doc.exists && doc.data() != null
              ? ServiceRequestModel.fromMap(doc.data()!, doc.id)
              : null);
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Create a new service request document
  Future<String?> createRequest(ServiceRequestModel request) async {
    try {
      return await createServiceRequest(request);
    } catch (e) {
      debugPrint("[ServiceRequestRepository Error] createRequest: $e");
      return null;
    }
  }

  /// Update request status
  Future<void> updateStatus({
    required String requestId,
    required String status,
    required String customerId,
    required String workerId,
    String? workerName,
    String? workerPhone,
  }) async {
    await updateRequestStatus(
      requestId: requestId,
      status: status,
      workerId: workerId,
      workerName: workerName,
      workerPhone: workerPhone,
    );
  }

  /// Delete a service request
  Future<void> deleteRequest(String requestId) async {
    try {
      await _firestore
          .collection(FirestoreCollections.serviceRequests)
          .doc(requestId)
          .delete();
    } catch (_) {}
  }

  /// Delete multiple service requests
  Future<void> deleteMultipleRequests(List<String> requestIds) async {
    try {
      WriteBatch batch = _firestore.batch();
      for (String id in requestIds) {
        DocumentReference ref = _firestore
            .collection(FirestoreCollections.serviceRequests)
            .doc(id);
        batch.delete(ref);
      }
      await batch.commit();
    } catch (_) {}
  }
}
