import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_location.dart';

class GoogleMapsAttribution extends StatelessWidget {
  const GoogleMapsAttribution({
    super.key,
    this.providers = const [],
    this.onDark = false,
  });
  final List<Map<String, dynamic>> providers;
  final bool onDark;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Google Maps',
        maxLines: 1,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: onDark ? Colors.white : const Color(0xFF5E5E5E),
        ),
      ),
      for (final provider in providers)
        TextButton(
          style: onDark
              ? TextButton.styleFrom(foregroundColor: Colors.white)
              : null,
          onPressed: () async {
            final uri = Uri.tryParse(provider['providerUri']?.toString() ?? '');
            if (uri != null && uri.scheme == 'https') {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          child: Text(provider['provider']?.toString() ?? ''),
        ),
    ],
  );
}

class GoogleVenueAttributions extends StatelessWidget {
  const GoogleVenueAttributions({
    super.key,
    required this.locations,
    this.onDark = false,
  });
  final Iterable<AppLocation> locations;
  final bool onDark;
  @override
  Widget build(BuildContext context) {
    final google = locations
        .where((location) => location.showsGoogleDetails)
        .toList();
    if (google.isEmpty) return const SizedBox.shrink();
    final providers = {
      for (final location in google)
        for (final provider in location.googleDetails!.attributions)
          '${provider['provider']}:${provider['providerUri']}': provider,
    };
    return GoogleMapsAttribution(
      providers: providers.values.toList(),
      onDark: onDark,
    );
  }
}
