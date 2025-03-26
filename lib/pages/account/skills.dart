import 'package:eve_fit_assistant/pages/account/account.dart';
import 'package:eve_fit_assistant/pages/character/char_edit.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/utils/utils.dart';
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
    final dataNotifier = ref.read(esiDataStorageProvider.notifier);

    final content = switch (data.authorized) {
      true => _SkillsPanel(onRefresh: () async => await dataNotifier.refreshCharacterSkills()),
      false => const _SkillsNotAuthorized(),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('技能')),
      body: SafeArea(bottom: true, child: content),
    );
  }
}

class _SkillsPanel extends ConsumerWidget {
  final void Function() onRefresh;

  const _SkillsPanel({required this.onRefresh});

  Future<void> _onImport({
    required Map<int, int> skills,
    required WidgetRef ref,
  }) async {
    final char = await ref.watch(getCharacterProvider.future);
    if (char == null) return;
    final character = await GlobalStorage()
        .character
        .createFromSkills(char.characterName ?? '角色 ${char.characterID}', skills);
    if (!ref.context.mounted) return;
    await showCharacterEditPage(ref.context, id: character.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skills = ref.watch(getCharacterSkillsProvider);

    return skills.when(
      data: (skills) => Column(children: [
        Theme(
            data: ThemeData(
                elevatedButtonTheme: ElevatedButtonThemeData(
                    style: Theme.of(context).elevatedButtonTheme.style?.copyWith(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16)
                              .widgetStateProperty,
                        ))),
            child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, spacing: 20, children: [
                  ElevatedButton(onPressed: () => onRefresh(), child: const Text('刷新列表')),
                  ElevatedButton(
                      onPressed: () => _onImport(skills: skills!.toSkillMap(), ref: ref),
                      child: const Text('导入为角色')),
                ]))),
        const Divider(height: 4, indent: 0, endIndent: 0),
        Expanded(child: CharacterSkillList(skills: skills!.toSkillMap())),
      ]),
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
