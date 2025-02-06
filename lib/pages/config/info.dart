import 'package:eve_fit_assistant/constant/constant.dart';
import 'package:flutter/material.dart';

class InfoPage extends StatelessWidget {
  const InfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: logoBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        // title: Center(child: Row(children: [Icon(Icons.info), Text('关于')])),
        title: const Text('关于'),
        centerTitle: true,
      ),
      body: DefaultTextStyle(
        style: TextStyle(fontSize: 20, color: Colors.black),
        child: Center(
          child: Column(
            children: [
              Image.asset(logo),
              Padding(
                padding: EdgeInsets.only(bottom: 40),
                child: Text(
                  'EVE Fit Assistant',
                  style: TextStyle(fontSize: 36),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(left: 100, right: 100),
                child: Row(children: [
                  Text('软件版本'),
                  Expanded(
                      child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(appVersion.stringify()),
                  )),
                ]),
              ),
              Padding(
                padding: EdgeInsets.only(left: 100, right: 100),
                child: Row(children: [
                  Text('Flutter 版本'),
                  Expanded(
                      child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(flutterVersion.stringify()),
                  )),
                ]),
              ),
              Padding(
                padding: EdgeInsets.only(left: 100, right: 100),
                child: Row(children: [
                  Text('Dart 版本'),
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
