import 'package:eve_fit_assistant/content/announcement.dart';
import 'package:eve_fit_assistant/utils/itertools.dart';
import 'package:eve_fit_assistant/utils/sort.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'content.g.dart';

class Content {
  final String title;
  final String path;
  final DateTime time;
  final IconData icon;

  const Content({
    required this.title,
    required this.path,
    required this.time,
    this.icon = Icons.dashboard,
  });

  static List<Content> of(Iterable<Content> contents) {
    return contents
        .sortedByKey<Reversed<num>>((content) => Reversed(content.time.millisecondsSinceEpoch))
        .toList();
  }
}

final List<Content> contents = Content.of([
  ...announcementContents,
]);

@riverpod
Future<String> markdownContent(Ref ref, String contentKey) async {
  final out = await rootBundle.loadString(contentKey);
  return out;
}
