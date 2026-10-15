import 'package:flutter_test/flutter_test.dart';
import 'package:cyns/core/services/agora_service.dart';
import 'package:cyns/core/services/location_service.dart';
import 'package:cyns/data/models/category_model.dart';
import 'package:cyns/data/models/service_request_model.dart';
import 'package:cyns/data/models/user_model.dart';

void main() {
  group('CYN Comprehensive Unit & Logic Tests', () {
    test('Agora App ID is configured securely without exposing certificate', () {
      expect(AgoraService.appId.isNotEmpty, isTrue);
      expect(AgoraService.appCertificate.isEmpty, isTrue);
    });

    test('CategoryModel serializes and deserializes correctly', () {
      final category = CategoryModel(
        id: 'cat_plumbing',
        name: 'Plumbing',
        description: 'Pipes, leaks and repair',
        icon: 'plumbing',
        isActive: true,
      );

      final map = category.toMap();
      expect(map['name'], 'Plumbing');
      expect(map['isActive'], true);

      final fromMap = CategoryModel.fromMap(map, 'cat_plumbing');
      expect(fromMap.id, 'cat_plumbing');
      expect(fromMap.name, 'Plumbing');
      expect(fromMap.description, 'Pipes, leaks and repair');
    });

    test('UserModel serialization and role assignment', () {
      final user = UserModel(
        uid: 'user_123',
        email: 'test@cyns.app',
        username: 'testuser',
        fullName: 'Test User',
        phoneNumber: '+923001122334',
        role: 'customer',
        isVerified: true,
      );

      final map = user.toMap();
      expect(map['role'], 'customer');
      expect(map['isVerified'], true);

      final restored = UserModel.fromMap(map, 'user_123');
      expect(restored.uid, 'user_123');
      expect(restored.role, 'customer');
      expect(restored.isVerified, true);
    });

    test('LocationService distance, formatting and ETA calculations', () {
      double distKm = LocationService.calculateDistanceKm(31.5204, 74.3587, 31.5304, 74.3687);
      expect(distKm, greaterThan(0.0));

      String fmtMeters = LocationService.formatDistance(0.45);
      expect(fmtMeters.contains('m away'), isTrue);

      String fmtKm = LocationService.formatDistance(3.5);
      expect(fmtKm, '3.5 km away');

      String eta = LocationService.calculateETA(2.5);
      expect(eta.isNotEmpty, isTrue);
    });

    test('ServiceRequestModel roundtrip serialization with OTP', () {
      final req = ServiceRequestModel(
        id: 'req_001',
        customerId: 'cust_01',
        customerName: 'Muhammad',
        customerPhone: '+923001234567',
        workerId: 'wrk_01',
        workerName: 'Ali Worker',
        workerPhone: '+923007654321',
        categoryId: 'cat_electrician',
        categoryName: 'Electrician',
        problemDescription: 'Short circuit in wiring',
        customerLat: 31.5204,
        customerLng: 74.3587,
        customerAddress: 'Gulberg III, Lahore',
        status: 'pending',
        completionOtp: '4589',
      );

      final map = req.toMap();
      expect(map['customerId'], 'cust_01');
      expect(map['workerId'], 'wrk_01');
      expect(map['status'], 'pending');
      expect(map['completionOtp'], '4589');

      final restored = ServiceRequestModel.fromMap(map, 'req_001');
      expect(restored.id, 'req_001');
      expect(restored.customerName, 'Muhammad');
      expect(restored.categoryName, 'Electrician');
      expect(restored.customerLat, 31.5204);
      expect(restored.customerLng, 74.3587);
      expect(restored.completionOtp, '4589');
    });
  });
}
