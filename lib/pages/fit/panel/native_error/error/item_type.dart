part of 'error.dart';

class IncompatibleShipGroup extends StatelessWidget {
  final List<int> expected;

  const IncompatibleShipGroup({super.key, required this.expected});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: _errorIcon,
        title: const Text('舰船类型不匹配'),
        subtitle: Text(
          '期望类型: ${expected.map(_getShipGroupName).join(', ')}',
        ),
      );
}

String _getShipGroupName(int groupID) => GlobalStorage().static.groups[groupID]?.nameZH ?? '未知';

class IncompatibleShipType extends StatelessWidget {
  final List<int> expected;

  const IncompatibleShipType({super.key, required this.expected});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: _errorIcon,
        title: const Text('舰船类型不匹配'),
        subtitle: Text(
          '期望类型: ${expected.map(_getShipTypeName).join(', ')}',
        ),
      );
}

String _getShipTypeName(int shipID) => GlobalStorage().static.types[shipID]?.nameZH ?? '未知';
