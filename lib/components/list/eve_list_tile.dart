import "package:eve_fit_assistant/components/icon/eve_icon.dart";
import "package:eve_fit_assistant/components/localized_text.dart";
import "package:eve_fit_assistant/storage/bundle/service/collection.dart";
import "package:eve_fit_assistant/utils/fp.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class GroupListTile extends ConsumerWidget {
  const GroupListTile({
    required this.groupId,
    super.key,
    this.trailing,
    this.leading,
    this.fallbackLeading,
    this.onTap,
  });

  final int groupId;
  final Widget? trailing;
  final Widget? leading;
  final Widget? fallbackLeading;
  final void Function()? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupInfo = ref.watch(bundleCollectionGetGroupProvider(groupId));

    if (groupInfo == null) {
      return ListTile(title: Text("Unknown Group[$groupId]"));
    }

    return ListTile(
      leading: leading.orElse(
        () => EveIcon(icon: groupInfo.icon, acceptGraphic: false, fallbackIcon: fallbackLeading),
      ),
      title: LocalizedText(localizationKey: groupInfo.groupName, formatter: (t) => "$t[$groupId]"),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

class GroupNameText extends ConsumerWidget {
  const GroupNameText({required this.groupId, super.key});

  final int groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupNameId = ref.watch(
      bundleCollectionGetGroupProvider(groupId).select((t) => t?.groupName),
    );
    if (groupNameId == null) {
      return Text("Unknown Group[$groupId]");
    }
    return LocalizedText(localizationKey: groupNameId);
  }
}

class CategoryListTile extends ConsumerWidget {
  const CategoryListTile({
    required this.categoryId,
    super.key,
    this.trailing,
    this.leading,
    this.fallbackLeading,
    this.onTap,
  });

  final int categoryId;
  final Widget? trailing;
  final Widget? leading;
  final Widget? fallbackLeading;
  final void Function()? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryInfo = ref.watch(bundleCollectionGetCategoryProvider(categoryId));

    if (categoryInfo == null) {
      return ListTile(title: Text("Unknown Category[$categoryId]"));
    }

    return ListTile(
      leading: leading.orElse(
        () => EveIcon(icon: categoryInfo.icon, acceptGraphic: false, fallbackIcon: fallbackLeading),
      ),
      title: LocalizedText(localizationKey: categoryInfo.categoryName),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

class CategoryNameText extends ConsumerWidget {
  const CategoryNameText({required this.categoryId, super.key});

  final int categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryNameId = ref.watch(
      bundleCollectionGetCategoryProvider(categoryId).select((t) => t?.categoryName),
    );
    if (categoryNameId == null) {
      return Text("Unknown Category[$categoryId]");
    }
    return LocalizedText(localizationKey: categoryNameId);
  }
}

class MarketGroupListTile extends ConsumerWidget {
  const MarketGroupListTile({
    required this.marketGroupId,
    super.key,
    this.trailing,
    this.leading,
    this.fallbackLeading,
    this.onTap,
  });

  final int marketGroupId;
  final Widget? trailing;
  final Widget? leading;
  final Widget? fallbackLeading;
  final void Function()? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marketGroupInfo = ref.watch(bundleCollectionGetMarketGroupProvider(marketGroupId));

    if (marketGroupInfo == null) {
      return ListTile(title: Text("Unknown Market Group[$marketGroupId]"));
    }

    return ListTile(
      leading: leading.orElse(
        () => EveIcon(
          icon: marketGroupInfo.icon,
          acceptGraphic: false,
          fallbackIcon: fallbackLeading,
        ),
      ),
      title: LocalizedText(localizationKey: marketGroupInfo.marketGroupName),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

class MarketGroupNameText extends ConsumerWidget {
  const MarketGroupNameText({required this.marketGroupId, super.key});

  final int marketGroupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marketGroupNameId = ref.watch(
      bundleCollectionGetMarketGroupProvider(marketGroupId).select((t) => t?.marketGroupName),
    );
    if (marketGroupNameId == null) {
      return Text("Unknown Market Group[$marketGroupId]");
    }
    return LocalizedText(localizationKey: marketGroupNameId);
  }
}

class TypeListTile extends ConsumerWidget {
  const TypeListTile({
    required this.typeId,
    super.key,
    this.trailing,
    this.leading,
    this.fallbackLeading,
    this.onTap,
  });

  final int typeId;
  final Widget? trailing;
  final Widget? leading;
  final Widget? fallbackLeading;
  final void Function()? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeInfo = ref.watch(bundleCollectionGetTypeProvider(typeId));

    if (typeInfo == null) {
      return ListTile(title: Text("Unknown Type[$typeId]"));
    }
    final metaGroupIcon = ref.watch(
      bundleCollectionGetMetaGroupProvider(typeInfo.metaGroupId).select((t) => t?.icon),
    );

    return ListTile(
      leading: leading.orElse(
        () =>
            EveIcon(icon: typeInfo.icon, overlayIcon: metaGroupIcon, fallbackIcon: fallbackLeading),
      ),
      title: LocalizedText(localizationKey: typeInfo.typeName),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

class TypeNameText extends ConsumerWidget {
  const TypeNameText({required this.typeId, super.key});

  final int typeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeNameId = ref.watch(
      bundleCollectionGetTypeProvider(typeId).select((t) => t?.typeName),
    );
    if (typeNameId == null) {
      return Text("Unknown Type[$typeId]");
    }
    return LocalizedText(localizationKey: typeNameId);
  }
}
