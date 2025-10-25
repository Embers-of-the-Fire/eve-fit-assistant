import "package:flutter/material.dart";

class HomepageLinkCard extends StatelessWidget {
  const HomepageLinkCard({required this.title, required this.icon, required this.onTap, super.key});

  final String title;
  final IconData icon;
  final void Function() onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final titleStyle =
        Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ) ??
        TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.onSurface);

    // Keep the tile square. Size things relative to the actual tile width for good scaling on different screen sizes.
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tileWidth = constraints.maxWidth;
          final iconSize = (tileWidth * 0.36).clamp(24.0, 64.0);
          final contentSpacing = (tileWidth * 0.06).clamp(6.0, 14.0);

          return Card(
            // Use a flat, low-contrast style: no elevation, subtle outline and beveled corners
            elevation: 0,
            shape: BeveledRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: colorScheme.outline, width: 0.9),
            ),
            clipBehavior: Clip.hardEdge,
            // use Material 3 recommended container color for flat surfaces
            color: colorScheme.surfaceContainerHighest,
            child: Ink(
              // flat background (no heavy gradient) to avoid interfering with boundary recognition
              decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest),
              child: InkWell(
                onTap: onTap,
                // use withAlpha to avoid withOpacity deprecation warnings
                splashColor: colorScheme.primary.withAlpha((0.12 * 255).round()),
                highlightColor: colorScheme.primary.withAlpha((0.06 * 255).round()),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: iconSize,
                        child: Center(
                          child: Icon(icon, size: iconSize, color: colorScheme.onSurface),
                        ),
                      ),
                      SizedBox(height: contentSpacing),
                      Flexible(
                        child: Text(
                          title,
                          style: titleStyle,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
