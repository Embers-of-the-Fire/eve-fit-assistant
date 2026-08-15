/// Platform factory for user-data `DocStore`s.
///
/// On native platforms this exports `user_store_io.dart` (file-backed stores
/// rooted at the `PathProvider` domain directories). On web it exports
/// `user_store_web.dart` (Hive CE boxes backed by IndexedDB).
library;

export "user_store_io.dart" if (dart.library.js_interop) "user_store_web.dart";
