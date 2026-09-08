import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firestore_collections.dart';
import '../../core/services/location_service.dart';
import '../models/worker_profile_model.dart';

class WorkerRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch single worker profile strictly from Cloud Firestore
  Future<WorkerProfileModel?> getWorkerProfile(String workerId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection(FirestoreCollections.workers)
          .doc(workerId)
          .get();
      if (doc.exists && doc.data() != null) {
        return WorkerProfileModel.fromMap(
            doc.data() as Map<String, dynamic>, doc.id);
      }
    } catch (_) {}
    return null;
  }

  /// Save or Update worker profile in Cloud Firestore
  Future<void> updateWorkerProfile(WorkerProfileModel worker) async {
    try {
      await _firestore
          .collection(FirestoreCollections.workers)
          .doc(worker.workerId)
          .set(worker.toMap(), SetOptions(merge: true));
    } catch (_) {}
  }

  /// Update Availability status in Cloud Firestore
  Future<void> toggleAvailability(String workerId, bool isAvailable) async {
    try {
      await _firestore
          .collection(FirestoreCollections.workers)
          .doc(workerId)
          .update({'isAvailable': isAvailable});
    } catch (_) {}
  }

  /// Search real available workers strictly from Cloud Firestore, sorted by real GPS distance
  Future<List<WorkerProfileModel>> searchWorkers({
    required String categoryId,
    double? customerLat,
    double? customerLng,
    String? searchQuery,
  }) async {
    List<WorkerProfileModel> workers = [];

    try {
      Query query = _firestore
          .collection(FirestoreCollections.workers)
          .where('isAvailable', isEqualTo: true)
          .where('isApproved', isEqualTo: true);

      if (categoryId.isNotEmpty && categoryId != 'all') {
        query = query.where('categoryIds', arrayContains: categoryId);
      }

      QuerySnapshot snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        workers = snapshot.docs
            .map((doc) => WorkerProfileModel.fromMap(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList();
      }
    } catch (_) {}

    // Filter by text search
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      String q = searchQuery.toLowerCase().trim();
      workers = workers.where((w) {
        return w.name.toLowerCase().contains(q) ||
            w.profession.toLowerCase().contains(q) ||
            w.skills.any((s) => s.toLowerCase().contains(q));
      }).toList();
    }

    // Sort strictly by real GPS distance from nearest to farthest
    if (customerLat != null && customerLng != null) {
      workers.sort((a, b) {
        double distA = (a.latitude != null && a.longitude != null)
            ? LocationService.calculateDistanceKm(
                customerLat, customerLng, a.latitude!, a.longitude!)
            : 9999.0;
        double distB = (b.latitude != null && b.longitude != null)
            ? LocationService.calculateDistanceKm(
                customerLat, customerLng, b.latitude!, b.longitude!)
            : 9999.0;
        return distA.compareTo(distB);
      });
    }

    return workers;
  }

  /// Get all registered workers strictly from Cloud Firestore
  Future<List<WorkerProfileModel>> getAllWorkers() async {
    try {
      QuerySnapshot snapshot =
          await _firestore.collection(FirestoreCollections.workers).get();
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs
            .map((doc) => WorkerProfileModel.fromMap(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Toggle worker approval status in Cloud Firestore
  Future<void> setWorkerApproval(String workerId, bool isApproved) async {
    try {
      await _firestore
          .collection(FirestoreCollections.workers)
          .doc(workerId)
          .update({'isApproved': isApproved});
    } catch (_) {}
  }
}
