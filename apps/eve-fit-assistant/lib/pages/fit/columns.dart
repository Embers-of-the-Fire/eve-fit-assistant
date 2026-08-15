part of "page.dart";

class FitDisplayColumns extends ConsumerWidget {
  const FitDisplayColumns({required this.fitContext, this.compatibilityNotice, super.key});

  final FitContext fitContext;
  final FitCheckoutCompatibilityNotice? compatibilityNotice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final columns = columnCount(context);
    final fitState = ref.watch(fitProvider(fitContext.fitId));
    final emulatorState = ref.watch(fitEmulatorServiceProvider(fitContext.fitId));
    final status = fitState.status;
    final saveErrorMessageKey = status.maybeWhen(
      error: (messageKey) => messageKey,
      orElse: () => null,
    );

    return Padding(
      padding: const .symmetric(horizontal: 6),
      child: Column(
        children: [
          if (compatibilityNotice != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _FitStatusBanner(
                icon: Icons.inventory_2_outlined,
                title: compatibilityNotice!.title,
                message: compatibilityNotice!.message,
                action: _buildCompatibilityAction(context, ref, compatibilityNotice!),
              ),
            ),
          if (saveErrorMessageKey != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _FitStatusBanner(
                icon: Icons.save_as_outlined,
                title: context.l10n.fitPageSaveErrorTitle,
                message: localizeFitErrorMessage(context.l10n, saveErrorMessageKey),
              ),
            ),
          if (emulatorState.hasError)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _FitStatusBanner(
                icon: Icons.calculate_outlined,
                title: context.l10n.fitPageStatsUnavailableTitle,
                message: localizeFitErrorMessage(
                  context.l10n,
                  emulatorState.errorMessageKey ?? FitErrorMessageKey.fitStatsUnavailable,
                ),
                action: FilledButton.tonalIcon(
                  onPressed: ref.read(fitEmulatorServiceProvider(fitContext.fitId).notifier).retry,
                  icon: const Icon(Icons.refresh),
                  label: Text(context.l10n.fitPageRetryAction),
                ),
              ),
            ),
          Expanded(
            child: Row(
              children: [
                ...range(0, columns)
                    .map<Widget>(
                      (i) => Expanded(
                        child: _FitDisplayTab(fitContext: fitContext, initialIndex: i + 1),
                      ),
                    )
                    .intersperse(const VerticalDivider(indent: 8, endIndent: 8)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildCompatibilityAction(
    BuildContext context,
    WidgetRef ref,
    FitCheckoutCompatibilityNotice notice,
  ) {
    final actionLabel = notice.actionLabel;
    if (actionLabel == null) {
      return null;
    }

    return switch (notice.action) {
      FitCheckoutCompatibilityAction.none => null,
      FitCheckoutCompatibilityAction.openBranchManager => FilledButton.tonalIcon(
        onPressed: () => context.router.pushPath("/setting/data/branches"),
        icon: const Icon(Icons.archive_outlined),
        label: Text(actionLabel),
      ),
    };
  }
}

class _FitStatusBanner extends StatelessWidget {
  const _FitStatusBanner({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        leading: Icon(icon, color: colorScheme.primary),
        title: Text(title),
        subtitle: Text(message),
        trailing: action,
      ),
    );
  }
}

class _FitDisplayTab extends StatefulWidget {
  const _FitDisplayTab({required this.fitContext, this.initialIndex = 1});

  final int initialIndex;

  final FitContext fitContext;

  @override
  State<_FitDisplayTab> createState() => _FitDisplayTabState();
}

class _FitDisplayTabState extends State<_FitDisplayTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final FitInteractionOptions _interactionOptions;
  final _edgeTracker = SlidableEdgeTracker();
  final Map<int, double> _pointerDownX = {};

  static const _tabCount = 5;
  static const _swipeThreshold = 50.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      initialIndex: widget.initialIndex,
      length: _tabCount,
      vsync: this,
    );
    _interactionOptions = const FitInteractionOptions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      TabBar(
        controller: _tabController,
        labelPadding: .zero,
        tabs: [
          Tab(text: context.l10n.fitTabsCharacter),
          Tab(text: context.l10n.fitTabsEquipment),
          Tab(text: context.l10n.fitTabsAttributes),
          Tab(
            text: widget.fitContext.ship.fighterTubes > 0
                ? context.l10n.fitTabsFighter
                : context.l10n.fitTabsDrone,
          ),
          Tab(text: context.l10n.fitTabsUtils),
        ],
      ),
      Expanded(
        child: SlidableEdgeScope(
          tracker: _edgeTracker,
          child: Listener(
            onPointerDown: (event) => _pointerDownX[event.pointer] = event.position.dx,
            onPointerUp: _handlePointerUp,
            onPointerCancel: (event) {
              _pointerDownX.remove(event.pointer);
              _edgeTracker.clear(event.pointer);
            },
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _CharacterTab(
                  fitContext: widget.fitContext,
                  interactionOptions: _interactionOptions,
                ),
                _EquipmentTab(
                  fitContext: widget.fitContext,
                  interactionOptions: _interactionOptions,
                ),
                _AttributeTab(
                  fitContext: widget.fitContext,
                  interactionOptions: _interactionOptions,
                ),
                if (widget.fitContext.ship.fighterTubes > 0)
                  _FighterTab(
                    fitContext: widget.fitContext,
                    interactionOptions: _interactionOptions,
                  )
                else
                  _DroneTab(fitContext: widget.fitContext, interactionOptions: _interactionOptions),
                _UtilsTab(fitContext: widget.fitContext),
              ],
            ),
          ),
        ),
      ),
    ],
  );

  void _handlePointerUp(PointerUpEvent event) {
    final startX = _pointerDownX.remove(event.pointer);
    final onEdge = _edgeTracker.consumeOnEdge(event.pointer);
    if (startX == null || onEdge) return;

    final delta = event.position.dx - startX;
    if (delta.abs() < _swipeThreshold) return;

    final next = delta < 0
        ? (_tabController.index + 1).clamp(0, _tabCount - 1)
        : (_tabController.index - 1).clamp(0, _tabCount - 1);
    if (next != _tabController.index) {
      _tabController.animateTo(next);
    }
  }
}
