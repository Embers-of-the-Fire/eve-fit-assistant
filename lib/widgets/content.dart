import 'package:date_format/date_format.dart';
import 'package:eve_fit_assistant/content/content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_widget/markdown_widget.dart';

class ContentList extends StatelessWidget {
  final List<Content> contents;

  const ContentList({super.key, required this.contents});

  @override
  Widget build(BuildContext context) => Scrollbar(
        child: ListView(
          children: contents.map((content) => ContentListTile(content: content)).toList(),
        ),
      );
}

class ContentListTile extends StatelessWidget {
  final Content content;

  const ContentListTile({super.key, required this.content});

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey)),
        ),
        child: ListTile(
          leading: Icon(content.icon),
          title: Text(content.title),
          subtitle: Text(formatDate(content.time, [yyyy, '-', mm, '-', dd, ' ', HH, ':', nn])),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => ContentDetailPage(content: content),
          )),
        ),
      );
}

class ContentDetailPage extends ConsumerWidget {
  final Content content;

  const ContentDetailPage({super.key, required this.content});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = ref.watch(markdownContentProvider(content.path));

    return Scaffold(
      appBar: AppBar(title: Text(content.title)),
      body: switch (text) {
        AsyncData(:final value) => Column(
            children: [
              const SizedBox(height: 10),
              Text('发布于：${formatDate(content.time, [yyyy, '-', mm, '-', dd, ' ', HH, ':', nn])}'),
              const Divider(),
              Expanded(
                child: Scrollbar(
                    child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.only(top: 4, bottom: 10, left: 20, right: 20),
                    child: MarkdownBlock(
                      data: value,
                      config: MarkdownConfig.darkConfig,
                    ),
                  ),
                )),
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
