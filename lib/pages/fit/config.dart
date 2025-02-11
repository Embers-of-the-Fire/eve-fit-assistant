part of 'fit.dart';

class ConfigTab extends ConsumerStatefulWidget {
  final String fitID;
  final String name;
  final String description;

  const ConfigTab({
    super.key,
    required this.fitID,
    required this.name,
    required this.description,
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
          side: BorderSide(color: Colors.red),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: const Text(
          '取消',
          style: TextStyle(color: Colors.red),
        ),
      ));
      bottomAction.add(SizedBox(width: 20));
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
          side: BorderSide(color: Colors.green),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          side: BorderSide(color: Colors.blue),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: const Text(
          '修改',
          style: TextStyle(color: Colors.blue),
        ),
      ));
    }

    return Form(
      key: form,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
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
                // hintText: '装配名称',
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
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: bottomAction,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
