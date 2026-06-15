import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/features/branch_management/server_tile.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/storage/repo/generation_nav.dart";
import "package:eve_fit_assistant/storage/repo/models/branch.dart";
import "package:eve_fit_assistant/storage/repo/models/remote_catalog.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

enum _SetupStep { server, checkout, name }

@RoutePage()
class BranchSetupPage extends ConsumerStatefulWidget {
  const BranchSetupPage({super.key});

  @override
  ConsumerState<BranchSetupPage> createState() => _BranchSetupPageState();
}

class _BranchSetupPageState extends ConsumerState<BranchSetupPage> {
  var _currentStep = _SetupStep.server;
  String? _selectedServerId;
  GenerationCheckoutEntry? _selectedCheckout;
  String? _genId;
  final _nameZhController = TextEditingController();
  final _nameEnController = TextEditingController();
  var _creating = false;

  @override
  void dispose() {
    _nameZhController.dispose();
    _nameEnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Layout(
    title: context.l10n.branchSetupTitle,
    child: Column(
      children: [
        _StepIndicator(currentStep: _currentStep),
        Expanded(child: _buildStepContent()),
      ],
    ),
  );

  Widget _buildStepContent() => switch (_currentStep) {
    _SetupStep.server => _ServerStep(
      selectedServerId: _selectedServerId,
      onServerSelected: (serverId, entry, genId) {
        setState(() {
          _selectedServerId = serverId;
          _genId = genId;
          _currentStep = _SetupStep.checkout;
        });
      },
    ),
    _SetupStep.checkout => _CheckoutStep(
      genId: _genId!,
      serverId: _selectedServerId!,
      selectedCheckout: _selectedCheckout,
      onCheckoutSelected: (checkout) {
        setState(() {
          _selectedCheckout = checkout;
          _currentStep = _SetupStep.name;
        });
      },
      onBack: () {
        setState(() {
          _currentStep = _SetupStep.server;
        });
      },
    ),
    _SetupStep.name => _NameStep(
      nameZhController: _nameZhController,
      nameEnController: _nameEnController,
      creating: _creating,
      onCreate: _createBranch,
      onBack: () {
        setState(() {
          _currentStep = _SetupStep.checkout;
        });
      },
    ),
  };

  Future<void> _createBranch() async {
    final zh = _nameZhController.text.trim();
    final en = _nameEnController.text.trim();
    if (zh.isEmpty && en.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.branchNameRequired)));
      }
      return;
    }

    setState(() => _creating = true);
    try {
      final result = await ref
          .read(repoServiceProvider)
          .createRemoteBranch(
            checkoutId: _selectedCheckout!.id,
            serverId: _selectedServerId!,
            metadata: _selectedCheckout!.metadata,
            branchName: IMap({"zh": zh, "en": en}),
            channel: Channel.defaultChannel,
            source: BranchSource(
              channel: Channel.defaultChannel.value,
              remoteCheckoutId: _selectedCheckout!.id,
            ),
            remoteCreatedAt: _selectedCheckout!.createdAt,
          );
      if (mounted) {
        if (result.isNone()) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.l10n.branchCreateSuccess)));
          unawaited(context.router.maybePop());
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.branchCreateError(message: result.toNullable()!))),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.branchCreateError(message: e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep});

  final _SetupStep currentStep;

  @override
  Widget build(BuildContext context) {
    const steps = _SetupStep.values;
    final currentIndex = steps.indexOf(currentStep);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  color: i <= currentIndex
                      ? context.theme.colorScheme.primary
                      : context.theme.colorScheme.outline,
                ),
              ),
            CircleAvatar(
              radius: 12,
              backgroundColor: i <= currentIndex
                  ? context.theme.colorScheme.primary
                  : context.theme.colorScheme.outline,
              child: i < currentIndex
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : Text(
                      "${i + 1}",
                      style: context.theme.textTheme.labelSmall?.copyWith(
                        color: i <= currentIndex ? Colors.white : null,
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ServerStep extends ConsumerWidget {
  const _ServerStep({required this.selectedServerId, required this.onServerSelected});

  final String? selectedServerId;
  final void Function(String serverId, GenerationServerEntry entry, String genId) onServerSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treeAsync = ref.watch(generationTreeProvider(Channel.defaultChannel));

    return switch (treeAsync) {
      AsyncData(value: final tree) => _buildServerList(context, tree),
      AsyncError(:final error) => Center(child: Text(error.toString())),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }

  Widget _buildServerList(BuildContext context, GenerationTree tree) {
    final sortedServers = tree.servers.toList()..sort((a, b) => a.serverId.compareTo(b.serverId));

    return ListView(
      children: [
        const SizedBox(height: 8),
        for (final server in sortedServers)
          _ServerTile(
            server: server,
            selected: server.serverId == selectedServerId,
            onTap: () => onServerSelected(
              server.serverId,
              GenerationServerEntry(lastUpdatedAt: server.lastUpdatedAt, name: server.name),
              tree.activatedGeneration,
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ServerTile extends StatelessWidget {
  const _ServerTile({required this.server, required this.selected, required this.onTap});

  final ServerSummary server;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final locale = context.locale.languageCode;
    final displayName = server.name[locale] ?? server.name["en"] ?? server.serverId;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          selected ? Icons.check_circle : Icons.circle_outlined,
          color: selected ? theme.colorScheme.primary : theme.colorScheme.outline,
        ),
        title: Text(displayName, style: theme.textTheme.titleMedium),
        subtitle: Text(server.serverId, style: theme.textTheme.bodySmall),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: theme.colorScheme.outline),
      ),
    );
  }
}

class _CheckoutStep extends ConsumerWidget {
  const _CheckoutStep({
    required this.genId,
    required this.serverId,
    required this.selectedCheckout,
    required this.onCheckoutSelected,
    required this.onBack,
  });

  final String genId;
  final String serverId;
  final GenerationCheckoutEntry? selectedCheckout;
  final void Function(GenerationCheckoutEntry) onCheckoutSelected;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(serverDetailProvider(genId, serverId, Channel.defaultChannel));

    return switch (detailAsync) {
      AsyncData(value: final detail) => ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.arrow_back),
            title: Text(context.l10n.branchSetupStepServer),
            onTap: onBack,
          ),
          const SizedBox(height: 8),
          for (final checkout
              in detail.checkouts.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
            CheckoutTile(
              checkout: checkout,
              selected: checkout.id == selectedCheckout?.id,
              onTap: () => onCheckoutSelected(checkout),
            ),
          const SizedBox(height: 8),
        ],
      ),
      AsyncError(:final error) => Center(child: Text(error.toString())),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _NameStep extends StatelessWidget {
  const _NameStep({
    required this.nameZhController,
    required this.nameEnController,
    required this.creating,
    required this.onCreate,
    required this.onBack,
  });

  final TextEditingController nameZhController;
  final TextEditingController nameEnController;
  final bool creating;
  final VoidCallback onCreate;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      ListTile(
        leading: const Icon(Icons.arrow_back),
        title: Text(context.l10n.branchSetupStepCheckout),
        onTap: onBack,
      ),
      const SizedBox(height: 8),
      TextField(
        controller: nameZhController,
        decoration: InputDecoration(
          labelText: context.l10n.branchNameZhLabel,
          border: const OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: nameEnController,
        decoration: InputDecoration(
          labelText: context.l10n.branchNameEnLabel,
          border: const OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 24),
      FilledButton.icon(
        onPressed: creating ? null : onCreate,
        icon: creating
            ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.add),
        label: Text(context.l10n.branchSetupCreate),
      ),
    ],
  );
}
