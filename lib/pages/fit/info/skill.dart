part of 'item_info.dart';

class SkillTab extends StatelessWidget {
  final int rootID;

  const SkillTab({super.key, required this.rootID});

  @override
  Widget build(BuildContext context) => SkillTree(rootID: rootID);
}
