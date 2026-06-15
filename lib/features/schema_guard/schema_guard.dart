import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/features/schema_guard/migration_gate.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/storage/repo/models/active.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/repo/repo_state.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class SchemaGuard extends ConsumerStatefulWidget {
  const SchemaGuard({required this.builder, super.key});

  final Widget Function(Active active) builder;

  @override
  ConsumerState<SchemaGuard> createState() => _SchemaGuardState();
}

class _SchemaGuardState extends ConsumerState<SchemaGuard> {
  bool _initialized = false;
  bool _migrationComplete = false;

  void _onMigrationComplete() {
    _migrationComplete = true;
    _tryInitialize();
  }

  void _tryInitialize() {
    if (_initialized) return;
    if (!_migrationComplete) return;
    final state = ref.read(repoStateProvider);
    if (state is RepoStateUninitialized) {
      _initialized = true;
      unawaited(ref.read(repoStateProvider.notifier).initialize());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_migrationComplete) {
      _initialized = false;
      return MigrationGate(onMigrationComplete: _onMigrationComplete);
    }

    final RepoState state = ref.watch(repoStateProvider);

    if (state is RepoStateUninitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryInitialize());
      return _buildLoading();
    }

    return switch (state) {
      RepoStateInitializing() => _buildLoading(),
      RepoStateActive(:final active) => _buildActive(context, active),
      RepoStateError(:final error) => _buildError(context, ref, error.message),
      _ => _buildLoading(),
    };
  }

  Widget _buildLoading() => const Scaffold(body: Center(child: CircularProgressIndicator()));

  Widget _buildActive(BuildContext context, Active active) {
    if (active.checkoutId.isEmpty) {
      final router = context.router;
      if (router.current.name != BranchSetupRoute.name) {
        unawaited(router.replace(const BranchSetupRoute()));
      }
      return _buildLoading();
    }
    return widget.builder(active);
  }

  Widget _buildError(BuildContext context, WidgetRef ref, String message) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              "Failed to initialize data repository",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(message, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => ref.read(repoStateProvider.notifier).initialize(),
              child: const Text("Retry"),
            ),
          ],
        ),
      ),
    ),
  );
}
