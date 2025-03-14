// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'info_component.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$getMarketPricesHash() => r'ff158335399bf52f83e0095c57a6a3408e277b5f';

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
  Iterable<ProviderOrFamily>? get allTransitiveDependencies => _allTransitiveDependencies;

  @override
  String? get name => r'getMarketPricesProvider';
}

/// See also [getMarketPrices].
class GetMarketPricesProvider
    extends AutoDisposeFutureProvider<(double, Iterable<int>, double, Iterable<int>)> {
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
              const bool.fromEnvironment('dart.vm.product') ? null : _$getMarketPricesHash,
          dependencies: GetMarketPricesFamily._dependencies,
          allTransitiveDependencies: GetMarketPricesFamily._allTransitiveDependencies,
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
    FutureOr<(double, Iterable<int>, double, Iterable<int>)> Function(GetMarketPricesRef provider)
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
  AutoDisposeFutureProviderElement<(double, Iterable<int>, double, Iterable<int>)> createElement() {
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
mixin GetMarketPricesRef
    on AutoDisposeFutureProviderRef<(double, Iterable<int>, double, Iterable<int>)> {
  /// The parameter `types` of this provider.
  MapEqual<int, int> get types;
}

class _GetMarketPricesProviderElement
    extends AutoDisposeFutureProviderElement<(double, Iterable<int>, double, Iterable<int>)>
    with GetMarketPricesRef {
  _GetMarketPricesProviderElement(super.provider);

  @override
  MapEqual<int, int> get types => (origin as GetMarketPricesProvider).types;
}

String _$getMarketPriceHash() => r'66a011a76e23a64fa7158ebad1b72ce4f5917528';

/// See also [getMarketPrice].
@ProviderFor(getMarketPrice)
const getMarketPriceProvider = GetMarketPriceFamily();

/// See also [getMarketPrice].
class GetMarketPriceFamily extends Family<AsyncValue<MarketPriceGroup>> {
  /// See also [getMarketPrice].
  const GetMarketPriceFamily();

  /// See also [getMarketPrice].
  GetMarketPriceProvider call(
    int typeID,
  ) {
    return GetMarketPriceProvider(
      typeID,
    );
  }

  @override
  GetMarketPriceProvider getProviderOverride(
    covariant GetMarketPriceProvider provider,
  ) {
    return call(
      provider.typeID,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies => _allTransitiveDependencies;

  @override
  String? get name => r'getMarketPriceProvider';
}

/// See also [getMarketPrice].
class GetMarketPriceProvider extends AutoDisposeFutureProvider<MarketPriceGroup> {
  /// See also [getMarketPrice].
  GetMarketPriceProvider(
    int typeID,
  ) : this._internal(
          (ref) => getMarketPrice(
            ref as GetMarketPriceRef,
            typeID,
          ),
          from: getMarketPriceProvider,
          name: r'getMarketPriceProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product') ? null : _$getMarketPriceHash,
          dependencies: GetMarketPriceFamily._dependencies,
          allTransitiveDependencies: GetMarketPriceFamily._allTransitiveDependencies,
          typeID: typeID,
        );

  GetMarketPriceProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.typeID,
  }) : super.internal();

  final int typeID;

  @override
  Override overrideWith(
    FutureOr<MarketPriceGroup> Function(GetMarketPriceRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GetMarketPriceProvider._internal(
        (ref) => create(ref as GetMarketPriceRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        typeID: typeID,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<MarketPriceGroup> createElement() {
    return _GetMarketPriceProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GetMarketPriceProvider && other.typeID == typeID;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, typeID.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GetMarketPriceRef on AutoDisposeFutureProviderRef<MarketPriceGroup> {
  /// The parameter `typeID` of this provider.
  int get typeID;
}

class _GetMarketPriceProviderElement extends AutoDisposeFutureProviderElement<MarketPriceGroup>
    with GetMarketPriceRef {
  _GetMarketPriceProviderElement(super.provider);

  @override
  int get typeID => (origin as GetMarketPriceProvider).typeID;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
