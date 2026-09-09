import 'package:coathematchmaker/l10n/app_strings.dart';
import 'package:flutter/material.dart';

class LoadError extends StatelessWidget {
  const LoadError({super.key, required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 36),
          const SizedBox(height: 12),
          Text(
            context.tr("Podaci nisu učitani"),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            context.tr("Provjeri internet vezu i pokušaj ponovo."),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(context.tr("Pokušaj ponovo")),
          ),
        ],
      ),
    ),
  );
}
