import "package:eve_fit_assistant/features/manual/repository/manual_repository.dart";
import "package:eve_fit_assistant/native/api/chat.dart" as native_chat;
import "package:flutter_riverpod/flutter_riverpod.dart";

/// The full bundled user manual as a flat list of doc×locale rows, handed to
/// the chat session so the model can use the `search_manual` and
/// `get_manual_doc` tools in any bundled language.
final chatManualCorpusProvider = FutureProvider<List<native_chat.ChatManualDoc>>((Ref ref) async {
  final repository = ref.watch(manualRepositoryProvider);
  final tree = await ref.watch(manualTreeProvider.future);

  final rows = <native_chat.ChatManualDoc>[];
  for (final doc in tree.allDocs) {
    for (final localization in doc.localizations.entries) {
      final body = await repository.loadContent(localization.value.contentFile);
      if (body == null) continue;
      rows.add(
        native_chat.ChatManualDoc(
          id: doc.id,
          locale: localization.key,
          title: localization.value.title,
          summary: localization.value.summary,
          body: body,
        ),
      );
    }
  }
  return rows;
});
