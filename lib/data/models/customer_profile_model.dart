class CustomerProfileModel {
  final String customerId;
  final String name;
  final String phoneNumber;
  final String profilePicUrl;
  final String address;
  final double? latitude;
  final double? longitude;

  CustomerProfileModel({
    required this.customerId,
    required this.name,
    required this.phoneNumber,
    this.profilePicUrl = '',
    this.address = '',
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'name': name,
      'phoneNumber': phoneNumber,
      'profilePicUrl': profilePicUrl,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory CustomerProfileModel.fromMap(Map<String, dynamic> map, String docId) {
    return CustomerProfileModel(
      customerId: docId,
      name: map['name'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      profilePicUrl: map['profilePicUrl'] ?? '',
      address: map['address'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
    );
  }
}
