import 'package:eve_fit_assistant/content/announcement.dart';
import 'package:eve_fit_assistant/utils/content.dart';
import 'package:flutter/material.dart';

class AnnouncementPage extends StatelessWidget {
  const AnnouncementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('公告'),
      ),
      body: ContentList(contents: announcementContents),
    );
  }
}
