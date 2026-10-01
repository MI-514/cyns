import 'package:flutter_test/flutter_test.dart';
import 'package:cyns/core/services/agora_service.dart';
import 'package:cyns/data/models/category_model.dart';
import 'package:cyns/data/models/service_request_model.dart';

void main() {
  group('CYN Unit & Logic Tests', () {
    test('Agora dynamic token generation generates valid 007 token', () {
      final token = AgoraService.getTokenForChannel('cyn_channel_test_123');
      expect(token.isNotEmpty, isTrue);
      expect(token.startsWith('007'), isTrue);
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
