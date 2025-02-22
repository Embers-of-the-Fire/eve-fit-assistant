part of 'error.dart';

class IncompatibleRigSize extends StatelessWidget {
  final int expected;
  final int actual;

  const IncompatibleRigSize({super.key, required this.expected, required this.actual});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: _errorIcon,
        title: const Text('改装件尺寸不匹配'),
        subtitle: Text(
          '期望尺寸: ${getSizeName(expected)}\n'
          '实际尺寸: ${getSizeName(actual)}',
        ),
      );
}
