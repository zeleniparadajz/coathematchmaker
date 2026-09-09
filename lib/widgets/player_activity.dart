import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';

String playerActivityLabel(BuildContext context, DateTime? lastActiveAt) {
  if (lastActiveAt == null) {
    return context.tr('Posljednja aktivnost nije zabilježena');
  }
  final date = lastActiveAt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  final value =
      '${two(date.day)}.${two(date.month)}.${date.year}. ${two(date.hour)}:${two(date.minute)}';
  return context.tr('Posljednja aktivnost: {p0}', [value]);
}

class PlayerActivity extends StatelessWidget {
  const PlayerActivity({super.key, required this.lastActiveAt, this.color});
  final DateTime? lastActiveAt;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.history, size: 16, color: color),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          playerActivityLabel(context, lastActiveAt),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ),
    ],
  );
}
