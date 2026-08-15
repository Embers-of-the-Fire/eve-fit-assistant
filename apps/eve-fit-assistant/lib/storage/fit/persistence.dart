import "dart:convert";

import "package:archive/archive.dart";
import "package:eve_fit_assistant/storage/fit/migrations.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:flutter/foundation.dart";

const currentFitStorageVersion = 2;
const currentFitRegistryVersion = 2;
const currentNativeFitPayloadVersion = 2;
const legacyNativeFitPayloadVersion = 1;

enum FitPersistencePayloadKind { fitStorage, fitRegistry, nativeText }

enum FitPersistenceErrorCode { invalidPayloadShape, unsupportedVersion }

class FitPersistenceException implements Exception {
  const FitPersistenceException({
    required this.kind,
    required this.code,
    required this.message,
    this.version,
  });

  final FitPersistencePayloadKind kind;
  final FitPersistenceErrorCode code;
  final String message;
  final int? version;

  @override
  String toString() =>
      "FitPersistenceException(kind: $kind, code: $code, version: $version, message: $message)";
}

class DecodedFitStorage {
  const DecodedFitStorage({required this.fit, required this.didMigrate});

  final FitStorage fit;
  final bool didMigrate;
}

class DecodedFitRegistry {
  const DecodedFitRegistry({required this.registry, required this.didMigrate});

  final FitRegistry registry;
  final bool didMigrate;
}

Map<String, dynamic> encodeFitStorage(FitStorage fit) => <String, dynamic>{
  "version": currentFitStorageVersion,
  "fit": fit.toJson(),
};

DecodedFitStorage decodeFitStorage(Map<String, dynamic> json) {
  final version = _readVersion(json, kind: FitPersistencePayloadKind.fitStorage);
  if (version == null) {
    return DecodedFitStorage(fit: FitStorage.fromJson(json), didMigrate: true);
  }

  switch (version) {
    case 1:
      return DecodedFitStorage(
        fit: FitStorage.fromJson(
          _readPayloadMap(json, "fit", kind: FitPersistencePayloadKind.fitStorage),
        ),
        didMigrate: true,
      );
    case 2:
      return DecodedFitStorage(
        fit: FitStorage.fromJson(
          _readPayloadMap(json, "fit", kind: FitPersistencePayloadKind.fitStorage),
        ),
        didMigrate: false,
      );
    case 3:
      return DecodedFitStorage(
        fit: FitStorage.fromJson(
          _readPayloadMap(json, "fit", kind: FitPersistencePayloadKind.fitStorage),
        ),
        didMigrate: true,
      );
  }

  throw FitPersistenceException(
    kind: FitPersistencePayloadKind.fitStorage,
    code: FitPersistenceErrorCode.unsupportedVersion,
    message: "Unsupported fit storage version: $version",
    version: version,
  );
}

Map<String, dynamic> encodeFitRegistry(FitRegistry registry) => <String, dynamic>{
  "version": currentFitRegistryVersion,
  "registry": registry.toJson(),
};

DecodedFitRegistry decodeFitRegistry(Map<String, dynamic> json) {
  final version = _readVersion(json, kind: FitPersistencePayloadKind.fitRegistry);
  if (version == null) {
    return DecodedFitRegistry(registry: FitRegistry.fromJson(json), didMigrate: true);
  }

  switch (version) {
    case 1:
      return DecodedFitRegistry(
        registry: FitRegistry.fromJson(
          _readPayloadMap(json, "registry", kind: FitPersistencePayloadKind.fitRegistry),
        ),
        didMigrate: true,
      );
    case currentFitRegistryVersion:
      return DecodedFitRegistry(
        registry: FitRegistry.fromJson(
          _readPayloadMap(json, "registry", kind: FitPersistencePayloadKind.fitRegistry),
        ),
        didMigrate: false,
      );
  }

  throw FitPersistenceException(
    kind: FitPersistencePayloadKind.fitRegistry,
    code: FitPersistenceErrorCode.unsupportedVersion,
    message: "Unsupported fit registry version: $version",
    version: version,
  );
}

Map<String, dynamic> encodeNativeFitPayload(FitStorage fit) => <String, dynamic>{
  "version": currentNativeFitPayloadVersion,
  "fit": encodeFitStorage(fit),
};

Uint8List encodeNativeFitBinary(FitStorage fit) {
  final payload = jsonEncode(encodeNativeFitPayload(fit));
  return Uint8List.fromList(const GZipEncoder().encodeBytes(utf8.encode(payload), level: 9));
}

DecodedFitStorage decodeNativeFitPayload(Map<String, dynamic> json) {
  final version = _readVersion(json, kind: FitPersistencePayloadKind.nativeText);
  if (version == null) {
    throw const FitPersistenceException(
      kind: FitPersistencePayloadKind.nativeText,
      code: FitPersistenceErrorCode.invalidPayloadShape,
      message: "Native fit payload is missing a version.",
    );
  }

  switch (version) {
    case legacyNativeFitPayloadVersion:
      return DecodedFitStorage(
        fit: FitStorage.fromJson(
          upgradeLegacyFitStorageJson(
            _readPayloadMap(json, "fit", kind: FitPersistencePayloadKind.nativeText),
          ),
        ),
        didMigrate: true,
      );
    case currentNativeFitPayloadVersion:
      return decodeFitStorage(
        _readPayloadMap(json, "fit", kind: FitPersistencePayloadKind.nativeText),
      );
  }

  throw FitPersistenceException(
    kind: FitPersistencePayloadKind.nativeText,
    code: FitPersistenceErrorCode.unsupportedVersion,
    message: "Unsupported native fit payload version: $version",
    version: version,
  );
}

int? _readVersion(Map<String, dynamic> json, {required FitPersistencePayloadKind kind}) {
  final version = json["version"];
  if (version == null) {
    return null;
  }
  if (version is int) {
    return version;
  }
  throw FitPersistenceException(
    kind: kind,
    code: FitPersistenceErrorCode.invalidPayloadShape,
    message: "Persisted version must be an integer.",
  );
}

Map<String, dynamic> _readPayloadMap(
  Map<String, dynamic> json,
  String key, {
  required FitPersistencePayloadKind kind,
}) {
  final payload = json[key];
  if (payload is Map<String, dynamic>) {
    return payload;
  }
  throw FitPersistenceException(
    kind: kind,
    code: FitPersistenceErrorCode.invalidPayloadShape,
    message: "Persisted payload is missing '$key'.",
  );
}
