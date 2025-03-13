// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$getCharacterHash() => r'29d8a30fe48f0b73de89b9e16dddc41f69a9d664';

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

/// See also [getCharacter].
@ProviderFor(getCharacter)
const getCharacterProvider = GetCharacterFamily();

/// See also [getCharacter].
class GetCharacterFamily extends Family<AsyncValue<Character?>> {
  /// See also [getCharacter].
  const GetCharacterFamily();

  /// See also [getCharacter].
  GetCharacterProvider call(
    int timestamp,
  ) {
    return GetCharacterProvider(
      timestamp,
    );
  }

  @override
  GetCharacterProvider getProviderOverride(
    covariant GetCharacterProvider provider,
  ) {
    return call(
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
  String? get name => r'getCharacterProvider';
}

/// See also [getCharacter].
class GetCharacterProvider extends AutoDisposeFutureProvider<Character?> {
  /// See also [getCharacter].
  GetCharacterProvider(
    int timestamp,
  ) : this._internal(
          (ref) => getCharacter(
            ref as GetCharacterRef,
            timestamp,
          ),
          from: getCharacterProvider,
          name: r'getCharacterProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$getCharacterHash,
          dependencies: GetCharacterFamily._dependencies,
          allTransitiveDependencies:
              GetCharacterFamily._allTransitiveDependencies,
          timestamp: timestamp,
        );

  GetCharacterProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.timestamp,
  }) : super.internal();

  final int timestamp;

  @override
  Override overrideWith(
    FutureOr<Character?> Function(GetCharacterRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GetCharacterProvider._internal(
        (ref) => create(ref as GetCharacterRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        timestamp: timestamp,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<Character?> createElement() {
    return _GetCharacterProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GetCharacterProvider && other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, timestamp.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GetCharacterRef on AutoDisposeFutureProviderRef<Character?> {
  /// The parameter `timestamp` of this provider.
  int get timestamp;
}

class _GetCharacterProviderElement
    extends AutoDisposeFutureProviderElement<Character?> with GetCharacterRef {
  _GetCharacterProviderElement(super.provider);

  @override
  int get timestamp => (origin as GetCharacterProvider).timestamp;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
