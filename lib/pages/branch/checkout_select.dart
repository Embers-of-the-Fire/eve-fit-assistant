import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/features/branch_management/server_tile.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/storage/repo/models/remote_catalog.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

enum _CheckoutFilter { all, installed, known }

@RoutePage()
class CheckoutSelectPage extends ConsumerStatefulWidget {
  const CheckoutSelectPage({this.genId, this.serverId, super.key});

  final String? genId;
  final String? serverId;

  @override
  ConsumerState<CheckoutSelectPage> createState() => _CheckoutSelectPageState();
}

class _CheckoutSelectPageState extends ConsumerState<CheckoutSelectPage> {
  var _filter = _CheckoutFilter.all;
  GenerationCheckoutEntry? _selected;

  @override
  Widget build(BuildContext context) {
    final genId = widget.genId;
    final serverId = widget.serverId;

    return Layout(
      title: context.l10n.checkoutSelectTitle,
      floatingActionButton: _selected != null
          ? FloatingActionButton.extended(
              onPressed: () => context.router.maybePop<GenerationCheckoutEntry>(_selected),
              label: const Text("Use this"),
              icon: const Icon(Icons.check),
            )
          : null,
      child: Column(
        children: [
          _FilterChips(
            selected: _filter,
            onChanged: (f) => setState(() {
              _filter = f;
              _selected = null;
            }),
          ),
          if (genId != null && serverId != null)
            Expanded(
              child: _CheckoutList(
                genId: genId,
                serverId: serverId,
                filter: _filter,
                selected: _selected,
                onSelected: (c) => setState(() => _selected = c),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onChanged});

  final _CheckoutFilter selected;
  final ValueChanged<_CheckoutFilter> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Row(
      children: [
        _FilterChip(
          label: context.l10n.checkoutFilterAll,
          value: _CheckoutFilter.all,
          selected: selected,
          onChanged: onChanged,
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: context.l10n.checkoutFilterInstalled,
          value: _CheckoutFilter.installed,
          selected: selected,
          onChanged: onChanged,
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: context.l10n.checkoutFilterKnown,
          value: _CheckoutFilter.known,
          selected: selected,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final _CheckoutFilter value;
  final _CheckoutFilter selected;
  final ValueChanged<_CheckoutFilter> onChanged;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: selected == value,
    onSelected: (_) => onChanged(value),
    visualDensity: VisualDensity.compact,
  );
}

class _CheckoutList extends ConsumerWidget {
  const _CheckoutList({
    required this.genId,
    required this.serverId,
    required this.filter,
    required this.selected,
    required this.onSelected,
  });

  final String genId;
  final String serverId;
  final _CheckoutFilter filter;
  final GenerationCheckoutEntry? selected;
  final void Function(GenerationCheckoutEntry) onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(serverDetailProvider(genId, serverId, Channel.defaultChannel));
    final installedIds = ref.watch(installedCheckoutIdsProvider);
    final knownIds = ref.watch(knownCheckoutIdsProvider);

    return switch (detailAsync) {
      AsyncData(value: final detail) => _buildList(
        context,
        detail.checkouts,
        installedIds,
        knownIds,
      ),
      AsyncError(:final error) => Center(child: Text(error.toString())),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }

  Widget _buildList(
    BuildContext context,
    IList<GenerationCheckoutEntry> checkouts,
    IList<String> installedIds,
    IList<String> knownIds,
  ) {
    final filtered =
        checkouts
            .where(
              (c) => switch (filter) {
                _CheckoutFilter.all => true,
                _CheckoutFilter.installed => installedIds.contains(c.id),
                _CheckoutFilter.known => knownIds.contains(c.id),
              },
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (filtered.isEmpty) {
      return const Center(child: Text("No checkouts match filter"));
    }

    return ListView(
      children: [
        const SizedBox(height: 8),
        for (final checkout in filtered)
          CheckoutTile(
            checkout: checkout,
            installed: installedIds.contains(checkout.id),
            selected: checkout.id == selected?.id,
            onTap: () => onSelected(checkout),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}
