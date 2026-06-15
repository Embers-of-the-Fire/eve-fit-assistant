import "package:eve_fit_assistant/storage/repo/models/shared.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:freezed_annotation/freezed_annotation.dart";

part "remote_catalog.freezed.dart";
part "remote_catalog.g.dart";

@freezed
abstract class ManifestIndex with _$ManifestIndex {
  const factory ManifestIndex({required int manifestVersion, required String activatedGeneration}) =
      _ManifestIndex;

  factory ManifestIndex.fromJson(Map<String, dynamic> json) => _$ManifestIndexFromJson(json);
}

@freezed
abstract class GenerationsIndex with _$GenerationsIndex {
  const factory GenerationsIndex({
    @Default(IMap<String, GenerationEntry>.empty()) IMap<String, GenerationEntry> generations,
  }) = _GenerationsIndex;

  factory GenerationsIndex.fromJson(Map<String, dynamic> json) => _$GenerationsIndexFromJson(json);
}

@freezed
abstract class GenerationEntry with _$GenerationEntry {
  const factory GenerationEntry({
    required String id,
    required String createdAt,
    required String description,
  }) = _GenerationEntry;

  factory GenerationEntry.fromJson(Map<String, dynamic> json) => _$GenerationEntryFromJson(json);
}

@freezed
abstract class GenerationCatalog with _$GenerationCatalog {
  const factory GenerationCatalog({
    required int catalogVersion,
    required String createdAt,
    required String description,
  }) = _GenerationCatalog;

  factory GenerationCatalog.fromJson(Map<String, dynamic> json) =>
      _$GenerationCatalogFromJson(json);
}

@freezed
abstract class GenerationResources with _$GenerationResources {
  const factory GenerationResources({
    required int resourcesVersion,
    @Default(IMap<String, GenerationServerEntry>.empty())
    IMap<String, GenerationServerEntry> servers,
  }) = _GenerationResources;

  factory GenerationResources.fromJson(Map<String, dynamic> json) =>
      _$GenerationResourcesFromJson(json);
}

@freezed
abstract class GenerationServerEntry with _$GenerationServerEntry {
  const factory GenerationServerEntry({
    required String lastUpdatedAt,
    @Default(IMap<String, String>.empty()) IMap<String, String> name,
  }) = _GenerationServerEntry;

  factory GenerationServerEntry.fromJson(Map<String, dynamic> json) =>
      _$GenerationServerEntryFromJson(json);
}

@freezed
abstract class GenerationServer with _$GenerationServer {
  const factory GenerationServer({
    required String id,
    required String lastUpdatedAt,
    required GameMetadata metadata,
    @Default(IMap<String, String>.empty()) IMap<String, String> name,
    @Default(IList<GenerationCheckoutEntry>.empty()) IList<GenerationCheckoutEntry> checkouts,
  }) = _GenerationServer;

  factory GenerationServer.fromJson(Map<String, dynamic> json) => _$GenerationServerFromJson(json);
}

@freezed
abstract class GenerationCheckoutEntry with _$GenerationCheckoutEntry {
  const factory GenerationCheckoutEntry({
    required String id,
    required String createdAt,
    required GameMetadata metadata,
  }) = _GenerationCheckoutEntry;

  factory GenerationCheckoutEntry.fromJson(Map<String, dynamic> json) =>
      _$GenerationCheckoutEntryFromJson(json);
}

@freezed
abstract class GenerationCheckoutCatalog with _$GenerationCheckoutCatalog {
  const factory GenerationCheckoutCatalog({
    required String id,
    required String createdAt,
    required String serverId,
    required GameMetadata metadata,
    @Default(IMap<String, AssetFile>.empty()) IMap<String, AssetFile> files,
  }) = _GenerationCheckoutCatalog;

  factory GenerationCheckoutCatalog.fromJson(Map<String, dynamic> json) =>
      _$GenerationCheckoutCatalogFromJson(json);
}

@freezed
abstract class AnnouncementCatalog with _$AnnouncementCatalog {
  const factory AnnouncementCatalog({
    required int announcementsVersion,
    @Default(IMap<String, AnnouncementCatalogEntry>.empty())
    IMap<String, AnnouncementCatalogEntry> announcements,
  }) = _AnnouncementCatalog;

  factory AnnouncementCatalog.fromJson(Map<String, dynamic> json) =>
      _$AnnouncementCatalogFromJson(json);
}

@freezed
abstract class AnnouncementCatalogEntry with _$AnnouncementCatalogEntry {
  const factory AnnouncementCatalogEntry({
    required String id,
    required String firstPublishedAt,
    required String updatedAt,
    required String contentHash,
    VersionRange? versionRange,
    @Default(false) bool isVersionUpdate,
  }) = _AnnouncementCatalogEntry;

  factory AnnouncementCatalogEntry.fromJson(Map<String, dynamic> json) =>
      _$AnnouncementCatalogEntryFromJson(json);
}

@freezed
abstract class ReleaseCatalog with _$ReleaseCatalog {
  const factory ReleaseCatalog({
    required int releasesVersion,
    @Default(IMap<String, ReleaseCatalogEntry>.empty()) IMap<String, ReleaseCatalogEntry> releases,
  }) = _ReleaseCatalog;

  factory ReleaseCatalog.fromJson(Map<String, dynamic> json) => _$ReleaseCatalogFromJson(json);
}

@freezed
abstract class ReleaseCatalogEntry with _$ReleaseCatalogEntry {
  const factory ReleaseCatalogEntry({
    required String id,
    required String createdAt,
    required String version,
    @Default(IList<String>.empty()) IList<String> offering,
  }) = _ReleaseCatalogEntry;

  factory ReleaseCatalogEntry.fromJson(Map<String, dynamic> json) =>
      _$ReleaseCatalogEntryFromJson(json);
}
