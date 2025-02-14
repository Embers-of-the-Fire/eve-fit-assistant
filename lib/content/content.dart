import 'package:eve_fit_assistant/content/announcement.dart';
import 'package:flutter/material.dart';

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
}

final List<Content> contents = [
  ...announcementContents,
];
