import "package:efa_proto/manual.pb.dart" as pb;
import "package:eve_fit_assistant/features/manual/models/manual_entry.dart";
import "package:flutter/foundation.dart" show FlutterError;
import "package:flutter/services.dart" show rootBundle;
import "package:flutter_riverpod/flutter_riverpod.dart";

const String _registryAssetPath = "assets/content/manual/generated/manual.pb";
const String _contentAssetRoot = "assets/content/manual/generated/content";

final manualRepositoryProvider = Provider<ManualRepository>((Ref ref) => ManualRepository());

/// Loads the bundled user-manual registry and its localized Markdown bodies
/// from Flutter assets.
class ManualRepository {
  /// Load and decode the bundled registry into the manual tree.
  ///
  /// Throws if the asset is missing or undecodable, surfacing the failure
  /// through [manualTreeProvider] as an error state.
  Future<ManualFolderEntry> loadRegistry() async {
    final data = await rootBundle.load(_registryAssetPath);
    final registry = pb.ManualRegistry.fromBuffer(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    return convertRegistry(registry);
  }

  /// Load a localized Markdown body by its content file name
  /// (see [ManualDocLocalization.contentFile]). Returns `null` only when the
  /// asset is genuinely missing; unexpected I/O or decode failures propagate
  /// to [manualContentProvider] as errors.
  Future<String?> loadContent(String contentFile) async {
    try {
      return await rootBundle.loadString("$_contentAssetRoot/$contentFile");
    } on FlutterError {
      return null;
    }
  }

  /// Convert a decoded [pb.ManualRegistry] into the manual tree model.
  static ManualFolderEntry convertRegistry(pb.ManualRegistry registry) => ManualFolderEntry(
    id: "",
    order: 0,
    names: const {},
    descriptions: const {},
    folders: registry.folders.map(_convertFolder).toList(growable: false),
    docs: const [],
  );

  static ManualFolderEntry _convertFolder(pb.ManualFolder folder) => ManualFolderEntry(
    id: folder.id,
    order: folder.order,
    names: Map<String, String>.unmodifiable(folder.name),
    descriptions: Map<String, String>.unmodifiable(folder.description),
    folders: folder.folders.map(_convertFolder).toList(growable: false),
    docs: folder.docs.map(_convertDoc).toList(growable: false),
  );

  static ManualDocEntry _convertDoc(pb.ManualDoc doc) => ManualDocEntry(
    id: doc.id,
    order: doc.order,
    localizations: Map<String, ManualDocLocalization>.unmodifiable(
      doc.localizations.map(
        (String locale, pb.ManualDocLocalization loc) => MapEntry(
          locale,
          ManualDocLocalization(
            title: loc.title,
            summary: loc.summary,
            contentFile: loc.contentFile,
          ),
        ),
      ),
    ),
  );
}

/// The bundled manual tree (root folder node).
final manualTreeProvider = FutureProvider<ManualFolderEntry>(
  (Ref ref) => ref.watch(manualRepositoryProvider).loadRegistry(),
);

/// Localized Markdown body for a given content file name.
final manualContentProvider = FutureProvider.family<String?, String>(
  (Ref ref, String contentFile) => ref.watch(manualRepositoryProvider).loadContent(contentFile),
);
