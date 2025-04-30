part of 'fit.dart';

class ConfigTab extends ConsumerStatefulWidget {
  final String fitID;
  final String name;
  final String description;
  final void Function() onScreenShot;

  const ConfigTab({
    super.key,
    required this.fitID,
    required this.name,
    required this.description,
    required this.onScreenShot,
  });

  @override
  ConsumerState<ConfigTab> createState() => _ConfigTabState();
}

class _ConfigTabState extends ConsumerState<ConfigTab> {
  final form = GlobalKey<FormState>();

  late final TextEditingController nameController;
  late final TextEditingController descController;

  bool editable = false;

  // bool editable = true;

  @override
  void initState() {
    nameController = TextEditingController(text: widget.name);
    descController = TextEditingController(text: widget.description);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final fit = ref.read(fitRecordNotifierProvider(widget.fitID).notifier);

    final List<Widget> bottomAction = [];
    if (editable) {
      bottomAction.add(OutlinedButton(
        onPressed: () => setState(() {
          editable = false;
          nameController.text = widget.name;
          descController.text = widget.description;
        }),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.red),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: const Text(
          '取消',
          style: TextStyle(color: Colors.red),
        ),
      ));
      bottomAction.add(const SizedBox(width: 20));
      bottomAction.add(OutlinedButton(
        onPressed: () {
          if (form.currentState?.validate() ?? false) {
            fit.modify((item) {
              item.brief.name = nameController.text;
              item.brief.description = descController.text;
              return item;
            });
            setState(() {
              editable = false;
            });
          }
        },
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.green),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: const Text(
          '保存',
          style: TextStyle(color: Colors.green),
        ),
      ));
    } else {
      bottomAction.add(OutlinedButton(
        onPressed: () => setState(() {
          editable = true;
        }),
        style: TextButton.styleFrom(
          side: const BorderSide(color: Colors.blue),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: const Text(
          '修改',
          style: TextStyle(color: Colors.blue),
        ),
      ));
    }

    return Column(children: [
      Padding(
        padding: const EdgeInsets.only(top: 20),
        child: ElevatedButton(onPressed: widget.onScreenShot, child: const Text('导出图片')),
      ),
      Form(
        key: form,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          child: Column(
            children: [
              TextFormField(
                readOnly: !editable,
                controller: nameController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入装配名称';
                  }
                  return null;
                },
                decoration: const InputDecoration(
                  label: Text('装配名称'),
                ),
              ),
              TextFormField(
                readOnly: !editable,
                controller: descController,
                maxLines: 10,
                decoration: const InputDecoration(
                  label: Text('装配备注'),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: bottomAction,
                ),
              ),
            ],
          ),
        ),
      )
    ]);
  }
}
