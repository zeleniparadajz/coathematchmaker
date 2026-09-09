import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

const tennisEditorialAsset = 'assets/images/tennis_court_editorial.png';

class SportBackdrop extends StatelessWidget {
  const SportBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFCAE8E0), Color(0xFFEDF5E9), Color(0xFFF5F8F6)],
        stops: [0, .42, 1],
      ),
    ),
    child: child,
  );
}

class FrostedSurface extends StatelessWidget {
  const FrostedSurface({super.key, required this.child, this.radius = 28});
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [
        BoxShadow(
          color: Color(0x140D5740),
          blurRadius: 28,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .78),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: .9)),
          ),
          child: child,
        ),
      ),
    ),
  );
}

/// Photo previews fill their frame; the separate viewer keeps the full image.
class SportPhoto extends StatelessWidget {
  const SportPhoto({super.key, this.url, this.alignment = Alignment.center});
  final String? url;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => Image.asset(
      tennisEditorialAsset,
      fit: BoxFit.cover,
      alignment: alignment,
    );
    if (url == null || url!.isEmpty) return fallback();
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      alignment: alignment,
      placeholder: (_, _) => const ColoredBox(color: AppTheme.ice),
      errorWidget: (_, _, _) => fallback(),
    );
  }
}

class PhotoShade extends StatelessWidget {
  const PhotoShade({super.key, this.strong = false});
  final bool strong;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF092D2D).withValues(alpha: .08),
          const Color(0xFF092D2D).withValues(alpha: strong ? .28 : 0),
          const Color(0xFF092D2D).withValues(alpha: .94),
        ],
        stops: const [0, .35, 1],
      ),
    ),
  );
}
