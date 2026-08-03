import "package:eve_fit_assistant/storage/fs/doc_store.dart";
import "package:eve_fit_assistant/storage/fs/hive_doc_store.dart";
import "package:hive_ce/hive_ce.dart";

var _hiveInitialized = false;

/// Creates a user-data document store for [domain] on web.
///
/// Each domain is a Hive CE box persisted to IndexedDB. Hive needs no home
/// directory in the browser; `init(null)` selects the IndexedDB backend.
DocStore createUserDocStore(UserDataDomain domain) {
  if (!_hiveInitialized) {
    Hive.init(null);
    _hiveInitialized = true;
  }
  return HiveDocStore(domain.boxName);
}
