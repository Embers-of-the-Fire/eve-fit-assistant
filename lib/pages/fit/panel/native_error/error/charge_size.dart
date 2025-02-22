part of 'error.dart';

class IncompatibleChargeSize extends StatelessWidget {
  final int expected;
  final int actual;

  const IncompatibleChargeSize({super.key, required this.expected, required this.actual});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: _errorIcon,
        title: const Text('弹药尺寸不匹配'),
        subtitle: Text(
          '期望尺寸: ${getSizeName(expected)}\n'
          '实际尺寸: ${getSizeName(actual)}',
        ),
      );
}

String getSizeName(int size) => switch (size) {
      1 => '小型',
      2 => '中型',
      3 => '大型',
      4 => '超大型',
      _ => '未知',
    };

class IncompatibleChargeCapacity extends StatelessWidget {
  final double max;
  final double actual;

  const IncompatibleChargeCapacity({super.key, required this.max, required this.actual});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: _errorIcon,
        title: const Text('弹药尺寸过大'),
        subtitle: Text(
          '最大容量: ${max.toStringAsFixed(1)} m³\n'
          '实际体积: ${actual.toStringAsFixed(1)} m³',
        ),
      );
}
