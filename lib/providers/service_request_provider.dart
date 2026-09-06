import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/services/notification_service.dart';
import '../data/models/service_request_model.dart';
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

      String requestId = await _repository.createServiceRequest(request);

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
    double? workerLat,
    double? workerLng,
    String? eta,
    double? distanceKm,
  }) async {
    await _repository.updateRequestStatus(
      requestId: requestId,
      status: status,
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
    }

    await NotificationService.sendNotification(
      userId: customerId,
      title: title,
      body: body,
      type: 'request',
      relatedId: requestId,
    );
  }

  Stream<List<ServiceRequestModel>> getCustomerRequests(String customerId) {
    return _repository.getCustomerRequests(customerId);
  }

  Stream<List<ServiceRequestModel>> getWorkerRequests(String workerId) {
    return _repository.getWorkerRequests(workerId);
  }

  Stream<ServiceRequestModel?> getRequestStream(String requestId) {
    return _repository.getRequestStream(requestId);
  }
}
