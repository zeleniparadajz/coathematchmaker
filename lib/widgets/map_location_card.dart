import 'package:coathematchmaker/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import '../services/maps_service.dart';
import '../theme/app_theme.dart';
import '../models/app_location.dart';
import 'google_maps_attribution.dart';

class MapLocationCard extends StatelessWidget {
  const MapLocationCard({
    super.key,
    required this.location,
    this.googlePlaceId,
    this.compact = false,
    this.venue,
  });
  final String location;
  final String? googlePlaceId;
  final bool compact;
  final AppLocation? venue;

  @override
  Widget build(BuildContext context) {
    if (location.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: Colors.white.withValues(alpha: .85),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            try {
              await MapsService.openLocation(
                location,
                googlePlaceId: googlePlaceId,
              );
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context.tr(
                        "Mapu nije moguće otvoriti. Pokušajte ponovo.",
                      ),
                    ),
                  ),
                );
              }
            }
          },
          child: Padding(
            padding: EdgeInsets.all(compact ? 12 : 16),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: AppTheme.court,
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        location,
                        softWrap: true,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.tr("Otvori u Google Maps"),
                        style: TextStyle(color: AppTheme.court, fontSize: 13),
                      ),
                      if (venue != null)
                        GoogleVenueAttributions(locations: [venue!]),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.north_east, size: 20, color: AppTheme.court),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
