import 'package:eve_fit_assistant/native/port/frb_generated.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'front.dart' as front;

Future main() async {
  await RustLib.init();
  configEasyLoading();
  runApp(const ProviderScope(child: MyApp()));
  // runApp(ChangeNotifierProvider.value(
  //   value: globalStorage,
  //   child: const MyApp(),
  // ));
}

void configEasyLoading() {
  EasyLoading.instance
    ..dismissOnTap = false
    ..userInteractions = false;
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future.delayed(const Duration(milliseconds: 150)).then((_) => GlobalStorage().init(ref));

    return MaterialApp(
      title: 'EVE Fit Assistant',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(brightness: Brightness.dark, seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const front.FrontendPage(),
      builder: EasyLoading.init(),
    );
    // });
  }
}

// The original content is temporarily commented out to allow generating a self-contained demo - feel free to uncomment later.
//
// import 'package:flutter/material.dart';
// import 'package:eve_fit_assistant/src/rust/api/simple.dart';
// import 'package:eve_fit_assistant/src/rust/frb_generated.dart';
//
// Future<void> main() async {
//   await RustLib.init();
//   runApp(const MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: Scaffold(
//         appBar: AppBar(title: const Text('flutter_rust_bridge quickstart')),
//         body: Center(
//           child: Text(
//               'Action: Call Rust `greet("Tom")`\nResult: `${greet(name: "Tom")}`'),
//         ),
//       ),
//     );
//   }
// }
