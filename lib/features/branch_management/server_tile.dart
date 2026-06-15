import "package:eve_fit_assistant/storage/repo/models/remote_catalog.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";

class ServerTile extends StatelessWidget {
  const ServerTile({
    required this.serverId,
    required this.entry,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String serverId;
  final GenerationServerEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final locale = context.locale.languageCode;
    final displayName = entry.name[locale] ?? entry.name["en"] ?? serverId;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          selected ? Icons.check_circle : Icons.circle_outlined,
          color: selected ? theme.colorScheme.primary : theme.colorScheme.outline,
        ),
        title: Text(displayName, style: theme.textTheme.titleMedium),
        subtitle: Text(serverId, style: theme.textTheme.bodySmall),
        trailing: selected ? Icon(Icons.arrow_forward, color: theme.colorScheme.primary) : null,
      ),
    );
  }
}

class CheckoutTile extends StatelessWidget {
  const CheckoutTile({
    required this.checkout,
    required this.selected,
    required this.onTap,
    this.installed = false,
    super.key,
  });

  final GenerationCheckoutEntry checkout;
  final bool selected;
  final bool installed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final metadata = checkout.metadata;
    final dateStr = _formatIsoDate(checkout.createdAt);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          selected ? Icons.check_circle : Icons.circle_outlined,
          color: selected ? theme.colorScheme.primary : theme.colorScheme.outline,
        ),
        title: Text(
          "${metadata.gameVersion} / ${metadata.gameBuild}",
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${context.l10n.branchServerLabel}: ${metadata.gameServer}",
              style: theme.textTheme.bodySmall,
            ),
            Text(dateStr, style: theme.textTheme.bodySmall),
            if (installed)
              Text(
                context.l10n.checkoutFilterInstalled,
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary),
              ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}

String _formatIsoDate(String iso) {
  try {
    final dt = DateTime.parse(iso);
    final y = dt.year.toString();
    final mo = dt.month.toString().padLeft(2, "0");
    final d = dt.day.toString().padLeft(2, "0");
    final h = dt.hour.toString().padLeft(2, "0");
    final mi = dt.minute.toString().padLeft(2, "0");
    return "$y-$mo-$d $h:$mi";
  } on FormatException {
    return iso;
  }
}
