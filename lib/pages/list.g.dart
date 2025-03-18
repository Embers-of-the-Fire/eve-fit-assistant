// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$exportFitToGameHash() => r'f155c2b3b477a248ffef6558ed97e9e523f05b51';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [exportFitToGame].
@ProviderFor(exportFitToGame)
const exportFitToGameProvider = ExportFitToGameFamily();

/// See also [exportFitToGame].
class ExportFitToGameFamily extends Family<AsyncValue<int?>> {
  /// See also [exportFitToGame].
  const ExportFitToGameFamily();

  /// See also [exportFitToGame].
  ExportFitToGameProvider call(
    String fitID,
  ) {
    return ExportFitToGameProvider(
      fitID,
    );
  }

  @override
  ExportFitToGameProvider getProviderOverride(
    covariant ExportFitToGameProvider provider,
  ) {
    return call(
      provider.fitID,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'exportFitToGameProvider';
}

/// See also [exportFitToGame].
class ExportFitToGameProvider extends AutoDisposeFutureProvider<int?> {
  /// See also [exportFitToGame].
  ExportFitToGameProvider(
    String fitID,
  ) : this._internal(
          (ref) => exportFitToGame(
            ref as ExportFitToGameRef,
            fitID,
          ),
          from: exportFitToGameProvider,
          name: r'exportFitToGameProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$exportFitToGameHash,
          dependencies: ExportFitToGameFamily._dependencies,
          allTransitiveDependencies:
              ExportFitToGameFamily._allTransitiveDependencies,
          fitID: fitID,
        );

  ExportFitToGameProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.fitID,
  }) : super.internal();

  final String fitID;

  @override
  Override overrideWith(
    FutureOr<int?> Function(ExportFitToGameRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ExportFitToGameProvider._internal(
        (ref) => create(ref as ExportFitToGameRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        fitID: fitID,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<int?> createElement() {
    return _ExportFitToGameProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ExportFitToGameProvider && other.fitID == fitID;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, fitID.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ExportFitToGameRef on AutoDisposeFutureProviderRef<int?> {
  /// The parameter `fitID` of this provider.
  String get fitID;
}

class _ExportFitToGameProviderElement
    extends AutoDisposeFutureProviderElement<int?> with ExportFitToGameRef {
  _ExportFitToGameProviderElement(super.provider);

  @override
  String get fitID => (origin as ExportFitToGameProvider).fitID;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
