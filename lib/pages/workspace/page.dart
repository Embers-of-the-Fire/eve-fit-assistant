import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/storage/bundle/manager.dart";
import "package:eve_fit_assistant/storage/bundle/service.dart";
import "package:eve_fit_assistant/storage/bundle/service/localization.dart";
import "package:eve_fit_assistant/storage/fit/manager.dart";
import "package:eve_fit_assistant/storage/fit/service.dart";
import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

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
        error: (err, stack) => Text("$err\n\n$stack", style: const TextStyle(color: Colors.red)),
        loading: () => const Text("Loading..."),
      );
    } else {
      child = const Text("Initialize");
    }

    return Center(
      child: Column(
        children: [
          TextButton(
            onPressed: () async {
              if (ref.read(bundleServiceProvider).isLoaded) {
                info("Loaded!");
              }
              final result = await FilePicker.platform.pickFiles();
              if (result != null) {
                final selected = result.xFiles.first;
                info("Selected file: ${selected.name}");
                await ref
                    .read(bundleManagerProvider.notifier)
                    .addBundle(
                      selected.path,
                      confirmOverwrite: () async =>
                          (await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              content: const Text("Overwrite?"),
                              actions: [
                                ElevatedButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text("No"),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: const Text("Yes"),
                                ),
                              ],
                            ),
                          )) ??
                          false,
                    );
                final bundleRegistry = ref.read(bundleRegistryManagerProvider);
                final bundleId = bundleRegistry.bundles.keys.first;
                await ref.read(bundleManagerProvider.notifier).selectBundle(bundleId);
              }
            },
            child: child,
          ),
          TextButton(
            onPressed: () async {
              final fitManager = ref.read(fitManagerProvider.notifier);
              await fitManager.newFit(28659, "Test Fit ${DateTime.now().toIso8601String()}");
            },
            child: Text("Found ${ref.watch(fitRegistryManagerProvider).fits.length} fits"),
          ),
          Text(ref.watch(nativeFitEngineServerProvider).debugOnlyDisplayState),
        ],
      ),
    );
  }
}
