import 'package:eve_fit_assistant/web/esi/esi/character/skills.dart';
import 'package:eve_fit_assistant/web/esi/storage/esi.dart';
import 'package:eve_fit_assistant/widgets/skill_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'skills.g.dart';

@riverpod
Future<CharacterSkills?> getCharacterSkills(Ref ref) async =>
    await ref.watch(esiDataStorageProvider).getCharacterSkills();

class SkillsPage extends ConsumerWidget {
  const SkillsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(esiDataStorageProvider);

    final content = switch (data.authorized) {
      true => _SkillsPanel(onRefresh: () => ref.refresh(getCharacterSkillsProvider)),
      false => const _SkillsNotAuthorized(),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('技能')),
      body: content,
    );
  }
}

class _SkillsPanel extends ConsumerWidget {
  final void Function() onRefresh;

  const _SkillsPanel({required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skills = ref.watch(getCharacterSkillsProvider);

    return skills.when(
      data: (skills) => CharacterSkillList(skills: skills!.toSkillMap()),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('加载技能信息失败', style: TextStyle(fontSize: 20)),
                const SizedBox(height: 20),
                SelectableText(error.toString()),
                const SizedBox(height: 20),
                SelectableText(
                  stackTrace.toString(),
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ]))),
    );
  }
}

class _SkillsNotAuthorized extends StatelessWidget {
  const _SkillsNotAuthorized();

  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('你还没有登录', style: TextStyle(fontSize: 20)));
}
