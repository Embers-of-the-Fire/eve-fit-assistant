// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'content.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$markdownContentHash() => r'1a81bc272ba02b96a8c74edc4688c5a0d1f82996';

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

/// See also [markdownContent].
@ProviderFor(markdownContent)
const markdownContentProvider = MarkdownContentFamily();

/// See also [markdownContent].
class MarkdownContentFamily extends Family<AsyncValue<String>> {
  /// See also [markdownContent].
  const MarkdownContentFamily();

  /// See also [markdownContent].
  MarkdownContentProvider call(
    String contentKey,
  ) {
    return MarkdownContentProvider(
      contentKey,
    );
  }

  @override
  MarkdownContentProvider getProviderOverride(
    covariant MarkdownContentProvider provider,
  ) {
    return call(
      provider.contentKey,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies => _allTransitiveDependencies;

  @override
  String? get name => r'markdownContentProvider';
}

/// See also [markdownContent].
class MarkdownContentProvider extends AutoDisposeFutureProvider<String> {
  /// See also [markdownContent].
  MarkdownContentProvider(
    String contentKey,
  ) : this._internal(
          (ref) => markdownContent(
            ref as MarkdownContentRef,
            contentKey,
          ),
          from: markdownContentProvider,
          name: r'markdownContentProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product') ? null : _$markdownContentHash,
          dependencies: MarkdownContentFamily._dependencies,
          allTransitiveDependencies: MarkdownContentFamily._allTransitiveDependencies,
          contentKey: contentKey,
        );

  MarkdownContentProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.contentKey,
  }) : super.internal();

  final String contentKey;

  @override
  Override overrideWith(
    FutureOr<String> Function(MarkdownContentRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: MarkdownContentProvider._internal(
        (ref) => create(ref as MarkdownContentRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        contentKey: contentKey,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<String> createElement() {
    return _MarkdownContentProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MarkdownContentProvider && other.contentKey == contentKey;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, contentKey.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin MarkdownContentRef on AutoDisposeFutureProviderRef<String> {
  /// The parameter `contentKey` of this provider.
  String get contentKey;
}

class _MarkdownContentProviderElement extends AutoDisposeFutureProviderElement<String>
    with MarkdownContentRef {
  _MarkdownContentProviderElement(super.provider);

  @override
  String get contentKey => (origin as MarkdownContentProvider).contentKey;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
