import 'package:flutter/material.dart';

import '../services/maps_service.dart';
import '../theme/app_theme.dart';

class MapLocationCard extends StatelessWidget {
  const MapLocationCard({
    super.key,
    required this.location,
    this.compact = false,
  });

  final String location;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final trimmed = location.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => MapsService.openLocation(trimmed),
        child: SizedBox(
          height: compact ? 108 : 128,
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CustomPaint(painter: _MapPreviewPainter()),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: .94),
                        Colors.white.withValues(alpha: .72),
                        AppTheme.court.withValues(alpha: .14),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.court,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.court.withValues(alpha: .24),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.location_on, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lokacija',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: AppTheme.ink.withValues(alpha: .58),
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            trimmed,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.map_outlined,
                                size: 16,
                                color: AppTheme.court,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Otvori u Google Maps',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: AppTheme.court,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.north_east,
                      color: AppTheme.ink.withValues(alpha: .42),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapPreviewPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = const Color(0xffeef7ea);
    canvas.drawRect(Offset.zero & size, background);

    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: .82)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 12;
    final thinRoadPaint = Paint()
      ..color = AppTheme.court.withValues(alpha: .14)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4;

    final path1 = Path()
      ..moveTo(-20, size.height * .72)
      ..cubicTo(
        size.width * .22,
        size.height * .48,
        size.width * .48,
        size.height * .88,
        size.width + 24,
        size.height * .56,
      );
    final path2 = Path()
      ..moveTo(size.width * .08, -10)
      ..cubicTo(
        size.width * .22,
        size.height * .34,
        size.width * .72,
        size.height * .20,
        size.width * .92,
        size.height + 18,
      );
    canvas.drawPath(path1, roadPaint);
    canvas.drawPath(path2, roadPaint);
    canvas.drawPath(path1, thinRoadPaint);
    canvas.drawPath(path2, thinRoadPaint);

    final parkPaint = Paint()..color = AppTheme.lime.withValues(alpha: .22);
    canvas.drawCircle(
      Offset(size.width * .78, size.height * .22),
      42,
      parkPaint,
    );
    canvas.drawCircle(
      Offset(size.width * .58, size.height * .92),
      34,
      parkPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
