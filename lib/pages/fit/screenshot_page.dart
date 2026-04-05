part of "page.dart";

class FitScreenshotPage extends ConsumerStatefulWidget {
  const FitScreenshotPage({required this.fitContext, super.key});

  final FitContext fitContext;

  @override
  ConsumerState<FitScreenshotPage> createState() => _FitScreenshotPageState();
}

class _FitScreenshotPageState extends ConsumerState<FitScreenshotPage> {
  static const _panelWidth = 360.0;
  static const _panelHeight = 1200.0;

  final GlobalKey _captureKey = GlobalKey();
  bool _busy = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.fitScreenshotPageTitle)),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _busy ? null : _handleSave,
                icon: const Icon(Icons.download_outlined),
                label: Text(context.l10n.fitScreenshotSave),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _handleShare,
                icon: const Icon(Icons.share_outlined),
                label: Text(context.l10n.fitScreenshotShare),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: RepaintBoundary(
                key: _captureKey,
                child: Container(
                  color: context.theme.scaffoldBackgroundColor,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ScreenshotPanel(
                        title: context.l10n.fitTabsCharacter,
                        child: _CharacterTab(fitContext: widget.fitContext),
                      ),
                      const SizedBox(width: 12),
                      _ScreenshotPanel(
                        title: context.l10n.fitTabsEquipment,
                        child: _EquipmentTab(fitContext: widget.fitContext),
                      ),
                      const SizedBox(width: 12),
                      _ScreenshotPanel(
                        title: context.l10n.fitTabsAttributes,
                        child: _AttributeTab(fitContext: widget.fitContext),
                      ),
                      const SizedBox(width: 12),
                      _ScreenshotPanel(
                        title: widget.fitContext.ship.fighterTubes > 0
                            ? context.l10n.fitTabsFighter
                            : context.l10n.fitTabsDrone,
                        child: widget.fitContext.ship.fighterTubes > 0
                            ? _FighterTab(fitContext: widget.fitContext)
                            : _DroneTab(fitContext: widget.fitContext),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Future<void> _handleSave() async {
    await _runCaptureAction((pngBytes) async {
      final file = await _writePng(
        pngBytes,
        directoryPath: PathProvider.downloadsPath ?? PathProvider.documentsPath,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.fitScreenshotSaved(path: file.path))));
    });
  }

  Future<void> _handleShare() async {
    await _runCaptureAction((pngBytes) async {
      final file = await _writePng(pngBytes, directoryPath: PathProvider.tempPath);
      await Share.shareXFiles([XFile(file.path)], subject: widget.fitContext.fit.metadata.name);
    });
  }

  Future<void> _runCaptureAction(Future<void> Function(Uint8List pngBytes) action) async {
    setState(() => _busy = true);
    try {
      final pngBytes = await _capturePng();
      if (pngBytes == null) return;
      await action(pngBytes);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<Uint8List?> _capturePng() async {
    final boundary = _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final pixelRatio = MediaQuery.devicePixelRatioOf(context).clamp(1.5, 3.0);
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<File> _writePng(Uint8List pngBytes, {required String directoryPath}) async {
    final directory = Directory(directoryPath);
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }

    final safeName = widget.fitContext.fit.metadata.name.replaceAll(
      RegExp("[^A-Za-z0-9._-]+"),
      "_",
    );
    final fileName =
        "${safeName.isEmpty ? "fit" : safeName}_${DateTime.now().millisecondsSinceEpoch}.png";
    final file = File(p.join(directory.path, fileName));
    await file.writeAsBytes(pngBytes, flush: true);
    return file;
  }
}

class _ScreenshotPanel extends StatelessWidget {
  const _ScreenshotPanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: _FitScreenshotPageState._panelWidth,
    height: _FitScreenshotPageState._panelHeight,
    decoration: BoxDecoration(
      color: context.theme.colorScheme.surface,
      border: Border.all(color: context.theme.colorScheme.outlineVariant),
    ),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(title, style: context.theme.textTheme.titleMedium),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: IgnorePointer(
            child: ClipRect(
              child: Padding(padding: const EdgeInsets.only(top: 4), child: child),
            ),
          ),
        ),
      ],
    ),
  );
}
