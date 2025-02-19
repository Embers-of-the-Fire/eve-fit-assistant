part of 'migrate.dart';

/// Migrate from version 1 to version 2.
///
/// 1. Move fit storage to `storage/fit` directory.
/// 2. Initialize character storage.
///    This should be done by the storage manager.
/// 3. Add a `characterID` to all fittings.
///    This should be done when saving a fitting.
///    It is **not** guaranteed that in future versions the character will still be available.
Future<void> migrate1To2() async {
  final storage = await getStorageDir();
  final brief = File('${storage.path}/brief.json');
  if (await brief.exists()) {
    await brief.rename((await getFitBriefFile()).path);
  }
  final full = Directory('${storage.path}/full');
  if (await full.exists()) {
    await full.rename((await getFitFullDir()).path);
  }
  final rec = Directory('${storage.path}/record');
  if (await rec.exists()) {
    await rec.delete(recursive: true);
  }
}
