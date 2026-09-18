import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/firestore_collections.dart';
import '../models/service_request_model.dart';

class ServiceRequestRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new service request
  Future<String> createServiceRequest(ServiceRequestModel request) async {
    try {
      DocumentReference ref = await _firestore
          .collection(FirestoreCollections.serviceRequests)
          .add(request.toMap());

      // Initialize corresponding chat doc
      await _firestore
          .collection(FirestoreCollections.chats)
          .doc(ref.id)
          .set({
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

  /// Update request status
  Future<void> updateRequestStatus({
    required String requestId,
    required String status,
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

      DocumentSnapshot requestDoc = await _firestore
          .collection(FirestoreCollections.serviceRequests)
          .doc(requestId)
          .get();

      if (requestDoc.exists && requestDoc.data() != null) {
        String workerId = requestDoc.get('workerId') ?? '';
        if (workerId.isNotEmpty) {
          if (status == AppConstants.statusAccepted ||
              status == AppConstants.statusOnTheWay ||
              status == AppConstants.statusArrived ||
              status == AppConstants.statusInProgress) {
            // Worker is occupied/on working
            await _firestore
                .collection(FirestoreCollections.workers)
                .doc(workerId)
                .set({'isAvailable': false}, SetOptions(merge: true));
          } else if (status == AppConstants.statusCompleted ||
              status == AppConstants.statusCancelled ||
              status == AppConstants.statusRejected) {
            // Worker is available again
            await _firestore
                .collection(FirestoreCollections.workers)
                .doc(workerId)
                .set({'isAvailable': true}, SetOptions(merge: true));
          }
        }
      }
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
              .map((doc) => ServiceRequestModel.fromMap(
                  doc.data(), doc.id))
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
                    if (categoryId != null && categoryId.isNotEmpty) {
                      if (req.categoryId.trim().toLowerCase() ==
                          categoryId.trim().toLowerCase()) {
                        return true;
                      }
                    }
                    if (categoryIds != null && categoryIds.isNotEmpty) {
                      if (categoryIds.any((c) =>
                          c.trim().toLowerCase() ==
                          req.categoryId.trim().toLowerCase())) {
                        return true;
                      }
                    }
                  }
                }
                return false;
              })
              .toList());
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
              ? ServiceRequestModel.fromMap(
                  doc.data()!, doc.id)
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
}
