import 'dart:async';
import 'package:flutter/material.dart';
import '../data/models/worker_profile_model.dart';
import '../data/repositories/worker_repository.dart';

class WorkerProvider extends ChangeNotifier {
  final WorkerRepository _repository = WorkerRepository();

  WorkerProfileModel? _currentWorkerProfile;
  List<WorkerProfileModel> _searchResults = [];
  bool _isLoading = false;
  String _searchQuery = '';
  StreamSubscription<WorkerProfileModel?>? _profileSubscription;

  WorkerProfileModel? get currentWorkerProfile => _currentWorkerProfile;
  List<WorkerProfileModel> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;

  /// Start real-time sync with worker's document in Firestore
  void listenToWorkerProfile(String workerId) {
    if (workerId.isEmpty) return;
    _profileSubscription?.cancel();
    _profileSubscription =
        _repository.streamWorkerProfile(workerId).listen((profile) {
      if (profile != null) {
        _currentWorkerProfile = profile;
        notifyListeners();
      }
    }, onError: (_) {});
  }

  void stopListeningToProfile() {
    _profileSubscription?.cancel();
    _profileSubscription = null;
  }

  Future<void> fetchWorkerProfile(String workerId) async {
    if (workerId.isEmpty) return;
    _isLoading = true;
    notifyListeners();

    try {
      final profile = await _repository.getWorkerProfile(workerId);
      if (profile != null) {
        _currentWorkerProfile = profile;
      }
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateWorkerProfile(WorkerProfileModel profile) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _repository.updateWorkerProfile(profile);
      _currentWorkerProfile = profile;
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  Future<void> toggleAvailability(String workerId, bool isAvailable) async {
    if (_currentWorkerProfile != null) {
      _currentWorkerProfile =
          _currentWorkerProfile!.copyWith(isAvailable: isAvailable);
      notifyListeners();
    }
    try {
      await _repository.toggleAvailability(workerId, isAvailable);
    } catch (_) {}
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    super.dispose();
  }

  Future<void> searchWorkers({
    required String categoryId,
    double? customerLat,
    double? customerLng,
    String? query,
    double maxRadiusKm = 10.0,
  }) async {
    _isLoading = true;
    _searchQuery = query ?? '';
    notifyListeners();

    _searchResults = await _repository.searchWorkers(
      categoryId: categoryId,
      customerLat: customerLat,
      customerLng: customerLng,
      searchQuery: query,
      maxRadiusKm: maxRadiusKm,
    );

    _isLoading = false;
    notifyListeners();
  }
}
