import "package:animated_text_kit/animated_text_kit.dart";
import "package:eve_fit_assistant/components/wizard/wizard_tokens.dart";
import "package:flutter/material.dart";

/// A wizard header animated in whenever [animationKey] changes.
///
/// This is the reusable animation mechanism behind the server step's metadata
/// display: a step supplies a [title] plus a list of metadata [details] and a
/// key that changes on every selection switch. The readout runs as a cohesive
/// sequence via `animated_text_kit`: the [title] rotates in first
/// ([RotateAnimatedText]), then the [details] block types beneath it
/// ([TypewriterAnimatedText]). Steps remain free of animation details; they
/// only map their domain data to strings.
class WizardRotatingHeader extends StatefulWidget {
  const WizardRotatingHeader({
    required this.title,
    required this.details,
    required this.animationKey,
    required this.textAlign,
    super.key,
  });

  /// The headline that rotates in first on every [animationKey] change.
  final String title;

  /// Metadata lines that type in after the title (already localized).
  final List<String> details;

  /// Changes whenever the displayed subject switches, restarting the readout.
  final Key animationKey;

  /// Text alignment supplied by the surrounding layout (left on phones, right on tablets).
  final TextAlign textAlign;

  @override
  State<WizardRotatingHeader> createState() => _WizardRotatingHeaderState();
}

class _WizardRotatingHeaderState extends State<WizardRotatingHeader> {
  static const _speed = Duration(milliseconds: 40);
  static const _pause = Duration(milliseconds: 200);
  static const _titleDuration = Duration(milliseconds: 400);

  bool _nameTyped = false;

  @override
  void didUpdateWidget(WizardRotatingHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animationKey != oldWidget.animationKey) {
      _nameTyped = false;
    }
  }

  double _lineHeight(TextStyle style) => (style.fontSize ?? 16) * (style.height ?? 1.3);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tokens = WizardTokens.of(context);
    final titleStyle = theme.textTheme.headlineMedium ?? const TextStyle(fontSize: 28);
    final detailStyle = (theme.textTheme.bodyLarge ?? const TextStyle(fontSize: 16)).copyWith(
      color: colorScheme.onSurfaceVariant,
    );

    final rotateAlign = widget.textAlign == TextAlign.right
        ? Alignment.topRight
        : Alignment.topLeft;

    final nameKey = ValueKey(Object.hash(widget.animationKey, "name"));
    final detailsKey = ValueKey(Object.hash(widget.animationKey, "details"));

    final titleBoxHeight = (titleStyle.fontSize ?? 28) * 2.0;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: titleBoxHeight,
          child: AnimatedTextKit(
            key: nameKey,
            isRepeatingAnimation: false,
            totalRepeatCount: 1,
            pause: _pause,
            displayFullTextOnTap: true,
            onFinished: () {
              if (mounted) setState(() => _nameTyped = true);
            },
            animatedTexts: [
              RotateAnimatedText(
                widget.title,
                textStyle: titleStyle,
                textAlign: widget.textAlign,
                alignment: rotateAlign,
                transitionHeight: titleBoxHeight,
                rotateOut: false,
                duration: _titleDuration,
              ),
            ],
          ),
        ),
        SizedBox(height: tokens.spacingXs),
        SizedBox(
          width: double.infinity,
          height: _lineHeight(detailStyle) * (widget.details.length + 1),
          child: _nameTyped
              ? AnimatedTextKit(
                  key: detailsKey,
                  isRepeatingAnimation: false,
                  totalRepeatCount: 1,
                  displayFullTextOnTap: true,
                  animatedTexts: [
                    TypewriterAnimatedText(
                      "${widget.details.join("\n")}\n",
                      textStyle: detailStyle,
                      textAlign: widget.textAlign,
                      speed: _speed,
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
