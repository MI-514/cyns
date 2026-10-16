import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../core/constants/firestore_collections.dart';
import '../../core/services/location_service.dart';
import '../models/worker_profile_model.dart';

class WorkerRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch worker profile with self-healing fallback and private subcollection merge
  Future<WorkerProfileModel?> getWorkerProfile(String workerId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection(FirestoreCollections.workers)
          .doc(workerId)
          .get()
          .timeout(const Duration(seconds: 6));
      
      Map<String, dynamic> data = {};
      if (doc.exists && doc.data() != null) {
        data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
      }

      // Merge private identity info if fatherName or cnicNumber is missing at top level
      try {
        DocumentSnapshot identityDoc = await _firestore
            .collection(FirestoreCollections.workers)
            .doc(workerId)
            .collection('private')
            .doc('identity')
            .get();
        if (identityDoc.exists && identityDoc.data() != null) {
          final idData = identityDoc.data() as Map<String, dynamic>;
          if ((data['fatherName'] == null || (data['fatherName'] as String).isEmpty) && idData['fatherName'] != null) {
            data['fatherName'] = idData['fatherName'];
          }
          if ((data['cnicNumber'] == null || (data['cnicNumber'] as String).isEmpty) && idData['cnicNumber'] != null) {
            data['cnicNumber'] = idData['cnicNumber'];
          }
        }
      } catch (_) {}

      if (data.isNotEmpty && (data['name'] != null || data['email'] != null)) {
        return WorkerProfileModel.fromMap(data, workerId);
      } else {
        // Self-healing: Check users collection and create missing worker profile
        DocumentSnapshot userDoc = await _firestore
            .collection(FirestoreCollections.users)
            .doc(workerId)
            .get();
            
        if (userDoc.exists && userDoc.data() != null) {
          final uData = userDoc.data() as Map<String, dynamic>;
          final defaultProfile = {
            'workerId': workerId,
            'email': uData['email'] ?? '',
            'name': uData['fullName'] ?? uData['name'] ?? 'Worker',
            'fatherName': uData['fatherName'] ?? '',
            'phoneNumber': uData['phoneNumber'] ?? '',
            'address': uData['address'] ?? 'Lahore',
            'profession': uData['profession'] ?? 'Skilled Worker',
            'categoryIds': ['general'],
            'skills': ['General Service'],
            'experienceYears': 1,
            'serviceDescription': 'Professional skilled worker.',
            'workingArea': uData['address'] ?? 'Lahore',
            'isAvailable': true,
            'isApproved': true,
            'rating': 5.0,
            'reviewCount': 0,
            'completedJobsCount': 0,
            'createdAt': FieldValue.serverTimestamp(),
          };
          await _firestore
              .collection(FirestoreCollections.workers)
              .doc(workerId)
              .set(defaultProfile, SetOptions(merge: true));
          return WorkerProfileModel.fromMap(defaultProfile, workerId);
        }
      }
    } catch (e) {
      debugPrint("[WorkerRepository Error] getWorkerProfile failed: $e");
    }
    return null;
  }

  /// Real-time stream for single worker profile with auto-healing & subcollection merge
  Stream<WorkerProfileModel?> streamWorkerProfile(String workerId) {
    return _firestore
        .collection(FirestoreCollections.workers)
        .doc(workerId)
        .snapshots()
        .asyncMap((doc) async {
      Map<String, dynamic> data = {};
      if (doc.exists && doc.data() != null) {
        data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
      }

      try {
        DocumentSnapshot identityDoc = await _firestore
            .collection(FirestoreCollections.workers)
            .doc(workerId)
            .collection('private')
            .doc('identity')
            .get();
        if (identityDoc.exists && identityDoc.data() != null) {
          final idData = identityDoc.data() as Map<String, dynamic>;
          if ((data['fatherName'] == null || (data['fatherName'] as String).isEmpty) && idData['fatherName'] != null) {
            data['fatherName'] = idData['fatherName'];
          }
          if ((data['cnicNumber'] == null || (data['cnicNumber'] as String).isEmpty) && idData['cnicNumber'] != null) {
            data['cnicNumber'] = idData['cnicNumber'];
          }
        }
      } catch (_) {}

      if (data.isNotEmpty) {
        return WorkerProfileModel.fromMap(data, workerId);
      }
      return null;
    });
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

  /// Search available workers robustly without fragile query filters or coordinate strictness
  Future<List<WorkerProfileModel>> searchWorkers({
    required String categoryId,
    double? customerLat,
    double? customerLng,
    String? searchQuery,
    double maxRadiusKm = 100.0,
  }) async {
    List<WorkerProfileModel> workers = [];

    try {
      QuerySnapshot snapshot = await _firestore
          .collection(FirestoreCollections.workers)
          .get()
          .timeout(const Duration(seconds: 10));

      if (snapshot.docs.isNotEmpty) {
        workers = snapshot.docs
            .map((doc) => WorkerProfileModel.fromMap(
                doc.data() as Map<String, dynamic>, doc.id))
            .where((w) => w.isApproved && w.isAvailable)
            .toList();

        if (categoryId.isNotEmpty && categoryId != 'all') {
          final target = categoryId.trim().toLowerCase();
          final targetClean = target.replaceAll('_', '').replaceAll(' ', '');

          List<WorkerProfileModel> categoryMatches = workers.where((w) {
            final prof = w.profession.trim().toLowerCase();
            final profClean = prof.replaceAll('_', '').replaceAll(' ', '');

            final matchesProfession = profClean.contains(targetClean) ||
                targetClean.contains(profClean);

            final matchesCategories = w.categoryIds.any((cid) {
              final cidClean = cid
                  .trim()
                  .toLowerCase()
                  .replaceAll('_', '').replaceAll(' ', '');
              return cidClean.contains(targetClean) ||
                  targetClean.contains(cidClean);
            });

            final matchesSkills = w.skills.any((s) {
              final sClean = s
                  .trim()
                  .toLowerCase()
                  .replaceAll('_', '').replaceAll(' ', '');
              return sClean.contains(targetClean) ||
                  targetClean.contains(sClean);
            });

            return matchesProfession || matchesCategories || matchesSkills;
          }).toList();

          if (categoryMatches.isNotEmpty) {
            workers = categoryMatches;
          }
        }
      }
    } catch (e) {
      debugPrint("[WorkerRepository Error] searchWorkers failed: $e");
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      String q = searchQuery.toLowerCase().trim();
      workers = workers.where((w) {
        return w.name.toLowerCase().contains(q) ||
            w.profession.toLowerCase().contains(q) ||
            w.skills.any((s) => s.toLowerCase().contains(q)) ||
            w.workingArea.toLowerCase().contains(q);
      }).toList();
    }

    if (customerLat != null && customerLng != null) {
      workers.sort((a, b) {
        double distA = (a.latitude != null && a.longitude != null)
            ? LocationService.calculateDistanceKm(
                customerLat, customerLng, a.latitude!, a.longitude!)
            : 1.0;
        double distB = (b.latitude != null && b.longitude != null)
            ? LocationService.calculateDistanceKm(
                customerLat, customerLng, b.latitude!, b.longitude!)
            : 1.0;
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
