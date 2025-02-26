part of 'error.dart';

class TooMuchTurret extends StatelessWidget {
  final int expected;
  final int actual;

  const TooMuchTurret({super.key, required this.expected, required this.actual});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: _errorIcon,
        title: const Text('炮台数量过多'),
        subtitle: Text(
          '最大容量: $expected\n'
          '实际数量: $actual',
        ),
      );
}

class TooMuchLauncher extends StatelessWidget {
  final int expected;
  final int actual;

  const TooMuchLauncher({super.key, required this.expected, required this.actual});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: _errorIcon,
        title: const Text('发射器数量过多'),
        subtitle: Text(
          '最大容量: $expected\n'
          '实际数量: $actual',
        ),
      );
}

class ConflictItem extends StatelessWidget {
  final int groupID;

  const ConflictItem({super.key, required this.groupID});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: _errorIcon,
        title: const Text('物品冲突'),
        subtitle: Text('超出物品组 ${GlobalStorage().static.groups[groupID]?.nameZH ?? groupID} 的数量限制'),
      );
}
