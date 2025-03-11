import 'package:eve_fit_assistant/web/esi/auth/auth.dart';
import 'package:flutter/material.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  EsiAuthData? _resp;

  @override
  void initState() {
    EsiAuth().getStorage(context).then((u) => setState(() {
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
                Image.network(
                  'https://image.eveonline.com/Character/${_resp!.characterID}_128.jpg',
                  width: 128,
                ),
                const SizedBox(height: 20),
                Text(
                  _resp!.characterName ?? '<未知>',
                  style: const TextStyle(fontSize: 20),
                ),
                Text(
                  _resp!.characterID.toString(),
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ]
            ])),
      );
}
