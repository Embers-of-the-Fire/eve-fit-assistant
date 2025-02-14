import 'package:date_format/date_format.dart';
import 'package:eve_fit_assistant/content/announcement.dart';
import 'package:eve_fit_assistant/pages/announcement/detail.dart';
import 'package:flutter/material.dart';

const testMarkdown = '''# Test
123

```rust
fn main() {
    println!("Hello, world!");
}
```
''';

class AnnouncementPage extends StatelessWidget {
  const AnnouncementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('公告'),
      ),
      body: ListView(
        children: announcementContents
            .map((content) => Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey)),
                ),
                child: ListTile(
                  leading: Icon(content.icon),
                  title: Text(content.title),
                  subtitle:
                      Text(formatDate(content.time, [yyyy, '-', mm, '-', dd, ' ', HH, ':', nn])),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => AnnouncementDetailPage(
                      title: content.title,
                      time: content.time,
                      path: content.path,
                    ),
                  )),
                )))
            .toList(),
      ),
    );
  }
}
