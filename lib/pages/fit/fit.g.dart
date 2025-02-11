// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fit.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$fitRecordNotifierHash() => r'f37877c4943ced7c032223de422174343feb3fa0';

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

abstract class _$FitRecordNotifier
    extends BuildlessAutoDisposeNotifier<FitRecordState> {
  late final String id;

  FitRecordState build(
    String id,
  );
}

/// See also [FitRecordNotifier].
@ProviderFor(FitRecordNotifier)
const fitRecordNotifierProvider = FitRecordNotifierFamily();

/// See also [FitRecordNotifier].
class FitRecordNotifierFamily extends Family<FitRecordState> {
  /// See also [FitRecordNotifier].
  const FitRecordNotifierFamily();

  /// See also [FitRecordNotifier].
  FitRecordNotifierProvider call(
    String id,
  ) {
    return FitRecordNotifierProvider(
      id,
    );
  }

  @override
  FitRecordNotifierProvider getProviderOverride(
    covariant FitRecordNotifierProvider provider,
  ) {
    return call(
      provider.id,
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
  String? get name => r'fitRecordNotifierProvider';
}

/// See also [FitRecordNotifier].
class FitRecordNotifierProvider
    extends AutoDisposeNotifierProviderImpl<FitRecordNotifier, FitRecordState> {
  /// See also [FitRecordNotifier].
  FitRecordNotifierProvider(
    String id,
  ) : this._internal(
          () => FitRecordNotifier()..id = id,
          from: fitRecordNotifierProvider,
          name: r'fitRecordNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$fitRecordNotifierHash,
          dependencies: FitRecordNotifierFamily._dependencies,
          allTransitiveDependencies:
              FitRecordNotifierFamily._allTransitiveDependencies,
          id: id,
        );

  FitRecordNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
  }) : super.internal();

  final String id;

  @override
  FitRecordState runNotifierBuild(
    covariant FitRecordNotifier notifier,
  ) {
    return notifier.build(
      id,
    );
  }

  @override
  Override overrideWith(FitRecordNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: FitRecordNotifierProvider._internal(
        () => create()..id = id,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<FitRecordNotifier, FitRecordState>
      createElement() {
    return _FitRecordNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is FitRecordNotifierProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin FitRecordNotifierRef on AutoDisposeNotifierProviderRef<FitRecordState> {
  /// The parameter `id` of this provider.
  String get id;
}

class _FitRecordNotifierProviderElement
    extends AutoDisposeNotifierProviderElement<FitRecordNotifier,
        FitRecordState> with FitRecordNotifierRef {
  _FitRecordNotifierProviderElement(super.provider);

  @override
  String get id => (origin as FitRecordNotifierProvider).id;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
