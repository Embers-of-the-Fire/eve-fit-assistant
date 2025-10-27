import "package:eve_fit_assistant/components/list/eve_list_tile.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/storage/bundle/manager.dart";
import "package:eve_fit_assistant/storage/bundle/service.dart";
import "package:eve_fit_assistant/storage/bundle/service/collection.dart";
import "package:eve_fit_assistant/storage/fit/manager.dart";
import "package:eve_fit_assistant/storage/fit/service.dart";
import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class CharacterPage extends ConsumerWidget {
  const CharacterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Widget> children = [];
    if (ref.watch(bundleServiceProvider).isLoaded) {
      children.add(const TypeListTile(typeId: 236));
      final type = ref.watch(bundleCollectionGetTypeProvider(236));
      if (type != null) {
        children
          ..add(MarketGroupListTile(marketGroupId: type.marketGroupId))
          ..add(GroupListTile(groupId: type.groupId));
        final group = ref.watch(bundleCollectionGetGroupProvider(type.groupId));
        if (group != null) {
          children.add(CategoryListTile(categoryId: group.categoryId));
        }
      }
    } else {
      children.add(const Text("Initialize"));
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
            child: const Text("Load Bundle"),
          ),
          ...children,
          TextButton(
            onPressed: () async {
              final fitManager = ref.read(fitManagerProvider.notifier);
              await fitManager.newFit(28659, "Test Fit ${DateTime.now().toIso8601String()}");
            },
            child: Text("Found ${ref.watch(fitRegistryManagerProvider).fits.length} fits"),
          ),
          Text(ref.watch(nativeFitEngineServiceProvider).debugOnlyDisplayState),
        ],
      ),
    );
  }
}
