// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fittings.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$getFittingsHash() => r'15dd3be6e2da58f22f481b89bc4d9eb20e6cdc6b';

/// See also [getFittings].
@ProviderFor(getFittings)
final getFittingsProvider = AutoDisposeFutureProvider<List<Fitting>?>.internal(
  getFittings,
  name: r'getFittingsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$getFittingsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef GetFittingsRef = AutoDisposeFutureProviderRef<List<Fitting>?>;
String _$deleteFittingHash() => r'0e7ef0dbe7b13d3e9dbf39a9240b2f104230e3a1';

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

/// See also [deleteFitting].
@ProviderFor(deleteFitting)
const deleteFittingProvider = DeleteFittingFamily();

/// See also [deleteFitting].
class DeleteFittingFamily extends Family<AsyncValue<void>> {
  /// See also [deleteFitting].
  const DeleteFittingFamily();

  /// See also [deleteFitting].
  DeleteFittingProvider call(
    int fittingID,
  ) {
    return DeleteFittingProvider(
      fittingID,
    );
  }

  @override
  DeleteFittingProvider getProviderOverride(
    covariant DeleteFittingProvider provider,
  ) {
    return call(
      provider.fittingID,
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
  String? get name => r'deleteFittingProvider';
}

/// See also [deleteFitting].
class DeleteFittingProvider extends AutoDisposeFutureProvider<void> {
  /// See also [deleteFitting].
  DeleteFittingProvider(
    int fittingID,
  ) : this._internal(
          (ref) => deleteFitting(
            ref as DeleteFittingRef,
            fittingID,
          ),
          from: deleteFittingProvider,
          name: r'deleteFittingProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$deleteFittingHash,
          dependencies: DeleteFittingFamily._dependencies,
          allTransitiveDependencies:
              DeleteFittingFamily._allTransitiveDependencies,
          fittingID: fittingID,
        );

  DeleteFittingProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.fittingID,
  }) : super.internal();

  final int fittingID;

  @override
  Override overrideWith(
    FutureOr<void> Function(DeleteFittingRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: DeleteFittingProvider._internal(
        (ref) => create(ref as DeleteFittingRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        fittingID: fittingID,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<void> createElement() {
    return _DeleteFittingProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is DeleteFittingProvider && other.fittingID == fittingID;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, fittingID.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin DeleteFittingRef on AutoDisposeFutureProviderRef<void> {
  /// The parameter `fittingID` of this provider.
  int get fittingID;
}

class _DeleteFittingProviderElement
    extends AutoDisposeFutureProviderElement<void> with DeleteFittingRef {
  _DeleteFittingProviderElement(super.provider);

  @override
  int get fittingID => (origin as DeleteFittingProvider).fittingID;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
