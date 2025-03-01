// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'market_list.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$getMarketPriceHash() => r'e9f1280fec783563a7c54d49efeda016d313a7d9';

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
    int timestamp,
  ) {
    return GetMarketPriceProvider(
      typeID,
      timestamp,
    );
  }

  @override
  GetMarketPriceProvider getProviderOverride(
    covariant GetMarketPriceProvider provider,
  ) {
    return call(
      provider.typeID,
      provider.timestamp,
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
  String? get name => r'getMarketPriceProvider';
}

/// See also [getMarketPrice].
class GetMarketPriceProvider
    extends AutoDisposeFutureProvider<MarketPriceGroup> {
  /// See also [getMarketPrice].
  GetMarketPriceProvider(
    int typeID,
    int timestamp,
  ) : this._internal(
          (ref) => getMarketPrice(
            ref as GetMarketPriceRef,
            typeID,
            timestamp,
          ),
          from: getMarketPriceProvider,
          name: r'getMarketPriceProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$getMarketPriceHash,
          dependencies: GetMarketPriceFamily._dependencies,
          allTransitiveDependencies:
              GetMarketPriceFamily._allTransitiveDependencies,
          typeID: typeID,
          timestamp: timestamp,
        );

  GetMarketPriceProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.typeID,
    required this.timestamp,
  }) : super.internal();

  final int typeID;
  final int timestamp;

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
        timestamp: timestamp,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<MarketPriceGroup> createElement() {
    return _GetMarketPriceProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GetMarketPriceProvider &&
        other.typeID == typeID &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, typeID.hashCode);
    hash = _SystemHash.combine(hash, timestamp.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GetMarketPriceRef on AutoDisposeFutureProviderRef<MarketPriceGroup> {
  /// The parameter `typeID` of this provider.
  int get typeID;

  /// The parameter `timestamp` of this provider.
  int get timestamp;
}

class _GetMarketPriceProviderElement
    extends AutoDisposeFutureProviderElement<MarketPriceGroup>
    with GetMarketPriceRef {
  _GetMarketPriceProviderElement(super.provider);

  @override
  int get typeID => (origin as GetMarketPriceProvider).typeID;
  @override
  int get timestamp => (origin as GetMarketPriceProvider).timestamp;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
