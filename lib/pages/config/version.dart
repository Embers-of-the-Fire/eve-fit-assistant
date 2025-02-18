import 'package:eve_fit_assistant/content/changelog.dart';
import 'package:eve_fit_assistant/widgets/content.dart';
import 'package:flutter/material.dart';

class VersionPage extends StatelessWidget {
  const VersionPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text('版本信息'),
          centerTitle: true,
        ),
        body: ContentList(contents: changelogContents),
      );
}
