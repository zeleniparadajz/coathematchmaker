import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/player.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'photo_viewer.dart';

class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.player,
    required this.api,
    this.radius = 24,
    this.allowPreview = false,
  });

  final Player player;
  final ApiClient api;
  final double radius;
  final bool allowPreview;

  @override
  Widget build(BuildContext context) {
    final url = api.imageUrl(player.profileImage);
    final fallback = Text(
      _initials(player),
      style: TextStyle(
        color: AppTheme.ink,
        fontSize: radius * .55,
        fontWeight: FontWeight.w800,
      ),
    );

    if (url.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppTheme.lime,
        child: fallback,
      );
    }

    return GestureDetector(
      onTap: allowPreview ? () => openPhotoViewer(context, [url]) : null,
      child: CachedNetworkImage(
        imageUrl: url,
        imageBuilder: (_, image) =>
            CircleAvatar(radius: radius, backgroundImage: image),
        placeholder: (context, url) => CircleAvatar(
          radius: radius,
          backgroundColor: Colors.white,
          child: SizedBox(
            width: radius * .7,
            height: radius * .7,
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (context, url, error) => CircleAvatar(
          radius: radius,
          backgroundColor: AppTheme.lime,
          child: fallback,
        ),
      ),
    );
  }

  String _initials(Player player) {
    final first = player.firstName.isEmpty ? '' : player.firstName[0];
    final last = player.lastName.isEmpty ? '' : player.lastName[0];
    return '$first$last'.toUpperCase();
  }
}
