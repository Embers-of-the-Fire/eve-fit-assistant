import 'package:eve_fit_assistant/storage/preference/preference.dart';
import 'package:eve_fit_assistant/web/esi/auth/auth.dart';
import 'package:eve_fit_assistant/web/esi/image.dart';
import 'package:eve_fit_assistant/web/esi/storage/esi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'account.g.dart';

@riverpod
Future<Character?> getCharacter(Ref ref, int timestamp) async =>
    await EsiDataStorage().getCharacter();

class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  int _timestamp = 0;

  @override
  void initState() {
    super.initState();
    _timestamp = DateTime.now().millisecondsSinceEpoch;
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(esiDataProvider).authorized) {
      return _AccountPanel(
          timestamp: _timestamp,
          onRefresh: () => setState(() {
                // _timestamp = DateTime.now().millisecondsSinceEpoch;
              }));
    } else {
      return const _AccountNotAuthorized();
    }
  }
}

class _AccountPanel extends ConsumerWidget {
  final int timestamp;
  final void Function() onRefresh;

  const _AccountPanel({required this.timestamp, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final character = ref.watch(getCharacterProvider(timestamp));

    return character.when(
      data: (character) => RefreshIndicator(
          onRefresh: () async => onRefresh(),
          child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.all(20),
                    leading: getCharacterImage(Preference().esiAuthServer, character!.characterID),
                    title: SelectableText(character.characterName ?? '<未知>',
                        style: const TextStyle(fontSize: 20)),
                    trailing: SelectableText(character.characterID.toString()),
                  ),
                  const Divider(height: 0, color: Colors.grey),
                ],
              ))),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('加载角色信息失败', style: TextStyle(fontSize: 20)),
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

class _AccountNotAuthorized extends StatelessWidget {
  const _AccountNotAuthorized();

  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('你还没有登录', style: TextStyle(fontSize: 20)),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => EsiAuth().autoAuth(context),
          child: const Text('登录并授权'),
        )
      ]));
}
