import 'package:flutter/services.dart';

class MapsService {
  static const _channel = MethodChannel('coathematchmaker/maps');

  static Future<void> openLocation(String location) async {
    final trimmed = location.trim();
    if (trimmed.isEmpty) return;

    await _channel.invokeMethod<void>('openLocation', {'location': trimmed});
  }
}
