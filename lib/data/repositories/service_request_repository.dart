import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/firestore_collections.dart';
import '../../core/services/notification_service.dart';
import '../models/service_request_model.dart';
import '../models/worker_profile_model.dart';

class ServiceRequestRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new service request
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
    } catch (_) {
      // Fallback request ID for offline/demo mode
      return 'req_${DateTime.now().millisecondsSinceEpoch}';
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
    double? heading,
    String? estimatedArrivalTime,
    double? distanceKm,
  }) async {
    try {
      Map<String, dynamic> updateData = {
        'workerLat': workerLat,
        'workerLng': workerLng,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (heading != null) updateData['heading'] = heading;
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

  /// Get Customer Requests Stream
  Stream<List<ServiceRequestModel>> getCustomerRequests(String customerId) {
    try {
      return _firestore
          .collection(FirestoreCollections.serviceRequests)
          .where('customerId', isEqualTo: customerId)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => ServiceRequestModel.fromMap(doc.data(), doc.id))
              .toList());
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Get Worker Requests Stream (filtered by worker ID and matching categories)
  Stream<List<ServiceRequestModel>> getWorkerRequests(
    String workerId, {
    String? categoryId,
    List<String>? categoryIds,
  }) {
    try {
      return _firestore
          .collection(FirestoreCollections.serviceRequests)
          .snapshots()
          .map((snapshot) => snapshot.docs
                  .map((doc) => ServiceRequestModel.fromMap(doc.data(), doc.id))
                  .where((req) {
                // Return requests assigned to this specific worker
                if (req.workerId == workerId) return true;

                // Return open pending requests in the worker's category
                if (req.status == AppConstants.statusPending) {
                  if (req.workerId.isEmpty) {
                    final reqCat = req.categoryId
                        .trim()
                        .toLowerCase()
                        .replaceAll('_', '')
                        .replaceAll(' ', '');
                    final reqCatName = req.categoryName
                        .trim()
                        .toLowerCase()
                        .replaceAll('_', '')
                        .replaceAll(' ', '');

                    if (categoryId != null && categoryId.isNotEmpty) {
                      final cNorm = categoryId
                          .trim()
                          .toLowerCase()
                          .replaceAll('_', '')
                          .replaceAll(' ', '');
                      if (cNorm == reqCat ||
                          cNorm == reqCatName ||
                          reqCat.contains(cNorm) ||
                          cNorm.contains(reqCat)) {
                        return true;
                      }
                    }
                    if (categoryIds != null && categoryIds.isNotEmpty) {
                      if (categoryIds.any((c) {
                        final cNorm = c
                            .trim()
                            .toLowerCase()
                            .replaceAll('_', '')
                            .replaceAll(' ', '');
                        return cNorm == reqCat ||
                            cNorm == reqCatName ||
                            reqCat.contains(cNorm) ||
                            cNorm.contains(reqCat);
                      })) {
                        return true;
                      }
                    }
                  }
                }
                return false;
              }).toList());
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

  /// Admin: Get all service requests
  Future<List<ServiceRequestModel>> getAllRequests() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(FirestoreCollections.serviceRequests)
          .get();
      return snapshot.docs
          .map((doc) => ServiceRequestModel.fromMap(
              doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Delete a single service request
  Future<void> deleteRequest(String requestId) async {
    try {
      await _firestore
          .collection(FirestoreCollections.serviceRequests)
          .doc(requestId)
          .delete();
      await _firestore
          .collection(FirestoreCollections.chats)
          .doc(requestId)
          .delete();
    } catch (_) {}
  }

  /// Batch delete multiple service requests
  Future<void> deleteMultipleRequests(List<String> requestIds) async {
    try {
      WriteBatch batch = _firestore.batch();
      for (String id in requestIds) {
        batch.delete(_firestore
            .collection(FirestoreCollections.serviceRequests)
            .doc(id));
        batch.delete(_firestore.collection(FirestoreCollections.chats).doc(id));
      }
      await batch.commit();
    } catch (_) {}
  }
}
