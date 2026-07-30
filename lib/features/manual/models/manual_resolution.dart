import "package:eve_fit_assistant/features/manual/models/manual_entry.dart";
import "package:eve_fit_assistant/utils/fp.dart";

/// Result of resolving a URI path (relative to the manual root) against the
/// manual tree.
sealed class ManualPathResolution {
  const ManualPathResolution();
}

/// The path points at a folder.
final class ManualFolderResolution extends ManualPathResolution {
  const ManualFolderResolution({required this.ancestors, required this.folder});

  /// Folder chain above [folder], from the top level down. Empty for the
  /// root node and for top-level folders.
  final List<ManualFolderEntry> ancestors;
  final ManualFolderEntry folder;
}

/// The path points at a document.
final class ManualDocResolution extends ManualPathResolution {
  const ManualDocResolution({required this.ancestors, required this.doc});

  /// Folder chain containing [doc], from the top level down.
  final List<ManualFolderEntry> ancestors;
  final ManualDocEntry doc;
}

/// The path does not match any node in the manual tree.
final class ManualPathNotFound extends ManualPathResolution {
  const ManualPathNotFound();
}

/// Resolve a `/`-joined manual path (e.g. `fitting/advanced`) against [root].
///
/// An empty path resolves to the root folder. Folder segments must match
/// intermediate folders; the final segment may match either a folder or a
/// document within the current folder.
ManualPathResolution resolveManualPath(ManualFolderEntry root, String path) {
  final segments = path.split("/").where((segment) => segment.isNotEmpty).toList();
  if (segments.isEmpty) {
    return ManualFolderResolution(ancestors: const [], folder: root);
  }

  final ancestors = <ManualFolderEntry>[];
  var current = root;
  for (var i = 0; i < segments.length; i++) {
    final id = segments.sublist(0, i + 1).join("/");
    final childFolder = current.folders.firstWhereOrNull((folder) => folder.id == id);
    if (childFolder != null) {
      if (i == segments.length - 1) {
        return ManualFolderResolution(ancestors: List.unmodifiable(ancestors), folder: childFolder);
      }
      ancestors.add(childFolder);
      current = childFolder;
      continue;
    }
    if (i == segments.length - 1) {
      final doc = current.docs.firstWhereOrNull((doc) => doc.id == id);
      if (doc != null) {
        return ManualDocResolution(ancestors: List.unmodifiable(ancestors), doc: doc);
      }
    }
    return const ManualPathNotFound();
  }
  return const ManualPathNotFound();
}
