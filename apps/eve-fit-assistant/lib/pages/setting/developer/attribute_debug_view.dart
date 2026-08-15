part of "page.dart";

class AttributeDebugViewTile extends ConsumerWidget {
  const AttributeDebugViewTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => SwitchListTile(
    secondary: const FaIcon(FontAwesomeIcons.listOl),
    title: const Text("Attribute Debug View"),
    subtitle: const Text("Show unpublished attributes with internal identifiers"),
    value: ref.watch(appSettingServiceProvider.select((s) => s.attributeDebugView)),
    onChanged: (value) => ref
        .read(appSettingServiceProvider.notifier)
        .update((setting) => setting.copyWith(attributeDebugView: value)),
  );
}
