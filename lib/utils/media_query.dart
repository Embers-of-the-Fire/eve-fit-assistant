part of 'utils.dart';

// final _ = MediaQuery.removePadding(context: context, child: child);

MediaQuery mediaQuerySetPadding({
  Key? key,
  required BuildContext context,
  double? left,
  double? top,
  double? right,
  double? bottom,
  required Widget child,
}) =>
    MediaQuery(
        key: key,
        data: MediaQuery.of(context).let((u) => u.copyWith(
              padding: EdgeInsets.only(
                left: left ?? 0,
                top: top ?? 0,
                right: right ?? 0,
                bottom: bottom ?? 0,
              ),
              viewPadding: u.viewPadding.copyWith(
                left: left.map((x) => x + math.max(0.0, u.viewPadding.left - u.padding.left)),
                top: top.map((x) => x + math.max(0.0, u.viewPadding.top - u.padding.top)),
                right: right.map((x) => x + math.max(0.0, u.viewPadding.right - u.padding.right)),
                bottom:
                    bottom.map((x) => x + math.max(0.0, u.viewPadding.bottom - u.padding.bottom)),
              ),
            )),
        child: child);
