import 'package:eve_fit_assistant/widgets/dialog.dart';
import 'package:flutter/material.dart';

Future<String?> showShipCreateDialog(BuildContext context) {
  final form = GlobalKey<FormState>();
  final controller = TextEditingController(text: '新配置');

  return showDialog<String>(
    context: context,
    builder: (context) => AppDialog(
      title: '创建舰船',
      content: Form(
          key: form,
          child: TextFormField(
            controller: controller,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '请输入舰船名称';
              }
              return null;
            },
            decoration: const InputDecoration(
              hintText: '装配名称',
            ),
          )),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            if (form.currentState?.validate() ?? false) {
              Navigator.of(context).pop(controller.text);
            }
          },
          child: const Text('确认'),
        ),
      ],
    ),
  );
}
