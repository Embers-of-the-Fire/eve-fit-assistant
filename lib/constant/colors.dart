import "package:flutter/widgets.dart";
import "package:markdown_widget/markdown_widget.dart";

const Color primaryBlue = Color(0xFF30B2E6);
const Color deepBlue = Color(0xFF0C1213);
const Color deepSpace = Color(0xFF0A1A2A);
const Color cyberTeal = Color(0xFF2A7B9C);
const Color neonHighlight = Color(0xFF4ED4FF);
const Color terminalText = Color(0xFFE0F4FF);

const Color neonGreen = Color(0xFF4DFFDF);
const Color neonPurple = Color(0xFF9B6DFF);
const Color neonPink = Color(0xFFFF4DFF);

const Color colorStatusActive = Color(0xFF2E7D32);
const Color colorStatusOverload = Color(0xFFEF5350);
const Color colorStatusOnline = Color(0xFFBDBDBD);
const Color colorStatusPassive = Color(0xFF2D2D2D);

const Color colorSkillAlphaLimited = Color(0xFFFBC02D);

const Color colorActionDelete = Color(0xFFFE4A49);

const CodeConfig _markdownCodeConfig = CodeConfig(
  style: TextStyle(backgroundColor: Color(0xCCeff1f3), color: Color(0xFF424242)),
);

/// Build the shared markdown config, optionally with a link-tap handler
/// (see `LinkConfig.onTap`; without one links open externally by default).
MarkdownConfig buildMarkdownDarkConfig({LinkConfig? linkConfig}) =>
    MarkdownConfig(configs: [_markdownCodeConfig, ?linkConfig]);

final MarkdownConfig markdownDarkConfig = buildMarkdownDarkConfig();
