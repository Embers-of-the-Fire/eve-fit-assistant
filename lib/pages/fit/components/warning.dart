part of "../page.dart";

enum WarningType { info, warning, error }

class WarningTrigger extends StatelessWidget {
  const WarningTrigger({required this.type, super.key, this.onTap});

  final WarningType type;
  final void Function()? onTap;

  @override
  Widget build(BuildContext context) => Ink(
    decoration: const BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(50))),
    child: InkWell(
      borderRadius: const BorderRadius.all(Radius.circular(50)),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(5),
        child: switch (type) {
          WarningType.info => const Icon(Icons.info, color: Colors.blue, size: 16),
          WarningType.warning => const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 16,
          ),
          WarningType.error => const Icon(Icons.error, color: Colors.red, size: 16),
        },
      ),
    ),
  );
}
