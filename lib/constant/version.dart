part of 'constant.dart';

class Version {
  final int major;
  final int minor;
  final int patch;
  final String? appendix;

  const Version({
    required this.major,
    required this.minor,
    required this.patch,
    this.appendix,
  });

  String stringify() {
    return '$major.$minor.$patch';
  }

  String stringifyFull() {
    return '$major.$minor.$patch${appendix != null ? '-$appendix' : ''}';
  }
}

const Version flutterVersion = Version(major: 3, minor: 27, patch: 3);

const Version dartVersion = Version(major: 3, minor: 6, patch: 1);
