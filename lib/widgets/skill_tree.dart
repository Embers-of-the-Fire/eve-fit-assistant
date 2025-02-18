import 'package:flutter/material.dart';

class SkillTree extends StatefulWidget {
  final bool keepAlive;

  const SkillTree({super.key, this.keepAlive = true});

  @override
  State<SkillTree> createState() => _SkillTreeState();
}

class _SkillTreeState extends State<SkillTree> with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const Placeholder();
  }

  @override
  bool get wantKeepAlive => widget.keepAlive;
}
