import 'package:flutter/material.dart';
import '../data/models/worker_profile_model.dart';
import '../data/repositories/worker_repository.dart';

class WorkerProvider extends ChangeNotifier {
  final WorkerRepository _repository = WorkerRepository();

  WorkerProfileModel? _currentWorkerProfile;
  List<WorkerProfileModel> _searchResults = [];
  bool _isLoading = false;
  String _searchQuery = '';

  WorkerProfileModel? get currentWorkerProfile => _currentWorkerProfile;
  List<WorkerProfileModel> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;

  Future<void> fetchWorkerProfile(String workerId) async {
    _isLoading = true;
    notifyListeners();

    _currentWorkerProfile = await _repository.getWorkerProfile(workerId);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateWorkerProfile(WorkerProfileModel profile) async {
    _isLoading = true;
    notifyListeners();

    await _repository.updateWorkerProfile(profile);
    _currentWorkerProfile = profile;

    _isLoading = false;
    notifyListeners();
  }

  Future<void> toggleAvailability(String workerId, bool isAvailable) async {
    await _repository.toggleAvailability(workerId, isAvailable);
    if (_currentWorkerProfile != null) {
      _currentWorkerProfile = WorkerProfileModel(
        workerId: _currentWorkerProfile!.workerId,
        name: _currentWorkerProfile!.name,
        phoneNumber: _currentWorkerProfile!.phoneNumber,
        profilePicUrl: _currentWorkerProfile!.profilePicUrl,
        profession: _currentWorkerProfile!.profession,
        categoryIds: _currentWorkerProfile!.categoryIds,
        skills: _currentWorkerProfile!.skills,
        experienceYears: _currentWorkerProfile!.experienceYears,
        serviceDescription: _currentWorkerProfile!.serviceDescription,
        workingArea: _currentWorkerProfile!.workingArea,
        isAvailable: isAvailable,
        latitude: _currentWorkerProfile!.latitude,
        longitude: _currentWorkerProfile!.longitude,
        rating: _currentWorkerProfile!.rating,
        reviewCount: _currentWorkerProfile!.reviewCount,
        completedJobsCount: _currentWorkerProfile!.completedJobsCount,
        isApproved: _currentWorkerProfile!.isApproved,
      );
      notifyListeners();
    }
  }

  Future<void> searchWorkers({
    required String categoryId,
    double? customerLat,
    double? customerLng,
    String? query,
  }) async {
    _isLoading = true;
    _searchQuery = query ?? '';
    notifyListeners();

    _searchResults = await _repository.searchWorkers(
      categoryId: categoryId,
      customerLat: customerLat,
      customerLng: customerLng,
      searchQuery: query,
    );

    _isLoading = false;
    notifyListeners();
  }
}
