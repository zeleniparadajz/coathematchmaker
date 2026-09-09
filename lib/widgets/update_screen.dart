import 'package:coathematchmaker/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_config_service.dart';

Future<void> openAppStore(BuildContext context, AppConfig config) async {
  var opened = false;
  try {
    final uri = config.storeUri;
    if (uri != null) {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (_) {
    /* Show the same recovery action for unavailable store apps. */
  }
  if (!opened && context.mounted) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr("Otvori {p0}", [config.storeName])),
        content: Text(
          context.tr(
            "Potraži COA The Matchmaker i ažuriraj aplikaciju. Ako ažuriranje još nije prikazano, pokušaj ponovo kasnije.",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr("U redu")),
          ),
        ],
      ),
    );
  }
}

class ForceUpdateScreen extends StatefulWidget {
  const ForceUpdateScreen({
    super.key,
    required this.config,
    required this.onRetry,
  });
  final AppConfig config;
  final Future<void> Function() onRetry;
  @override
  State<ForceUpdateScreen> createState() => _ForceUpdateScreenState();
}

class _ForceUpdateScreenState extends State<ForceUpdateScreen> {
  bool _checking = false;
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/images/coa.png', width: 96, height: 96),
                  const SizedBox(height: 24),
                  Text(
                    context.tr("Vrijeme je za novu verziju"),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppStrings.of(context).isEnglish
                        ? widget.config.messageEn ??
                              context.tr(
                                'Nova verzija aplikacije je obavezna. Ažuriraj COA The Matchmaker.',
                              )
                        : widget.config.message,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => openAppStore(context, widget.config),
                    icon: const Icon(Icons.system_update),
                    label: Text(context.tr("Ažuriraj aplikaciju")),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _checking
                        ? null
                        : () async {
                            setState(() => _checking = true);
                            await widget.onRetry();
                            if (mounted) setState(() => _checking = false);
                          },
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      _checking
                          ? context.tr("Provjeravam…")
                          : context.tr("Provjeri ponovo"),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${widget.config.installedVersion} (${widget.config.installedBuild})',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class VersionSheet extends StatelessWidget {
  const VersionSheet({super.key, required this.config, this.onCheck});
  final AppConfig? config;
  final Future<void> Function()? onCheck;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr("Verzija aplikacije"),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(
            config == null
                ? context.tr("Provjera trenutno nije dostupna.")
                : '${config!.installedVersion} (${config!.installedBuild}) · ${config!.storeName}',
          ),
          const SizedBox(height: 8),
          if (config != null)
            Text(
              config!.updateAvailable
                  ? context.tr("Dostupna je nova verzija.")
                  : context.tr("Koristiš najnoviju verziju."),
            ),
          const SizedBox(height: 16),
          if (config?.updateAvailable == true)
            FilledButton.icon(
              onPressed: () => openAppStore(context, config!),
              icon: const Icon(Icons.system_update),
              label: Text(context.tr("Ažuriraj aplikaciju")),
            ),
          TextButton.icon(
            onPressed: onCheck == null
                ? null
                : () async {
                    await onCheck!();
                    if (context.mounted) Navigator.pop(context);
                  },
            icon: const Icon(Icons.refresh),
            label: Text(context.tr("Provjeri ponovo")),
          ),
        ],
      ),
    ),
  );
}
