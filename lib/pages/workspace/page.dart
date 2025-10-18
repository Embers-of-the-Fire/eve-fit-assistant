import 'package:eve_fit_assistant/config/logger.dart';
import 'package:eve_fit_assistant/storage/bundle/manager.dart';
import 'package:eve_fit_assistant/storage/bundle/service.dart';
import 'package:eve_fit_assistant/storage/bundle/service/localization.dart';
import 'package:eve_fit_assistant/storage/fit/manager.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WorkspacePage extends ConsumerWidget {
  const WorkspacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // return Center(child: Text('Workspace Page'));
    final Widget child;
    if (ref.watch(bundleServiceProvider).isLoaded) {
      final loc = ref.watch(localizationProvider(73330));
      child = loc.when(
        data: (data) => Text("$data"),
        error: (err, stack) => Text("$err\n\n$stack", style: TextStyle(color: Colors.red)),
        loading: () => const Text("Loading..."),
      );
    } else {
      child = Text("Initialize");
    }

    return Center(
      child: Column(
        children: [
          TextButton(
            onPressed: () async {
              if (ref.read(bundleServiceProvider).isLoaded) return;
              final result = await FilePicker.platform.pickFiles();
              if (result != null) {
                final selected = result.xFiles.first;
                info("Selected file: ${selected.name}");
                await ref.read(bundleManagerProvider.notifier).addBundle(selected.path);
                final bundleRegistry = ref.read(bundleRegistryManagerProvider);
                final bundleId = bundleRegistry.bundles.keys.first;
                await ref.read(bundleServiceProvider.notifier).loadBundle(bundleId);
              }
            },
            child: child,
          ),
          TextButton(
            onPressed: () async {
              final fitManager = ref.read(fitManagerProvider.notifier);
              await fitManager.newFit(28659, "Test Fit ${DateTime.now().toIso8601String()}");
            },
            child: Text('Found ${ref.watch(fitRegistryManagerProvider).fits.length} fits'),
          ),
        ],
      ),
    );
  }
}
