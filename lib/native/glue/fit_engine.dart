import 'package:eve_fit_assistant/native/glue/database.dart';
import 'package:eve_fit_assistant/native/glue/fit.dart';
import 'package:eve_fit_assistant/native/port/api.dart' as native;
import 'package:eve_fit_assistant/storage/character/character.dart';
import 'package:eve_fit_assistant/storage/fit/fit.dart';

class FitEngine {
  late final NativeDatabase _database;

  FitEngine._private(this._database);

  static Future<FitEngine> init() async {
    final database = await NativeDatabase.init();
    return FitEngine._private(database);
  }

  native.CalculateOutput calculate({required Fit fit, required Character character}) =>
      _database.calculate(intoNativeFit(fit: fit, skills: character.skills));

  Map<int, double> getTypeAttr(int typeID) => _database.getTypeAttr(typeID);
}
