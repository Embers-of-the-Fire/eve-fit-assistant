import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:efa_proto/types.pb.dart" as pb_types;
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/components/list/eve_list_tile.dart";
import "package:eve_fit_assistant/components/list/eve_select_list.dart";
import "package:eve_fit_assistant/components/list/meta_filter_bar.dart";
import "package:eve_fit_assistant/components/list/search/type_search_field.dart";
import "package:eve_fit_assistant/components/list/search/type_searcher.dart";
import "package:eve_fit_assistant/components/skeleton.dart";
import "package:eve_fit_assistant/constant/assets.dart";
import "package:eve_fit_assistant/pages/item-detail/page.dart";
import "package:eve_fit_assistant/storage/repo/collection.dart";
import "package:eve_fit_assistant/storage/repo/data_readiness.dart";
import "package:eve_fit_assistant/storage/repo/localization_db.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:eve_fit_assistant/utils/type_sort.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

/// The item database: a full EVE type list with browsing, search, filtering
/// and sorting. Browses the category tree by default; an active search query
/// or an explicit sort key switches to a flat result list. Tapping a type
/// opens the standard item detail page.
@RoutePage()
class TypeDatabasePage extends ConsumerStatefulWidget {
  const TypeDatabasePage({super.key});

  @override
  ConsumerState<TypeDatabasePage> createState() => _TypeDatabasePageState();
}

class _TypeDatabasePageState extends ConsumerState<TypeDatabasePage> {
  /// Active search hits; `null` while the search field is empty.
  List<int>? _searchHits;

  MetaFilter _metaFilter = const MetaFilter.all();

  /// Category filter; `null` shows all categories (browse mode lands on the
  /// category list, flat mode applies no category restriction).
  int? _categoryId;

  /// Explicit sort key; `null` keeps the default order (category tree when
  /// browsing, search relevance when searching).
  TypeSortKey? _sortKey;
  TypeSortDirection _direction = TypeSortDirection.ascending;

  /// Resolved localized names for the current name-sorted list, keyed by
  /// type id; `null` while resolution is pending.
  Map<int, String>? _sortNames;
  int _nameResolutionGeneration = 0;

  bool get _isFlatMode => _searchHits != null || _sortKey != null;

  List<pb_types.Type> _filteredTypes(RepoCollectionService collection) {
    final Iterable<pb_types.Type> base = _searchHits == null
        ? collection.getAllTypes()
        : _searchHits!.map(collection.getType).nonNulls;
    return base.where((type) {
      if (_categoryId != null && collection.getGroup(type.groupId)?.categoryId != _categoryId) {
        return false;
      }
      return _metaFilter.passes(type);
    }).toList();
  }

  List<pb_types.Type> _sortedTypes(RepoCollectionService collection) {
    final types = _filteredTypes(collection);
    final key = _sortKey;
    if (key == null) return types;
    types.sort(
      typeComparator(
        key,
        _direction,
        names: _sortNames ?? const {},
        categoryOfGroup: (groupId) => collection.getGroup(groupId)?.categoryId,
      ),
    );
    return types;
  }

  Future<LocalizationDbService?> _tryOpenLocalizationDb() async {
    try {
      return await ref.read(localizationDbServiceProvider.future);
    } on Object {
      return null;
    }
  }

  /// Resolves localized names for the current filtered list so it can be
  /// sorted by name. No-op unless the name sort is active.
  Future<void> _resolveSortNames() async {
    if (_sortKey != TypeSortKey.name || _sortNames != null) return;
    final generation = ++_nameResolutionGeneration;
    final collection = ref.read(repoCollectionProvider);
    if (collection == null) return;
    final types = _filteredTypes(collection);
    final db = await _tryOpenLocalizationDb();
    if (!mounted || generation != _nameResolutionGeneration) return;
    if (db == null) {
      // Without the localization database names cannot be resolved; fall
      // back to the type-id tiebreak order instead of loading forever.
      setState(() => _sortNames = const {});
      return;
    }
    final nameIdToTypeId = {for (final type in types) type.typeName.id: type.typeId};
    final names = await db.localizedNames(nameIdToTypeId.keys, ref.read(localeProvider).name);
    if (!mounted || generation != _nameResolutionGeneration) return;
    setState(() {
      _sortNames = {for (final entry in nameIdToTypeId.entries) entry.value: ?names[entry.key]};
    });
  }

  /// Marks the resolved-name cache stale after any input to the filtered
  /// list changed, then kicks off re-resolution when name sort is active.
  void _invalidateSortNames() {
    _sortNames = null;
    unawaited(_resolveSortNames());
  }

  void _onSearchResults(List<int>? hits) => setState(() {
    _searchHits = hits;
    _invalidateSortNames();
  });

  void _onMetaFilterChanged(MetaFilter filter) => setState(() {
    _metaFilter = filter;
    _invalidateSortNames();
  });

  void _onCategoryChanged(int? categoryId) => setState(() {
    _categoryId = categoryId;
    _invalidateSortNames();
  });

  void _onSortKeySelected(TypeSortKey? key) => setState(() {
    _sortKey = key;
    _invalidateSortNames();
  });

  String _sortKeyLabel(BuildContext context, TypeSortKey? key) => switch (key) {
    null => context.l10n.typeDatabaseSortDefault,
    TypeSortKey.name => context.l10n.typeDatabaseSortName,
    TypeSortKey.typeId => context.l10n.typeDatabaseSortTypeId,
    TypeSortKey.metaLevel => context.l10n.typeDatabaseSortMetaLevel,
    TypeSortKey.group => context.l10n.typeDatabaseSortGroup,
    TypeSortKey.category => context.l10n.typeDatabaseSortCategory,
  };

  Widget _menuCheckIcon(bool checked) =>
      checked ? const Icon(Icons.check, size: 18) : const SizedBox(width: 18);

  Widget _menuAnchorButton({
    required MenuController controller,
    required IconData icon,
    required Widget label,
  }) => TextButton(
    style: TextButton.styleFrom(
      padding: const .symmetric(horizontal: 8),
      visualDensity: VisualDensity.compact,
    ),
    onPressed: () => controller.isOpen ? controller.close() : controller.open(),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 4),
        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 200), child: label),
        const Icon(Icons.arrow_drop_down, size: 18),
      ],
    ),
  );

  Widget _buildCategorySelector(BuildContext context, RepoCollectionService collection) {
    final categories = collection.getAllCategories().toList()
      ..sort((a, b) => a.categoryId.compareTo(b.categoryId));
    return MenuAnchor(
      builder: (context, controller, _) => _menuAnchorButton(
        controller: controller,
        icon: Icons.category_outlined,
        label: _categoryId == null
            ? Text(context.l10n.typeDatabaseCategoryAll, overflow: TextOverflow.ellipsis)
            : CategoryNameText(categoryId: _categoryId!),
      ),
      menuChildren: [
        MenuItemButton(
          onPressed: () => _onCategoryChanged(null),
          leadingIcon: _menuCheckIcon(_categoryId == null),
          child: Text(context.l10n.typeDatabaseCategoryAll),
        ),
        for (final category in categories)
          MenuItemButton(
            onPressed: () => _onCategoryChanged(category.categoryId),
            leadingIcon: _menuCheckIcon(_categoryId == category.categoryId),
            child: CategoryNameText(categoryId: category.categoryId),
          ),
      ],
    );
  }

  Widget _buildSortControls(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      MenuAnchor(
        builder: (context, controller, _) => _menuAnchorButton(
          controller: controller,
          icon: Icons.sort,
          label: Text(_sortKeyLabel(context, _sortKey), overflow: TextOverflow.ellipsis),
        ),
        menuChildren: [
          for (final key in [null, ...TypeSortKey.values])
            MenuItemButton(
              onPressed: () => _onSortKeySelected(key),
              leadingIcon: _menuCheckIcon(_sortKey == key),
              child: Text(_sortKeyLabel(context, key)),
            ),
        ],
      ),
      if (_sortKey != null)
        IconButton(
          iconSize: 18,
          visualDensity: VisualDensity.compact,
          tooltip: _direction == TypeSortDirection.ascending
              ? context.l10n.typeDatabaseSortAscending
              : context.l10n.typeDatabaseSortDescending,
          icon: Icon(
            _direction == TypeSortDirection.ascending ? Icons.arrow_upward : Icons.arrow_downward,
          ),
          onPressed: () => setState(() {
            _direction = _direction == TypeSortDirection.ascending
                ? TypeSortDirection.descending
                : TypeSortDirection.ascending;
          }),
        ),
    ],
  );

  Widget _buildBrowseMode(BuildContext context, RepoCollectionService collection) {
    final categoryId = _categoryId;
    if (categoryId == null) {
      final categories = collection.getAllCategories().toList()
        ..sort((a, b) => a.categoryId.compareTo(b.categoryId));
      return ListView.builder(
        itemCount: categories.length,
        itemBuilder: (context, index) => CategoryListTile(
          categoryId: categories[index].categoryId,
          fallbackLeading: const Icon(Icons.list),
          onTap: () => _onCategoryChanged(categories[index].categoryId),
        ),
      );
    }
    return EveSelectList(
      key: ValueKey(categoryId),
      root: EveSelectListRoot.category(categoryId: categoryId),
      validator: (node) => switch (node) {
        EveSelectListRootType(:final typeId) => switch (collection.getType(typeId)) {
          final type? => _metaFilter.passes(type),
          _ => false,
        },
        _ => true,
      },
      shallPopToSelect: (node) => node is EveSelectListRootType,
      onSelect: (node) => switch (node) {
        EveSelectListRootType(:final typeId) => unawaited(
          showItemDetailPage(context, typeId: typeId),
        ),
        _ => null,
      },
    );
  }

  Widget _buildFlatMode(BuildContext context, RepoCollectionService collection) {
    if (_sortKey == TypeSortKey.name && _sortNames == null) {
      return const SelectListSkeleton();
    }
    final types = _sortedTypes(collection);
    if (types.isEmpty) {
      return Center(
        child: Padding(
          padding: const .symmetric(horizontal: 24),
          child: Text(
            context.l10n.typeSearchNoResults,
            style: context.theme.textTheme.titleMedium?.copyWith(
              color: context.theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: types.length,
      itemBuilder: (context, index) {
        final type = types[index];
        return TypeListTile(
          typeId: type.typeId,
          fallbackLeading: const Image(image: ImageAssets.unknownIcon, height: 32),
          onTap: () => unawaited(showItemDetailPage(context, typeId: type.typeId)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final collectionLoading = ref.watch(
      dataReadinessProvider.select((DataReadinessState s) => s is DataReadinessLoading),
    );
    final collection = ref.watch(repoCollectionProvider);
    if (collection == null) {
      return Layout(
        title: context.l10n.typeDatabaseTitle,
        child: collectionLoading ? const SelectListSkeleton() : const SizedBox.shrink(),
      );
    }

    return Layout(
      title: context.l10n.typeDatabaseTitle,
      child: Column(
        children: [
          Padding(
            padding: const .fromLTRB(16, 8, 16, 4),
            child: EveTypeSearchField(
              searcher: LocalizationTypeSearcher.fromRef(ref).search,
              onResults: _onSearchResults,
            ),
          ),
          Padding(
            padding: const .symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _buildCategorySelector(context, collection),
                  ),
                ),
                _buildSortControls(context),
              ],
            ),
          ),
          MetaFilterBar(filter: _metaFilter, onChanged: _onMetaFilterChanged),
          Expanded(
            child: _isFlatMode
                ? _buildFlatMode(context, collection)
                : _buildBrowseMode(context, collection),
          ),
        ],
      ),
    );
  }
}
