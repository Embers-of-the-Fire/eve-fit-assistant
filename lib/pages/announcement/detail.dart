import 'dart:developer';

import 'package:date_format/date_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'detail.g.dart';

@riverpod
Future<String> _markdownContent(Ref ref, String contentKey) async {
  // final out = await rootBundle.loadString(contentKey);
  final out = await rootBundle.loadString('content/announcement/about-test-version.md');
  log(out, name: '_markdownContent');
  return out;
}

class AnnouncementDetailPage extends ConsumerWidget {
  final String title;
  final DateTime time;
  final String path;

  const AnnouncementDetailPage({
    super.key,
    required this.title,
    required this.time,
    required this.path,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(_markdownContentProvider(path));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(title),
      ),
      body: switch (content) {
        AsyncData(:final value) => Column(
            children: [
              const SizedBox(height: 10),
              Text('发布于：${formatDate(time, [yyyy, '-', mm, '-', dd, ' ', HH, ':', nn])}'),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.only(top: 4, bottom: 10, left: 20, right: 20),
                    child: MarkdownBlock(
                      data: value,
                      config: MarkdownConfig.darkConfig,
                    ),
                  ),
                ),
              )
            ],
          ),
        AsyncError(:final error, :final stackTrace) => Center(
              child: Container(
            padding: const EdgeInsets.all(20),
            child: Text('发生错误：$error\n\n$stackTrace'),
          )),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
