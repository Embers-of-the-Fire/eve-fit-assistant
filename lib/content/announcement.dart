import 'package:eve_fit_assistant/content/changelog.dart';
import 'package:eve_fit_assistant/content/content.dart';
import 'package:flutter/material.dart';

final List<Content> announcementContents = Content.of([
  Content(
      icon: Icons.celebration,
      title: '关于正式版的信息和未来计划',
      path: 'content/announcement/about-stable-version.md',
      time: DateTime(2025, 3, 20, 18, 09)),
  Content(
      icon: Icons.info_outline,
      title: '关于 BETA 测试的一些须知和信息',
      path: 'content/announcement/about-beta-test-version.md',
      time: DateTime(2025, 3, 1, 19, 37)),
  Content(
      icon: Icons.info_outline,
      title: '关于测试版的一些须知和信息',
      path: 'content/announcement/about-test-version.md',
      time: DateTime(2025, 2, 14, 16, 18)),
  ...changelogContents,
]);
