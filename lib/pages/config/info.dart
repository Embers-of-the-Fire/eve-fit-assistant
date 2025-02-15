import 'package:eve_fit_assistant/constant/constant.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:flutter/material.dart';

class InfoPage extends StatelessWidget {
  const InfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: logoBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('关于'),
        centerTitle: true,
      ),
      body: DefaultTextStyle(
        style: const TextStyle(fontSize: 20, color: Colors.black),
        child: Center(
          child: Column(
            children: [
              Image.asset(logo),
              const Padding(
                padding: EdgeInsets.only(bottom: 40),
                child: Text(
                  'EVE Fit Assistant',
                  style: TextStyle(fontSize: 36),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 100),
                child: Row(children: [
                  const Text('软件版本'),
                  Expanded(
                      child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(GlobalStorage().packageInfo.version),
                  )),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 100),
                child: Row(children: [
                  const Text('Flutter 版本'),
                  Expanded(
                      child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(flutterVersion.stringify()),
                  )),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 100),
                child: Row(children: [
                  const Text('Dart 版本'),
                  Expanded(
                      child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(dartVersion.stringify()),
                  )),
                ]),
              ),
              const Expanded(
                  child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(left: 20, right: 20, bottom: 40),
                  child: Text(
                    'Flutter and the related logo are trademarks of '
                    'Google LLC.\nThis project is not endorsed by '
                    'or affiliated with Google LLC.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ))
            ],
          ),
        ),
      ),
    );
  }
}
