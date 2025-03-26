import 'package:eve_fit_assistant/storage/character/character.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/widgets/skill_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'char_edit.g.dart';
part 'char_profile.dart';
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

  Future<void> setProfile(String name, String desc) async {
    await modify((char) {
      char.name = name;
      char.description = desc;
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

Future<void> showCharacterEditPage(BuildContext context, {required String id}) =>
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => CharacterEditPageContent(id: id)));

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
        appBar: AppBar(title: const Text('加载中...')),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
}

class CharacterEditPageContent extends ConsumerStatefulWidget {
  final String id;

  const CharacterEditPageContent({super.key, required this.id});

  @override
  ConsumerState createState() => _CharacterEditPageContentState();
}

class _CharacterEditPageContentState extends ConsumerState<CharacterEditPageContent>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;

  @override
  void initState() {
    _controller = TabController(length: 2, vsync: this);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final char = ref.watch(characterNotifierProvider(widget.id));

    if (!char.initialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
        appBar: AppBar(
          title: Text('角色配置 - ${char.character.name}'),
          actions: [
            Container(
              padding: const EdgeInsets.only(right: 10),
              child: Icon(char.saved ? Icons.download_done : Icons.downloading),
            )
          ],
          bottom: TabBar(
            controller: _controller,
            tabs: const ['技能', '信息'].map((e) => Tab(text: e)).toList(),
          ),
        ),
        // body: CharacterSkillList(id: id),
        body: SafeArea(
            bottom: true,
            child: TabBarView(controller: _controller, children: [
              CharacterSkillListPage(id: widget.id),
              CharacterProfileTab(
                charID: widget.id,
                name: char.character.name,
                description: char.character.description,
              ),
            ])));
  }
}
