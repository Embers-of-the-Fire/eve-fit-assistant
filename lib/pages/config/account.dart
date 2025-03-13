import 'package:eve_fit_assistant/pages/account/account.dart';
import 'package:eve_fit_assistant/storage/preference/preference.dart';
import 'package:eve_fit_assistant/web/esi/auth/auth.dart';
import 'package:eve_fit_assistant/web/esi/image.dart';
import 'package:eve_fit_assistant/web/esi/storage/esi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  @override
  Widget build(BuildContext context) {
    final data = ref.watch(esiDataProvider);
    if (!data.authorized) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('你还没有登录', style: TextStyle(fontSize: 20)),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => EsiAuth().autoAuth(context),
          child: const Text('登录并授权'),
        )
      ]));
    }

    final char = ref.watch(getCharacterProvider);

    final inner = char.when(
      data: (data) => SizedBox(
          width: double.infinity,
          child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            const SizedBox(height: 50),
            if (data != null) ...[
              getCharacterImage(Preference().esiAuthServer, data.characterID),
              const SizedBox(height: 20),
              Text(
                data.characterName ?? '<未知>',
                style: const TextStyle(fontSize: 20),
              ),
              Text(
                data.characterID.toString(),
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                  onPressed: () async {
                    await EsiDataStorage().clearAuthorize();
                    final _ = ref.refresh(getCharacterProvider);
                  },
                  child: const Text('退出登录'))
            ]
          ])),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('加载角色信息失败', style: TextStyle(fontSize: 20)),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => ref.refresh(getCharacterProvider),
                  child: const Text('重试'),
                )
              ]))),
    );
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('账户管理'),
        centerTitle: true,
      ),
      body: inner,
    );
  }
}
