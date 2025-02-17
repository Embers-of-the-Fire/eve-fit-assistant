import 'dart:io';
import 'dart:typed_data';

import 'package:eve_fit_assistant/storage/proto/implant_group.pb.dart';

class ImplantSubGroup {
  final ImplantGroups_ImplantSubGroup _raw;

  String get name => _raw.name;

  List<int> get items => _raw.items;

  const ImplantSubGroup._private(this._raw);
}

class ImplantGroup {
  final String _name;
  final List<ImplantSubGroup> _groups;

  String get name => _name;

  List<ImplantSubGroup> get groups => _groups;

  const ImplantGroup._private(this._name, this._groups);

  factory ImplantGroup._fromRaw(ImplantGroups_ImplantGroup raw) =>
      ImplantGroup._private(raw.name, raw.groups.map((v) => ImplantSubGroup._private(v)).toList());

  static List<ImplantGroup> _fromBuffer(Uint8List buffer) {
    final raw = ImplantGroups.fromBuffer(buffer);
    return raw.groups.map((v) => ImplantGroup._fromRaw(v)).toList();
  }

  static Future<List<ImplantGroup>> read(Directory staticDir) async {
    final file = File('${staticDir.path}/implant_group.pb');
    final buffer = await file.readAsBytes();
    return ImplantGroup._fromBuffer(buffer);
  }
}
