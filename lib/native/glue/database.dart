import 'dart:io';

import 'package:eve_fit_assistant/native/port/api.dart' as native;
import 'package:eve_fit_assistant/native/port/api/data.dart';
import 'package:eve_fit_assistant/native/port/api/schema.dart' as schema;
import 'package:eve_fit_assistant/storage/static/storage.dart';

class NativeDatabase {
  final EveDatabase _raw;

  const NativeDatabase._private(this._raw);

  static Future<NativeDatabase> init() async {
    final storage = await getNativeStorageDir(create: true);
    final dogmaAttr = await File('${storage.path}/dogmaAttributes.pb2').readAsBytes();
    final dogmaEffect = await File('${storage.path}/dogmaEffects.pb2').readAsBytes();
    final typeDogma = await File('${storage.path}/typeDogma.pb2').readAsBytes();
    final types = await File('${storage.path}/types.pb2').readAsBytes();
    final buffs = await File('${storage.path}/dbuffcollections.pb2').readAsBytes();

    final db = await EveDatabase.init(
        dogmaAttrBuffer: dogmaAttr,
        dogmaEffectBuffer: dogmaEffect,
        typeDogmaBuffer: typeDogma,
        typesBuffer: types,
        buffCollectionsBuffer: buffs);

    return NativeDatabase._private(db);
  }

  native.CalculateOutput calculate(schema.Fit fit) => native.calculate(db: _raw, fit: fit);

  Map<int, double> getTypeAttr(int typeID) => native.getTypeAttr(db: _raw, typeId: typeID);
}

Future<Directory> getNativeStorageDir({bool create = false}) async {
  final appDir = await getStaticStorageDir();
  final nativeDir = Directory('${appDir.path}/native');
  if (create && !await nativeDir.exists()) {
    await nativeDir.create();
  }
  return nativeDir;
}
