class AppLocation {
  const AppLocation({
    required this.id,
    required String name,
    String address = '',
    this.googlePlaceId,
    this.active = true,
    this.googleOnly = false,
    this.googleDetails,
  }) : customName = name,
       customAddress = address;

  final String id;
  final String customName;
  final String customAddress;
  final String? googlePlaceId;
  final bool active;
  final bool googleOnly;
  final GooglePlaceResult? googleDetails;
  String get name =>
      customName.isNotEmpty ? customName : googleDetails?.name ?? 'Google Maps';
  String get address =>
      customAddress.isNotEmpty ? customAddress : googleDetails?.address ?? '';
  bool get showsGoogleDetails =>
      googleOnly &&
      googleDetails != null &&
      (customName.isEmpty || customAddress.isEmpty);

  String get label => [name, if (address.isNotEmpty) address].join(', ');

  factory AppLocation.fromJson(Map<String, dynamic> json) => AppLocation(
    id: (json['_id'] ?? json['id']).toString(),
    name: json['customName'] ?? json['name'] ?? '',
    address: json['address'] ?? '',
    googlePlaceId: json['googlePlaceId'],
    active: json['active'] != false,
    googleOnly: json['googleOnly'] == true,
    googleDetails: json['googleDetails'] is Map<String, dynamic>
        ? GooglePlaceResult.fromJson(json['googleDetails'])
        : null,
  );
}

// Search results live only in the current screen, never in persistent storage.
class GooglePlaceResult {
  const GooglePlaceResult({
    required this.id,
    required this.name,
    required this.address,
    this.attributions = const [],
  });
  final String id;
  final String name;
  final String address;
  final List<Map<String, dynamic>> attributions;

  factory GooglePlaceResult.fromJson(Map<String, dynamic> json) =>
      GooglePlaceResult(
        id: json['id'],
        name: json['displayName']?['text'] ?? '',
        address: json['formattedAddress'] ?? '',
        attributions: (json['attributions'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList(),
      );
}
