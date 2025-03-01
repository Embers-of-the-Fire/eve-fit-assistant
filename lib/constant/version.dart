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

  String stringify() => '$major.$minor.$patch';

  String stringifyFull() => '$major.$minor.$patch${appendix != null ? '-$appendix' : ''}';
}

const Version flutterVersion = Version(major: 3, minor: 29, patch: 0);

const Version dartVersion = Version(major: 3, minor: 7, patch: 0);
