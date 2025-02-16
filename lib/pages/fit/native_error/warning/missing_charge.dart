part of 'warning.dart';

class MissingCharge extends StatelessWidget {
  const MissingCharge({super.key});

  @override
  Widget build(BuildContext context) => const ListTile(
        leading: _warningIcon,
        title: Text('缺少弹药'),
      );
}
