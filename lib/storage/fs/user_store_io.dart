import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/storage/fs/doc_store.dart";
import "package:eve_fit_assistant/storage/fs/file_doc_store.dart";

/// Creates a user-data document store for [domain] on native platforms.
///
/// Stores are file-backed and rooted at the existing `PathProvider` domain
/// directories, preserving the historical on-disk layout.
DocStore createUserDocStore(UserDataDomain domain) => FileDocStore(switch (domain) {
  UserDataDomain.fittings => PathProvider.fittingsPath,
  UserDataDomain.characters => PathProvider.charactersPath,
  UserDataDomain.settings => PathProvider.settingsPath,
});
