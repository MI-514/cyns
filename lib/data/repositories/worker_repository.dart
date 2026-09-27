import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firestore_collections.dart';
import '../../core/services/location_service.dart';
import '../models/worker_profile_model.dart';

class WorkerRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch single worker profile from Firestore (real data only)
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

  /// Save or Update worker profile
  Future<void> updateWorkerProfile(WorkerProfileModel worker) async {
    try {
      await _firestore
          .collection(FirestoreCollections.workers)
          .doc(worker.workerId)
          .set(worker.toMap(), SetOptions(merge: true));
    } catch (_) {}
  }

  /// Update Availability status
  Future<void> toggleAvailability(String workerId, bool isAvailable) async {
    try {
      await _firestore
          .collection(FirestoreCollections.workers)
          .doc(workerId)
          .set({'isAvailable': isAvailable}, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Search available workers within radius by category, strictly sorted by distance (Nearest First)
  Future<List<WorkerProfileModel>> searchWorkers({
    required String categoryId,
    double? customerLat,
    double? customerLng,
    String? searchQuery,
    double maxRadiusKm = 10.0,
  }) async {
    List<WorkerProfileModel> workers = [];

    try {
      QuerySnapshot snapshot = await _firestore
          .collection(FirestoreCollections.workers)
          .where('isAvailable', isEqualTo: true)
          .get();

      if (snapshot.docs.isNotEmpty) {
        workers = snapshot.docs
            .map((doc) => WorkerProfileModel.fromMap(
                doc.data() as Map<String, dynamic>, doc.id))
            .where((w) => w.isApproved)
            .toList();

        if (categoryId.isNotEmpty && categoryId != 'all') {
          workers =
              workers.where((w) => w.categoryIds.contains(categoryId)).toList();
        }
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

    // Strict Radius Filter & Nearest Distance Sorting
    if (customerLat != null && customerLng != null) {
      List<WorkerProfileModel> withinRadius = workers.where((w) {
        if (w.latitude == null || w.longitude == null) return false;
        double dist = LocationService.calculateDistanceKm(
            customerLat, customerLng, w.latitude!, w.longitude!);
        return dist <= maxRadiusKm;
      }).toList();

      // If workers exist within radius, use filtered list
      if (withinRadius.isNotEmpty) {
        workers = withinRadius;
      }

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

  /// Admin: Get all workers
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

  /// Admin: Toggle worker approval
  Future<void> setWorkerApproval(String workerId, bool isApproved) async {
    try {
      await _firestore
          .collection(FirestoreCollections.workers)
          .doc(workerId)
          .set({'isApproved': isApproved}, SetOptions(merge: true));
    } catch (_) {}
  }
}
