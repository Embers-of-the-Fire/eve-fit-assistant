// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'char_edit.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$characterNotifierHash() => r'c2231b72ba53142a82880b006fe591fc2e5a6103';

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

abstract class _$CharacterNotifier
    extends BuildlessAutoDisposeNotifier<CharacterState> {
  late final String id;

  CharacterState build(
    String id,
  );
}

/// See also [CharacterNotifier].
@ProviderFor(CharacterNotifier)
const characterNotifierProvider = CharacterNotifierFamily();

/// See also [CharacterNotifier].
class CharacterNotifierFamily extends Family<CharacterState> {
  /// See also [CharacterNotifier].
  const CharacterNotifierFamily();

  /// See also [CharacterNotifier].
  CharacterNotifierProvider call(
    String id,
  ) {
    return CharacterNotifierProvider(
      id,
    );
  }

  @override
  CharacterNotifierProvider getProviderOverride(
    covariant CharacterNotifierProvider provider,
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
  String? get name => r'characterNotifierProvider';
}

/// See also [CharacterNotifier].
class CharacterNotifierProvider
    extends AutoDisposeNotifierProviderImpl<CharacterNotifier, CharacterState> {
  /// See also [CharacterNotifier].
  CharacterNotifierProvider(
    String id,
  ) : this._internal(
          () => CharacterNotifier()..id = id,
          from: characterNotifierProvider,
          name: r'characterNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$characterNotifierHash,
          dependencies: CharacterNotifierFamily._dependencies,
          allTransitiveDependencies:
              CharacterNotifierFamily._allTransitiveDependencies,
          id: id,
        );

  CharacterNotifierProvider._internal(
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
  CharacterState runNotifierBuild(
    covariant CharacterNotifier notifier,
  ) {
    return notifier.build(
      id,
    );
  }

  @override
  Override overrideWith(CharacterNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: CharacterNotifierProvider._internal(
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
  AutoDisposeNotifierProviderElement<CharacterNotifier, CharacterState>
      createElement() {
    return _CharacterNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CharacterNotifierProvider && other.id == id;
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
mixin CharacterNotifierRef on AutoDisposeNotifierProviderRef<CharacterState> {
  /// The parameter `id` of this provider.
  String get id;
}

class _CharacterNotifierProviderElement
    extends AutoDisposeNotifierProviderElement<CharacterNotifier,
        CharacterState> with CharacterNotifierRef {
  _CharacterNotifierProviderElement(super.provider);

  @override
  String get id => (origin as CharacterNotifierProvider).id;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
