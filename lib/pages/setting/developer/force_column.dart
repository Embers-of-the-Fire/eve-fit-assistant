part of "page.dart";

class ForceColumnTile extends ConsumerWidget {
  const ForceColumnTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => DropdownListTile<ForceColumnSelection>(
    icon: Icons.view_column_outlined,
    title: const Text("Force Column Selection"),
    subtitle: const Text("Override the grid column count"),
    initialValue: ref.watch(appSettingServiceProvider.select((s) => s.forceColumn)),
    onValueChange: (value) => ref
        .read(appSettingServiceProvider.notifier)
        .update((old) => old.copyWith(forceColumn: value)),
    items: [
      for (final v in ForceColumnSelection.values) DropdownMenuItem(value: v, child: Text(v.label)),
    ],
  );
}
