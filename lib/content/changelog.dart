import 'package:eve_fit_assistant/content/content.dart';
import 'package:flutter/material.dart';

final List<Content> changelogContents = Content.of([
  Content(
      icon: Icons.update,
      title: '更新日志 EFA v0.5.0',
      path: 'content/changelog/v0.5.0.md',
      time: DateTime(2025, 2, 18, 19, 47)),
  Content(
      icon: Icons.update,
      title: '更新日志 EFA v0.4.0',
      path: 'content/changelog/v0.4.0.md',
      time: DateTime(2025, 2, 18, 10, 40)),
  Content(
      icon: Icons.update,
      title: '更新日志 EFA v0.3.0',
      path: 'content/changelog/v0.3.0.md',
      time: DateTime(2025, 2, 15, 19, 44)),
  Content(
      icon: Icons.update,
      title: '更新日志 EFA v0.2.0',
      path: 'content/changelog/v0.2.0.md',
      time: DateTime(2025, 2, 15, 10, 07)),
]);
