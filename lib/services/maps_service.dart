import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class MapsService {
  static const _channel = MethodChannel('coathematchmaker/maps');

  static Uri googleMapsUri(String location, String placeId) => Uri.https(
    'www.google.com',
    '/maps/search/',
    {'api': '1', 'query': location, 'query_place_id': placeId},
  );

  static Future<void> openLocation(
    String location, {
    String? googlePlaceId,
  }) async {
    final trimmed = location.trim();
    if (trimmed.isEmpty) return;

    if (googlePlaceId != null && googlePlaceId.isNotEmpty) {
      if (!await launchUrl(
        googleMapsUri(trimmed, googlePlaceId),
        mode: LaunchMode.externalApplication,
      )) {
        throw PlatformException(
          code: 'maps_unavailable',
          message: 'Google Maps nije dostupan.',
        );
      }
      return;
    }

    await _channel.invokeMethod<void>('openLocation', {'location': trimmed});
  }
}
