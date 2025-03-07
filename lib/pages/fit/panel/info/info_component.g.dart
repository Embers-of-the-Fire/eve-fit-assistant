// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'info_component.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$getMarketPricesHash() => r'6aca6c6e41399fb25e30497a81bfa0a5acc06c41';

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

/// See also [getMarketPrices].
@ProviderFor(getMarketPrices)
const getMarketPricesProvider = GetMarketPricesFamily();

/// See also [getMarketPrices].
class GetMarketPricesFamily
    extends Family<AsyncValue<(double, Iterable<int>, double, Iterable<int>)>> {
  /// See also [getMarketPrices].
  const GetMarketPricesFamily();

  /// See also [getMarketPrices].
  GetMarketPricesProvider call(
    MapEqual<int, int> types,
  ) {
    return GetMarketPricesProvider(
      types,
    );
  }

  @override
  GetMarketPricesProvider getProviderOverride(
    covariant GetMarketPricesProvider provider,
  ) {
    return call(
      provider.types,
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
  String? get name => r'getMarketPricesProvider';
}

/// See also [getMarketPrices].
class GetMarketPricesProvider extends AutoDisposeFutureProvider<
    (double, Iterable<int>, double, Iterable<int>)> {
  /// See also [getMarketPrices].
  GetMarketPricesProvider(
    MapEqual<int, int> types,
  ) : this._internal(
          (ref) => getMarketPrices(
            ref as GetMarketPricesRef,
            types,
          ),
          from: getMarketPricesProvider,
          name: r'getMarketPricesProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$getMarketPricesHash,
          dependencies: GetMarketPricesFamily._dependencies,
          allTransitiveDependencies:
              GetMarketPricesFamily._allTransitiveDependencies,
          types: types,
        );

  GetMarketPricesProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.types,
  }) : super.internal();

  final MapEqual<int, int> types;

  @override
  Override overrideWith(
    FutureOr<(double, Iterable<int>, double, Iterable<int>)> Function(
            GetMarketPricesRef provider)
        create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GetMarketPricesProvider._internal(
        (ref) => create(ref as GetMarketPricesRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        types: types,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<
      (double, Iterable<int>, double, Iterable<int>)> createElement() {
    return _GetMarketPricesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GetMarketPricesProvider && other.types == types;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, types.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GetMarketPricesRef on AutoDisposeFutureProviderRef<
    (double, Iterable<int>, double, Iterable<int>)> {
  /// The parameter `types` of this provider.
  MapEqual<int, int> get types;
}

class _GetMarketPricesProviderElement extends AutoDisposeFutureProviderElement<
    (double, Iterable<int>, double, Iterable<int>)> with GetMarketPricesRef {
  _GetMarketPricesProviderElement(super.provider);

  @override
  MapEqual<int, int> get types => (origin as GetMarketPricesProvider).types;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
