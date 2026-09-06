import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firestore_collections.dart';
import '../../core/services/location_service.dart';
import '../models/worker_profile_model.dart';

class WorkerRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Pre-populated demo workers for immediate out-of-the-box testing
  static final List<WorkerProfileModel> _demoWorkers = [
    WorkerProfileModel(
      workerId: 'worker_001',
      name: 'Ahmed Khan',
      phoneNumber: '+923001234567',
      profession: 'Master Plumber',
      categoryIds: ['plumber'],
      skills: ['Pipe Fitting', 'Water Heater Repair', 'Drainage', 'Leakage Detection'],
      experienceYears: 7,
      serviceDescription: 'Expert plumber with 7+ years of experience in residential and commercial plumbing.',
      workingArea: 'Gulberg & Surrounding Areas',
      isAvailable: true,
      latitude: 31.5204,
      longitude: 74.3587,
      rating: 4.8,
      reviewCount: 24,
      completedJobsCount: 85,
    ),
    WorkerProfileModel(
      workerId: 'worker_002',
      name: 'Muhammad Usman',
      phoneNumber: '+923009876543',
      profession: 'Electrician',
      categoryIds: ['electrician'],
      skills: ['Short Circuit Repair', 'Wiring', 'Switchboard', 'Generator Repair'],
      experienceYears: 5,
      serviceDescription: 'Licensed electrician specializing in home wiring, short circuit repairs, and appliances.',
      workingArea: 'DHA & Model Town',
      isAvailable: true,
      latitude: 31.4700,
      longitude: 74.4100,
      rating: 4.9,
      reviewCount: 38,
      completedJobsCount: 110,
    ),
    WorkerProfileModel(
      workerId: 'worker_003',
      name: 'Rashid Ali',
      phoneNumber: '+923005551234',
      profession: 'Auto Mechanic',
      categoryIds: ['auto_mechanic'],
      skills: ['Engine Tuning', 'Brake Repair', 'Roadside Assistance', 'Oil Change'],
      experienceYears: 8,
      serviceDescription: 'Experienced mechanic providing on-site car and bike repairs and roadside help.',
      workingArea: 'Johar Town & Township',
      isAvailable: true,
      latitude: 31.4690,
      longitude: 74.2720,
      rating: 4.7,
      reviewCount: 19,
      completedJobsCount: 62,
    ),
    WorkerProfileModel(
      workerId: 'worker_004',
      name: 'Tariq Mehmood',
      phoneNumber: '+923007778899',
      profession: 'AC & Refrigerator Technician',
      categoryIds: ['ac_technician', 'refrigerator_technician'],
      skills: ['AC Servicing', 'Gas Refilling', 'Cooling Leak Repair', 'Compressor Service'],
      experienceYears: 6,
      serviceDescription: 'Certified AC and Fridge repair technician with modern tools.',
      workingArea: 'Garden Town & Cavalry',
      isAvailable: true,
      latitude: 31.5000,
      longitude: 74.3300,
      rating: 4.9,
      reviewCount: 42,
      completedJobsCount: 130,
    ),
  ];

  /// Fetch single worker profile
  Future<WorkerProfileModel?> getWorkerProfile(String workerId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection(FirestoreCollections.workers)
          .doc(workerId)
          .get();
      if (doc.exists) {
        return WorkerProfileModel.fromMap(
            doc.data() as Map<String, dynamic>, doc.id);
      }
    } catch (_) {}

    // Fallback to demo workers
    try {
      return _demoWorkers.firstWhere((w) => w.workerId == workerId);
    } catch (_) {
      return _demoWorkers.first;
    }
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
          .update({'isAvailable': isAvailable});
    } catch (_) {}
  }

  /// Search available workers by category, sorting by distance
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

    // If Firestore returns empty or is uninitialized, fallback to demo workers
    if (workers.isEmpty) {
      workers = List.from(_demoWorkers);
      if (categoryId.isNotEmpty && categoryId != 'all') {
        workers = workers
            .where((w) => w.categoryIds.contains(categoryId))
            .toList();
      }
    }

    // Filter by text search
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      String q = searchQuery.toLowerCase().trim();
      workers = workers.where((w) {
        return w.name.toLowerCase().contains(q) ||
            w.profession.toLowerCase().contains(q) ||
            w.skills.any((s) => s.toLowerCase().contains(q));
      }).toList();
    }

    // Sort by distance
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
    return _demoWorkers;
  }

  /// Admin: Toggle worker approval
  Future<void> setWorkerApproval(String workerId, bool isApproved) async {
    try {
      await _firestore
          .collection(FirestoreCollections.workers)
          .doc(workerId)
          .update({'isApproved': isApproved});
    } catch (_) {}
  }
}
