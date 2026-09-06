import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firestore_collections.dart';
import '../data/models/report_model.dart';
import '../data/models/user_model.dart';
import '../data/models/worker_profile_model.dart';
import '../data/models/service_request_model.dart';

class AdminProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _totalCustomers = 0;
  int _totalWorkers = 0;
  int _totalRequests = 0;
  int _pendingWorkerApprovals = 0;
  bool _isLoading = false;

  List<UserModel> _allUsers = [];
  List<WorkerProfileModel> _allWorkers = [];
  List<ServiceRequestModel> _allRequests = [];
  List<ReportModel> _allReports = [];

  int get totalCustomers => _totalCustomers;
  int get totalWorkers => _totalWorkers;
  int get totalRequests => _totalRequests;
  int get pendingWorkerApprovals => _pendingWorkerApprovals;
  bool get isLoading => _isLoading;

  List<UserModel> get allUsers => _allUsers;
  List<WorkerProfileModel> get allWorkers => _allWorkers;
  List<ServiceRequestModel> get allRequests => _allRequests;
  List<ReportModel> get allReports => _allReports;

  Future<void> fetchDashboardStats() async {
    _isLoading = true;
    notifyListeners();

    try {
      QuerySnapshot usersSnap =
          await _firestore.collection(FirestoreCollections.users).get();
      QuerySnapshot workersSnap =
          await _firestore.collection(FirestoreCollections.workers).get();
      QuerySnapshot reqSnap = await _firestore
          .collection(FirestoreCollections.serviceRequests)
          .get();

      _allUsers = usersSnap.docs
          .map((doc) =>
              UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      _allWorkers = workersSnap.docs
          .map((doc) => WorkerProfileModel.fromMap(
              doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      _allRequests = reqSnap.docs
          .map((doc) => ServiceRequestModel.fromMap(
              doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      _totalCustomers =
          _allUsers.where((u) => u.role == 'customer').length;
      _totalWorkers = _allWorkers.length;
      _totalRequests = _allRequests.length;
      _pendingWorkerApprovals =
          _allWorkers.where((w) => !w.isApproved).length;
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchReports() async {
    QuerySnapshot snap =
        await _firestore.collection(FirestoreCollections.reports).get();
    _allReports = snap.docs
        .map((doc) =>
            ReportModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
    notifyListeners();
  }

  Future<void> toggleWorkerApproval(String workerId, bool currentStatus) async {
    await _firestore
        .collection(FirestoreCollections.workers)
        .doc(workerId)
        .update({'isApproved': !currentStatus});
    await fetchDashboardStats();
  }

  Future<void> resolveReport(String reportId) async {
    await _firestore
        .collection(FirestoreCollections.reports)
        .doc(reportId)
        .update({'status': 'Resolved'});
    await fetchReports();
  }
}
