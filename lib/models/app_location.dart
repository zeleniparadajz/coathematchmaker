class AppLocation {
  const AppLocation({
    required this.id,
    required this.name,
    this.address = '',
    this.googlePlaceId,
    this.active = true,
  });

  final String id;
  final String name;
  final String address;
  final String? googlePlaceId;
  final bool active;

  String get label => [name, if (address.isNotEmpty) address].join(', ');

  factory AppLocation.fromJson(Map<String, dynamic> json) => AppLocation(
    id: (json['_id'] ?? json['id']).toString(),
    name: json['name'] ?? '',
    address: json['address'] ?? '',
    googlePlaceId: json['googlePlaceId'],
    active: json['active'] != false,
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
