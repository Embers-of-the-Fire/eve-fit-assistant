// The original content is temporarily commented out to allow generating a self-contained demo - feel free to uncomment later.

// import 'package:flutter/material.dart';
// // import 'package:provider/provider.dart';
// import 'front.dart' as front;
// import 'package:rinf/rinf.dart';
// import './messages/all.dart';
//
// void main() async {
//   await initializeRust(assignRustSignal);
//   runApp(const MyApp());
//   // runApp(MultiProvider(
//   //   providers: [],
//   //   child: const MyApp(),
//   // ));
// }
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   // This widget is the root of your application.
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'EVE Fit Assistant',
//       theme: ThemeData(
//         colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
//         useMaterial3: true,
//       ),
//       home: const front.FrontendPage(),
//     );
//   }
// }
//

import 'package:flutter/material.dart';
import 'package:eve_fit_assistant/src/rust/api/simple.dart';
import 'package:eve_fit_assistant/src/rust/frb_generated.dart';

Future<void> main() async {
  await RustLib.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('flutter_rust_bridge quickstart')),
        body: Center(
          child: Text(
              'Action: Call Rust `greet("Tom")`\nResult: `${greet(name: "Tom")}`'),
        ),
      ),
    );
  }
}
