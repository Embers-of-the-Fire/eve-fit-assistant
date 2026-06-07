part of "page.dart";

const _scaleFactors = [0.8, 0.9, 1.0, 1.2, 1.5];

class FontScaleTile extends ConsumerWidget {
  const FontScaleTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontScale = ref.watch(appSettingServiceProvider).fontScale;
    final labels = _buildLabels(context);
    final position = _positionForScale(fontScale);

    return ListTile(
      leading: const Icon(Icons.format_size),
      title: Row(
        children: [
          Expanded(child: Text(context.l10n.appSettingsPageFontScaleTitle)),
          Text(
            labels[position],
            style: context.theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.theme.colorScheme.primary,
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Slider(
            value: position.toDouble(),
            max: (_scaleFactors.length - 1).toDouble(),
            divisions: _scaleFactors.length - 1,
            onChanged: (value) {
              final idx = value.round();
              ref
                  .read(appSettingServiceProvider.notifier)
                  .update((old) => old.copyWith(fontScale: _scaleFactors[idx]));
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                _scaleFactors.length,
                (i) => Text(labels[i], textScaler: TextScaler.linear(_scaleFactors[i])),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.appSettingsPageFontScaleDescription,
            style: context.theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  int _positionForScale(double scale) {
    final idx = _scaleFactors.indexOf(scale);
    return idx >= 0 ? idx : 2;
  }

  List<String> _buildLabels(BuildContext context) {
    final l10n = context.l10n;
    return [
      l10n.appSettingsPageFontScaleXS,
      l10n.appSettingsPageFontScaleS,
      l10n.appSettingsPageFontScaleM,
      l10n.appSettingsPageFontScaleL,
      l10n.appSettingsPageFontScaleXL,
    ];
  }
}
