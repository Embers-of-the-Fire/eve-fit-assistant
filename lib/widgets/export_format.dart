import 'package:eve_fit_assistant/export/game_url.dart';
import 'package:eve_fit_assistant/export/schema.dart';
import 'package:eve_fit_assistant/storage/fit/fit.dart';
import 'package:eve_fit_assistant/widgets/dialog.dart';
import 'package:eve_fit_assistant/widgets/radio_button_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<bool?> showExportFormatDialog(BuildContext context, {required FitRecord fit}) async =>
    await showDialog<bool?>(
      context: context,
      builder: (context) => ExportFormatDialog(fit: fit),
    );

enum _ExportFormat {
  efa,
  gameLink;

  String get name => switch (this) {
        efa => 'EFA 编码',
        gameLink => '游戏内链',
      };

  SelectableText get desc => switch (this) {
        efa => const SelectableText('导出为 EFA 的专有格式，只能在 EFA 中使用，但是可以保存更多具体信息，包括深渊装备等。'),
        gameLink => const SelectableText.rich(TextSpan(children: [
            TextSpan(text: '导出为游戏内黄字链接，黏贴到游戏内的邮件/笔记本等文本框即可转换为链接。\n\n'),
            TextSpan(
                text: '注意：黏贴到聊天窗口处无效，请先黏贴到笔记本中然后再拖拽至聊天窗口。\n\n',
                style: TextStyle(color: Colors.yellow)),
            TextSpan(
                text: '提醒：游戏内装配链接无法包含深渊装备数值、植入体、增效剂和启用状况等信息。\n\n',
                style: TextStyle(color: Colors.red))
          ])),
      };
}

class ExportFormatDialog extends StatefulWidget {
  final FitRecord fit;

  const ExportFormatDialog({super.key, required this.fit});

  @override
  State<ExportFormatDialog> createState() => _ExportFormatDialogState();
}

class _ExportFormatDialogState extends State<ExportFormatDialog> {
  _ExportFormat _exportFormat = _ExportFormat.efa;

  @override
  Widget build(BuildContext context) => AppDialog(
        title: '导出格式',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RadioButtonGroup<_ExportFormat>(
                choices: const [
                  _ExportFormat.efa,
                  _ExportFormat.gameLink,
                ],
                builder: (context, choice) => Text(choice.name, textAlign: TextAlign.center),
                groupBuilder: (context, children) => Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      spacing: 8,
                      children: children.map((el) => Expanded(child: el)).toList(growable: false),
                    ),
                selected: _exportFormat,
                onChanged: (choice) => setState(() {
                      _exportFormat = choice;
                    })),
            const Divider(indent: 0, endIndent: 0),
            _exportFormat.desc,
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
          TextButton(
              onPressed: () async {
                switch (_exportFormat) {
                  case _ExportFormat.efa:
                    final export = FitExport.fromRecord(widget.fit);
                    final text = export.encoded;
                    await Clipboard.setData(ClipboardData(text: text));
                    break;
                  case _ExportFormat.gameLink:
                    final text = exportToGameUrl(widget.fit);
                    await Clipboard.setData(ClipboardData(text: text));
                    break;
                }
                if (context.mounted) {
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('导出')),
        ],
      );
}
