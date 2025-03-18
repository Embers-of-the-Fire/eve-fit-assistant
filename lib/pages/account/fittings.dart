import 'package:eve_fit_assistant/pages/fit/panel/fit.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:eve_fit_assistant/web/esi/esi/character/fittings.dart';
import 'package:eve_fit_assistant/web/esi/storage/esi.dart';
import 'package:eve_fit_assistant/widgets/confirm_dialog.dart';
import 'package:eve_fit_assistant/widgets/import_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'fittings.g.dart';

@riverpod
Future<List<Fitting>?> getFittings(Ref ref) async =>
    await ref.watch(esiDataStorageProvider).getFittings();

@riverpod
Future<void> deleteFitting(Ref ref, int fittingID) async =>
    await ref.watch(esiDataStorageProvider.notifier).deleteFitting(fittingID);

class FittingsPage extends ConsumerWidget {
  const FittingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(esiDataStorageProvider);

    final content = switch (data.authorized) {
      true => _FittingsPanel(onRefresh: () {
          final _ = ref.refresh(getFittingsProvider);
          ref.read(esiDataStorageProvider.notifier).clearCache();
        }),
      false => const _FittingsNotAuthorized(),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('装配')),
      body: content,
    );
  }
}

class _FittingsPanel extends ConsumerWidget {
  final void Function() onRefresh;

  const _FittingsPanel({required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fittings = ref.watch(getFittingsProvider);

    return fittings.when(
      data: (fittings) => RefreshIndicator(
          onRefresh: () async => onRefresh(),
          child: ListView.builder(
              itemCount: fittings?.length ?? 0,
              itemBuilder: (context, index) {
                final fitting = fittings?[index];
                if (fitting == null) return const SizedBox.shrink();
                final ship = GlobalStorage().static.ships[fitting.shipTypeID];
                if (ship == null) {
                  return ListTile(
                    leading: const SizedBox(width: 32),
                    title: Text('[未知舰船 ${fitting.shipTypeID}] - ${fitting.name}'),
                    subtitle: fitting.description.isNotEmpty.thenSome(Text(fitting.description)),
                  );
                }
                return Slidable(
                    startActionPane:
                        ActionPane(motion: const StretchMotion(), extentRatio: 0.15, children: [
                      SlidableAction(
                        backgroundColor: Colors.green,
                        padding: EdgeInsets.zero,
                        label: '导入',
                        icon: Icons.input_outlined,
                        onPressed: (_) => _intoImportDialog(context, fitting),
                      ),
                    ]),
                    endActionPane:
                        ActionPane(motion: const StretchMotion(), extentRatio: 0.15, children: [
                      SlidableAction(
                        backgroundColor: Colors.red,
                        padding: EdgeInsets.zero,
                        label: '删除',
                        icon: Icons.delete_outline,
                        onPressed: (_) => showConfirmDialog(
                          context,
                          title: '删除装配',
                          description: '确定要删除这个装配吗？',
                          warning: '该行为会将此配置从你的账号中删除，无法撤回。\n\n'
                              '受 ESI 系统限制，装配数值的查询每 300 秒刷新一次。因此删除行为不会立刻生效。',
                          onConfirm: () async {
                            await ref.read(deleteFittingProvider(fitting.fittingID).future);
                            onRefresh();
                          },
                        ),
                      ),
                    ]),
                    child: ListTile(
                      leading: GlobalStorage()
                          .static
                          .icons
                          .getTypeIconSync(fitting.shipTypeID)
                          .orBox(width: 32),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      title: Text('[${ship.nameZH}] - ${fitting.name}'),
                      subtitle: fitting.description.isNotEmpty.thenSome(Text(fitting.description)),
                    ));
              })),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('加载装配信息失败', style: TextStyle(fontSize: 20)),
                const SizedBox(height: 20),
                SelectableText(error.toString()),
                const SizedBox(height: 20),
                SelectableText(
                  stackTrace.toString(),
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ]))),
    );
  }
}

class _FittingsNotAuthorized extends StatelessWidget {
  const _FittingsNotAuthorized();

  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('你还没有登录', style: TextStyle(fontSize: 20)));
}

Future<void> _intoImportDialog(BuildContext context, Fitting fit) async {
  final Map<int, int> typeMap = {};
  for (final item in fit.items) {
    switch (item.flag) {
      case FittingItemFlag.cargo ||
            FittingItemFlag.invalid ||
            FittingItemFlag.serviceSlot0 ||
            FittingItemFlag.serviceSlot1 ||
            FittingItemFlag.serviceSlot2 ||
            FittingItemFlag.serviceSlot3 ||
            FittingItemFlag.serviceSlot4 ||
            FittingItemFlag.serviceSlot5 ||
            FittingItemFlag.serviceSlot6 ||
            FittingItemFlag.serviceSlot7:
        continue;
      default:
        typeMap[item.typeID] = (typeMap[item.typeID] ?? 0) + item.quantity;
        break;
    }
  }
  final status =
      await showImportDialog(context, shipID: fit.shipTypeID, types: typeMap, name: fit.name);
  if (status == false || !context.mounted) return;
  Navigator.pop(context);
  final output = await GlobalStorage().ship.importEsiFit(fit);
  if (!context.mounted) return;
  await intoFitPage(context, output.brief.id);
}
