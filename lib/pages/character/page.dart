import "dart:async";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/pages/character/skill_list.dart";
import "package:eve_fit_assistant/storage/character/manager.dart";
import "package:eve_fit_assistant/storage/character/schema.dart";
import "package:eve_fit_assistant/storage/character/service.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:eve_fit_assistant/utils/datetime.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class CharacterPage extends ConsumerWidget {
  const CharacterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.watch(characterRegistryManagerProvider);
    final customCharacters =
        registry.characters.values
            .where(
              (metadata) => !CharacterRegistryManager.isBuiltInCharacterId(metadata.characterId),
            )
            .toList()
          ..sort((left, right) => right.lastModified.compareTo(left.lastModified));

    return ListView(
      children: [
        _CharacterSectionHeader(title: context.l10n.characterBuiltInProfiles),
        for (final characterId in CharacterRegistryManager.builtInCharacterIds)
          _CharacterProfileTile(
            characterId: characterId,
            metadata: registry.characters[characterId],
            canEdit: false,
          ),
        _CharacterSectionHeader(
          title: context.l10n.characterCustomProfiles,
          trailing: IconButton(
            tooltip: context.l10n.characterCreateProfile,
            onPressed: () => _createCharacter(context, ref),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ),
        if (customCharacters.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Text(
              context.l10n.characterNoCustomProfiles,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final metadata in customCharacters)
            _CharacterProfileTile(
              characterId: metadata.characterId,
              metadata: metadata,
              canEdit: true,
            ),
      ],
    );
  }

  Future<void> _createCharacter(BuildContext context, WidgetRef ref) async {
    CharacterStorage character;
    try {
      character = await ref
          .read(characterRegistryManagerProvider.notifier)
          .createCharacter(name: context.l10n.characterNewProfileName);
    } on Object catch (errorValue, stackTrace) {
      error("Failed to create character profile", error: errorValue, stackTrace: stackTrace);
      if (context.mounted) {
        _showCharacterActionError(
          context,
          context.l10n.characterCreateProfileError(message: errorValue.toString()),
        );
      }
      return;
    }
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => CharacterEditPage(characterId: character.characterId),
      ),
    );
  }
}

class _CharacterSectionHeader extends StatelessWidget {
  const _CharacterSectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    title: Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
    trailing: trailing,
  );
}

enum _CharacterProfileAction { clone, edit, delete }

class _CharacterProfileTile extends ConsumerWidget {
  const _CharacterProfileTile({
    required this.characterId,
    required this.metadata,
    required this.canEdit,
  });

  final String characterId;
  final CharacterMetadata? metadata;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = characterDisplayName(context, characterId, metadata);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(canEdit ? Icons.account_circle : Icons.verified_user_outlined),
      ),
      title: Text(title),
      subtitle: _subtitle(context),
      onTap: canEdit ? () => _edit(context) : null,
      trailing: PopupMenuButton<_CharacterProfileAction>(
        onSelected: (action) => _handleAction(context, ref, action, title),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: _CharacterProfileAction.clone,
            child: ListTile(leading: const Icon(Icons.copy), title: Text(context.l10n.copy)),
          ),
          if (canEdit)
            PopupMenuItem(
              value: _CharacterProfileAction.edit,
              child: ListTile(leading: const Icon(Icons.edit), title: Text(context.l10n.edit)),
            ),
          if (canEdit)
            PopupMenuItem(
              value: _CharacterProfileAction.delete,
              child: ListTile(
                leading: const Icon(Icons.delete_forever),
                title: Text(context.l10n.delete),
              ),
            ),
        ],
      ),
    );
  }

  Widget? _subtitle(BuildContext context) {
    final metadata = this.metadata;
    if (metadata == null) {
      return null;
    }
    if (!canEdit) {
      return metadata.description.isEmpty ? null : Text(metadata.description);
    }
    final lastModified = DateTime.fromMillisecondsSinceEpoch(metadata.lastModified);
    return Text(
      context.l10n.characterLastModified(time: yMMMMdHmsLocalized(context).format(lastModified)),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    _CharacterProfileAction action,
    String title,
  ) async {
    switch (action) {
      case _CharacterProfileAction.clone:
        CharacterStorage cloned;
        try {
          cloned = await ref
              .read(characterRegistryManagerProvider.notifier)
              .cloneCharacter(
                characterId,
                name: context.l10n.characterClonedProfileName(name: title),
              );
        } on Object catch (errorValue, stackTrace) {
          error(
            "Failed to clone character $characterId",
            error: errorValue,
            stackTrace: stackTrace,
          );
          if (context.mounted) {
            _showCharacterActionError(
              context,
              context.l10n.characterCloneProfileError(name: title, message: errorValue.toString()),
            );
          }
          return;
        }
        if (!context.mounted) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (context) => CharacterEditPage(characterId: cloned.characterId),
          ),
        );
        return;
      case _CharacterProfileAction.edit:
        _edit(context);
        return;
      case _CharacterProfileAction.delete:
        await _delete(context, ref, title);
        return;
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, String title) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.characterDeleteProfileTitle),
            content: Text(context.l10n.characterDeleteProfileContent(name: title)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(context.l10n.delete),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    try {
      await ref.read(characterRegistryManagerProvider.notifier).deleteCharacter(characterId);
    } on Object catch (errorValue, stackTrace) {
      error("Failed to delete character $characterId", error: errorValue, stackTrace: stackTrace);
      if (!context.mounted) return;
      _showCharacterActionError(
        context,
        context.l10n.characterDeleteProfileError(name: title, message: errorValue.toString()),
      );
    }
  }

  void _edit(BuildContext context) {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (context) => CharacterEditPage(characterId: characterId)),
      ),
    );
  }
}

String characterDisplayName(
  BuildContext context,
  String characterId,
  CharacterMetadata? metadata,
) => switch (characterId) {
  predefinedMaxCharacterId => context.l10n.fitSkillProfileAll5,
  predefinedZeroCharacterId => context.l10n.fitSkillProfileAll0,
  _ => metadata?.name ?? characterId,
};

void _showCharacterActionError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class CharacterEditPage extends ConsumerStatefulWidget {
  const CharacterEditPage({required this.characterId, super.key});

  final String characterId;

  @override
  ConsumerState<CharacterEditPage> createState() => _CharacterEditPageState();
}

class _CharacterEditPageState extends ConsumerState<CharacterEditPage>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 2, vsync: this);
    unawaited(_mountCharacter());
  }

  @override
  void dispose() {
    _disposed = true;
    final characterState = ref.read(characterServiceProvider);
    if (characterState.isInitialized &&
        characterState.character.characterId == widget.characterId) {
      unawaited(ref.read(characterServiceProvider.notifier).unmount());
    }
    _controller.dispose();
    super.dispose();
  }

  Future<void> _mountCharacter() async {
    final characterService = ref.read(characterServiceProvider.notifier);
    await characterService.mount(widget.characterId);
    if (_disposed) {
      await characterService.unmount();
    }
  }

  @override
  Widget build(BuildContext context) {
    final characterState = ref.watch(characterServiceProvider);
    final loadedCharacter = characterState.isInitialized ? characterState.character : null;
    final character = loadedCharacter?.characterId == widget.characterId ? loadedCharacter : null;
    final errorMessage = characterState.status.maybeWhen(
      error: (message) => message,
      orElse: () => null,
    );

    if (character == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.frontPageTitleCharacter)),
        body: Center(
          child: errorMessage == null
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(errorMessage, textAlign: TextAlign.center),
                ),
        ),
      );
    }

    final syncing = characterState.status.maybeWhen(syncing: () => true, orElse: () => false);
    return Scaffold(
      appBar: AppBar(
        title: Text(character.name),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(syncing ? Icons.downloading : Icons.download_done),
          ),
        ],
        bottom: TabBar(
          controller: _controller,
          tabs: [
            Tab(text: context.l10n.itemDetailTabSkills),
            Tab(text: context.l10n.characterProfileInfoTab),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _controller,
          children: [
            CharacterSkillList(skills: character.skills, onTapLevel: _setSkillLevel),
            _CharacterProfileInfoTab(character: character),
          ],
        ),
      ),
    );
  }

  Future<void> _setSkillLevel(int skillTypeId, int level) async {
    final current = ref.read(characterServiceProvider).character;
    final currentLevel = current.skills[skillTypeId] ?? 0;
    final nextLevel = currentLevel == level ? 0 : level;
    final saved = await ref.read(characterServiceProvider.notifier).update((character) {
      final skills = Map<int, int>.from(character.skills);
      if (nextLevel == 0) {
        skills.remove(skillTypeId);
      } else {
        skills[skillTypeId] = nextLevel;
      }
      return character.copyWith(skills: skills);
    });
    if (saved) {
      return;
    }
    if (!mounted) return;
    final message = ref
        .read(characterServiceProvider)
        .status
        .maybeWhen(error: (message) => message, orElse: () => null);
    if (message != null) {
      _showCharacterActionError(context, message);
    }
  }
}

class _CharacterProfileInfoTab extends ConsumerStatefulWidget {
  const _CharacterProfileInfoTab({required this.character});

  final CharacterStorage character;

  @override
  ConsumerState<_CharacterProfileInfoTab> createState() => _CharacterProfileInfoTabState();
}

class _CharacterProfileInfoTabState extends ConsumerState<_CharacterProfileInfoTab> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.character.name);
    _descriptionController = TextEditingController(text: widget.character.description);
  }

  @override
  void didUpdateWidget(covariant _CharacterProfileInfoTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_editing) return;
    if (oldWidget.character.name != widget.character.name) {
      _nameController.text = widget.character.name;
    }
    if (oldWidget.character.description != widget.character.description) {
      _descriptionController.text = widget.character.description;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _formKey,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextFormField(
          controller: _nameController,
          readOnly: !_editing,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(labelText: context.l10n.characterProfileNameLabel),
          validator: (value) => value == null || value.trim().isEmpty
              ? context.l10n.characterProfileNameRequired
              : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          readOnly: !_editing,
          minLines: 4,
          maxLines: 8,
          decoration: InputDecoration(labelText: context.l10n.characterProfileDescriptionLabel),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 16,
          children: _editing
              ? [
                  OutlinedButton(onPressed: _cancel, child: Text(context.l10n.cancel)),
                  FilledButton(onPressed: _save, child: Text(context.l10n.save)),
                ]
              : [
                  FilledButton.icon(
                    onPressed: () => setState(() => _editing = true),
                    icon: const Icon(Icons.edit),
                    label: Text(context.l10n.edit),
                  ),
                ],
        ),
      ],
    ),
  );

  void _cancel() {
    setState(() {
      _editing = false;
      _nameController.text = widget.character.name;
      _descriptionController.text = widget.character.description;
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final saved = await ref
        .read(characterServiceProvider.notifier)
        .update((character) => character.copyWith(name: name, description: description));
    if (!saved) {
      return;
    }
    if (!mounted) return;
    setState(() => _editing = false);
  }
}
