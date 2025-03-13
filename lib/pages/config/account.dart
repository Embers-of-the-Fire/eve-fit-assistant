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
  Character? _resp;

  @override
  void initState() {
    (ref.read(esiDataProvider).authorized ? Future(() => null) : showAuthPage(context))
        .then((_) async => await EsiDataStorage().getCharacter())
        .then((u) => setState(() {
              _resp = u;
            }));
    super.initState();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text('账户管理'),
          centerTitle: true,
        ),
        body: SizedBox(
            width: double.infinity,
            child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
              const SizedBox(height: 50),
              if (_resp != null) ...[
                getCharacterImage(Preference().esiAuthServer, _resp!.characterID),
                const SizedBox(height: 20),
                Text(
                  _resp!.characterName ?? '<未知>',
                  style: const TextStyle(fontSize: 20),
                ),
                Text(
                  _resp!.characterID.toString(),
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                    onPressed: () async {
                      await EsiDataStorage().clearAuthorize();
                      setState(() {
                        _resp = null;
                      });
                    },
                    child: const Text('退出登录'))
              ]
            ])),
      );
}
