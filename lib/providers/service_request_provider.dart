import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/services/notification_service.dart';
import '../data/models/service_request_model.dart';
import '../data/models/worker_profile_model.dart';
import '../data/repositories/service_request_repository.dart';

class ServiceRequestProvider extends ChangeNotifier {
  final ServiceRequestRepository _repository = ServiceRequestRepository();

  bool _isCreating = false;
  String _errorMessage = '';

  bool get isCreating => _isCreating;
  String get errorMessage => _errorMessage;

  /// Create service request
  Future<String?> createRequest(ServiceRequestModel request) async {
    try {
      _isCreating = true;
      _errorMessage = '';
      notifyListeners();

      String otp =
          (1000 + DateTime.now().millisecondsSinceEpoch % 9000).toString();

      ServiceRequestModel requestWithOtp = ServiceRequestModel(
        id: request.id,
        customerId: request.customerId,
        customerName: request.customerName,
        customerPhone: request.customerPhone,
        workerId: request.workerId,
        workerName: request.workerName,
        workerPhone: request.workerPhone,
        categoryId: request.categoryId,
        categoryName: request.categoryName,
        problemDescription: request.problemDescription,
        attachmentUrl: request.attachmentUrl,
        customerLat: request.customerLat,
        customerLng: request.customerLng,
        customerAddress: request.customerAddress,
        workerLat: request.workerLat,
        workerLng: request.workerLng,
        status: request.status,
        completionOtp: otp,
      );

      String requestId = await _repository.createServiceRequest(requestWithOtp);

      // Send notification to worker
      await NotificationService.sendNotification(
        userId: request.workerId,
        title: 'New Service Request!',
        body: '${request.customerName} needs a ${request.categoryName}.',
        type: 'request',
        relatedId: requestId,
      );

      _isCreating = false;
      notifyListeners();
      return requestId;
    } catch (e) {
      _errorMessage = e.toString();
      _isCreating = false;
      notifyListeners();
      return null;
    }
  }

  /// Update status
  Future<void> updateStatus({
    required String requestId,
    required String status,
    required String customerId,
    required String workerId,
    String? workerName,
    String? workerPhone,
    double? workerLat,
    double? workerLng,
    String? eta,
    double? distanceKm,
  }) async {
    await _repository.updateRequestStatus(
      requestId: requestId,
      status: status,
      workerId: workerId,
      workerName: workerName,
      workerPhone: workerPhone,
      workerLat: workerLat,
      workerLng: workerLng,
      estimatedArrivalTime: eta,
      distanceKm: distanceKm,
    );

    // Notify Customer about status change
    String title = 'Request Status Update';
    String body = 'Your service request status is now: $status';

    if (status == AppConstants.statusAccepted) {
      body = 'Worker accepted your service request!';
    } else if (status == AppConstants.statusOnTheWay) {
      body = 'Worker is on the way to your location.';
    } else if (status == AppConstants.statusArrived) {
      body = 'Worker has arrived at your location.';
    } else if (status == AppConstants.statusCompleted) {
      body = 'Service completed! Please leave a review for the worker.';
    } else if (status == AppConstants.statusRejected) {
      title = 'Worker Unavailable';
      body =
          'The worker was unable to accept your request. Tap to choose another worker.';
    } else if (status == AppConstants.statusMissed) {
      title = 'Request Expired';
      body =
          'The worker did not respond in time. Tap to choose another worker.';
    }

    await NotificationService.sendNotification(
      userId: customerId,
      title: title,
      body: body,
      type: 'request',
      relatedId: requestId,
    );
  }

  /// Reassign request to next available worker in the cascade waterfall
  Future<void> reassignRequestToWorker({
    required String requestId,
    required WorkerProfileModel nextWorker,
    required String customerName,
  }) async {
    await _repository.reassignRequestToWorker(
      requestId: requestId,
      nextWorker: nextWorker,
      customerName: customerName,
    );
    notifyListeners();
  }

  Stream<List<ServiceRequestModel>> getCustomerRequests(String customerId) {
    return _repository.getCustomerRequests(customerId);
  }

  Stream<List<ServiceRequestModel>> getWorkerRequests(
    String workerId, {
    String? categoryId,
    List<String>? categoryIds,
  }) {
    return _repository.getWorkerRequests(
      workerId,
      categoryId: categoryId,
      categoryIds: categoryIds,
    );
  }

  Stream<ServiceRequestModel?> getRequestStream(String requestId) {
    return _repository.getRequestStream(requestId);
  }

  /// Delete a single service request
  Future<void> deleteRequest(String requestId) async {
    await _repository.deleteRequest(requestId);
    notifyListeners();
  }

  /// Batch delete multiple service requests
  Future<void> deleteMultipleRequests(List<String> requestIds) async {
    await _repository.deleteMultipleRequests(requestIds);
    notifyListeners();
  }

  /// Ensure a 4-digit cross-verification OTP exists for a request
  Future<String> ensureCompletionOtp(String requestId,
      {String? currentOtp}) async {
    return await _repository.ensureCompletionOtp(requestId,
        currentOtp: currentOtp);
  }
}
