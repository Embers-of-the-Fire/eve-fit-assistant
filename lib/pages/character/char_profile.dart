part of 'char_edit.dart';

class CharacterProfileTab extends ConsumerStatefulWidget {
  final String charID;
  final String name;
  final String description;

  const CharacterProfileTab({
    super.key,
    required this.charID,
    required this.name,
    required this.description,
  });

  @override
  ConsumerState<CharacterProfileTab> createState() => _CharacterProfileTabState();
}

class _CharacterProfileTabState extends ConsumerState<CharacterProfileTab> {
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
    final char = ref.read(characterNotifierProvider(widget.charID).notifier);

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
            char.setProfile(nameController.text, descController.text);
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

    return Form(
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
                  return '请输入角色名称';
                }
                return null;
              },
              decoration: const InputDecoration(
                label: Text('角色名称'),
              ),
            ),
            TextFormField(
              readOnly: !editable,
              controller: descController,
              maxLines: 10,
              decoration: const InputDecoration(
                label: Text('角色备注'),
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
    );
  }
}
