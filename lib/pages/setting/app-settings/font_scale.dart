part of "page.dart";

const _scaleFactors = [0.8, 0.9, 1.0, 1.2, 1.5];

class FontScaleTile extends ConsumerStatefulWidget {
  const FontScaleTile({super.key});

  @override
  ConsumerState<FontScaleTile> createState() => _FontScaleTileState();
}

class _FontScaleTileState extends ConsumerState<FontScaleTile> {
  late double _sliderPosition;

  @override
  void initState() {
    super.initState();
    _sliderPosition = _positionForScale(ref.read(appSettingServiceProvider).fontScale);
  }

  @override
  Widget build(BuildContext context) {
    final labels = _buildLabels(context);

    return ListTile(
      leading: const Icon(Icons.format_size),
      title: Row(
        children: [
          Expanded(child: Text(context.l10n.appSettingsPageFontScaleTitle)),
          Text(
            labels[_sliderPosition.round()],
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
            value: _sliderPosition,
            max: (_scaleFactors.length - 1).toDouble(),
            divisions: _scaleFactors.length - 1,
            onChanged: (value) {
              setState(() => _sliderPosition = value);
            },
            onChangeEnd: (value) {
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

  double _positionForScale(double scale) {
    final idx = _scaleFactors.indexOf(scale);
    return (idx >= 0 ? idx : 2).toDouble();
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
