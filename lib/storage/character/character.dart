import 'dart:io';
import 'dart:typed_data';

import 'package:eve_fit_assistant/storage/proto/character.pb.dart' as proto;
import 'package:eve_fit_assistant/storage/static/storage.dart';

class Character {
  final proto.Character _raw;

  String get name => _raw.name;

  String get description => _raw.description;

  Map<int, int> get skills => _raw.skills;

  const Character._private(this._raw);

  static Character _fromBuffer(Uint8List buffer) {
    final raw = proto.Character.fromBuffer(buffer);
    return Character._private(raw);
  }

  static Future<Character> readFromFile(File file) async {
    final buffer = await file.readAsBytes();
    return _fromBuffer(buffer);
  }
}

class CharacterStorage {
  late final Character _predefinedAll5;
  late final Character _predefinedAll0;

  Character get predefinedAll5 => _predefinedAll5;

  Character get predefinedAll0 => _predefinedAll0;

  CharacterStorage();

  Future<void> init() async {
    final staticDir = await getStaticPersonDir();
    final all5File = File('${staticDir.path}/max.pb');
    final all0File = File('${staticDir.path}/min.pb');
    _predefinedAll5 = await Character.readFromFile(all5File);
    _predefinedAll0 = await Character.readFromFile(all0File);
  }
}

Future<Directory> getStaticPersonDir({bool create = false}) async {
  final staticDir = await getStaticStorageDir();
  final staticPersonDir = Directory('${staticDir.path}/person');
  if (create && !await staticPersonDir.exists()) {
    await staticPersonDir.create();
  }
  return staticPersonDir;
}
