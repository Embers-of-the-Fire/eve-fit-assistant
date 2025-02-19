import 'package:eve_fit_assistant/constant/eve/categories.dart';
import 'package:eve_fit_assistant/storage/character/character.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:eve_fit_assistant/widgets/skill_tree.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'char_edit.g.dart';
part 'char_skill_list.dart';

@riverpod
class CharacterNotifier extends _$CharacterNotifier {
  @override
  CharacterState build(String id) {
    final s = CharacterState(id: id);

    GlobalStorage().character.get(id).then((rec) async {
      state = await CharacterState.init(rec);
    });

    return s;
  }

  Future<void> modify(FutureOr<Character> Function(Character) modifier) async {
    if (!state.initialized) {
      return;
    }

    final temp = await CharacterState.init(state.character);
    temp.saved = false;
    state = temp;
    final char = await modifier(state.character);
    await char.save();
    state = await CharacterState.init(char);
  }

  Future<void> setSkillLevel(int skillID, int level) async {
    await modify((char) {
      char.skills[skillID] = level;
      return char;
    });
  }
}

class CharacterState {
  String id;
  late Character character;
  bool saved = false;
  bool initialized = false;

  CharacterState({required this.id, this.saved = false});

  static Future<CharacterState> init(Character character) async {
    final s = CharacterState(id: character.id, saved: true);
    s.character = character;
    s.initialized = true;
    return s;
  }
}

class CharacterEditPage extends ConsumerWidget {
  final String id;

  const CharacterEditPage({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final char = ref.watch(characterNotifierProvider(id));

    if (!char.initialized) {
      return const CharacterEditPagePlaceholder();
    }

    return CharacterEditPageContent(id: id);
  }
}

class CharacterEditPagePlaceholder extends StatelessWidget {
  const CharacterEditPagePlaceholder({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text('加载中...'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
}

class CharacterEditPageContent extends ConsumerWidget {
  final String id;

  const CharacterEditPageContent({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final char = ref.watch(characterNotifierProvider(id));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('角色配置'),
        actions: [
          Container(
            padding: const EdgeInsets.only(right: 10),
            child: Icon(char.saved ? Icons.download_done : Icons.downloading),
          )
        ],
      ),
      body: CharacterSkillList(id: id),
    );
  }
}
