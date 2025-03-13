part of 'char_edit.dart';

class CharacterSkillListPage extends ConsumerStatefulWidget {
  final String id;

  const CharacterSkillListPage({super.key, required this.id});

  @override
  ConsumerState createState() => _CharaState();
}

class _CharaState extends ConsumerState<CharacterSkillListPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final charNotifier = ref.read(characterNotifierProvider(widget.id).notifier);
    final char = ref.watch(characterNotifierProvider(widget.id));

    if (!char.initialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return CharacterSkillList(
      skills: char.character.skills,
      onTapLevel: (id, level) =>
          charNotifier.setSkillLevel(id, level == char.character.skills[id] ? 0 : level),
    );
  }
}
