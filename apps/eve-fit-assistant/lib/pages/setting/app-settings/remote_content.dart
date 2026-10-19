import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/components/list/config_list.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

@RoutePage()
class RemoteContentSettingsPage extends ConsumerWidget {
  const RemoteContentSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Layout(
    title: context.l10n.appSettingsPageSectionRemoteContent,
    child: const ConfigListView(
      children: [
        ConfigListTile.custom(RemoteContentEnabledTile()),
        ConfigListTile.custom(RemoteContentEndpointTile()),
      ],
    ),
  );
}

class RemoteContentEnabledTile extends ConsumerWidget {
  const RemoteContentEnabledTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      appSettingServiceProvider.select((setting) => setting.remoteContent.enabled),
    );
    return SwitchListTile(
      secondary: const Icon(Icons.cloud_sync_outlined),
      title: Text(context.l10n.appSettingsPageRemoteContentEnabledTitle),
      subtitle: Text(context.l10n.appSettingsPageRemoteContentEnabledDescription),
      value: enabled,
      onChanged: (value) => ref
          .read(appSettingServiceProvider.notifier)
          .update((setting) => setting.copyWith.remoteContent(enabled: value)),
    );
  }
}

class RemoteContentEndpointTile extends ConsumerWidget {
  const RemoteContentEndpointTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appSettingServiceProvider.select((setting) => setting.remoteContent));
    final notSet = context.l10n.appSettingsPageRemoteContentNotSet;
    String endpointValue(String value) => value.isEmpty ? notSet : value;

    return ListTile(
      leading: const Icon(Icons.link_outlined),
      title: Text(context.l10n.appSettingsPageRemoteContentEndpointTitle),
      subtitle: Text(
        context.l10n.appSettingsPageRemoteContentEndpointDescription(
          origin: endpointValue(config.originUrl),
          resourceRoot: "",
          channel: endpointValue(config.channel),
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showRemoteContentEndpointDialog(context, ref, config),
    );
  }
}

Future<void> _showRemoteContentEndpointDialog(
  BuildContext context,
  WidgetRef ref,
  RemoteContentSetting config,
) async {
  final originUrl = await showDialog<String>(
    context: context,
    builder: (context) => _RemoteContentEndpointDialog(originUrl: config.originUrl),
  );
  if (originUrl == null) {
    return;
  }
  ref
      .read(appSettingServiceProvider.notifier)
      .update((setting) => setting.copyWith.remoteContent(originUrl: originUrl));
}

class _RemoteContentEndpointDialog extends StatefulWidget {
  const _RemoteContentEndpointDialog({required this.originUrl});

  final String originUrl;

  @override
  State<_RemoteContentEndpointDialog> createState() => _RemoteContentEndpointDialogState();
}

class _RemoteContentEndpointDialogState extends State<_RemoteContentEndpointDialog> {
  late final TextEditingController originController;

  @override
  void initState() {
    super.initState();
    originController = TextEditingController(text: widget.originUrl);
  }

  @override
  void dispose() {
    originController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.appSettingsPageRemoteContentEndpointTitle),
    content: TextField(
      controller: originController,
      decoration: InputDecoration(
        labelText: context.l10n.appSettingsPageRemoteContentOriginUrlLabel,
        hintText: context.l10n.appSettingsPageRemoteContentUrlHint,
      ),
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.done,
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(originController.text.trim()),
        child: Text(MaterialLocalizations.of(context).saveButtonLabel),
      ),
    ],
  );
}
