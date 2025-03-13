part of 'preference.dart';

const _esiAuthKey = 'esi_auth';

enum EsiAuthBehavior {
  immediate,
  doubleCheck;

  static const defaultValue = immediate;

  void setDefault(SharedPreferences prefs) {
    if (!prefs.containsKey(_esiAuthKey)) {
      prefs.setInt(_esiAuthKey, defaultValue.index);
    }
  }

  Future<void> set(SharedPreferences prefs) async {
    await prefs.setInt(_esiAuthKey, index);
  }

  static EsiAuthBehavior get(SharedPreferences prefs) =>
      EsiAuthBehavior.values[prefs.getInt(_esiAuthKey) ?? 0];
}

const _esiAuthServerKey = 'esi_auth_server';

@JsonEnum(valueField: 'value')
enum EsiAuthServer {
  tranquility._(0),
  serenity._(1);

  const EsiAuthServer._(this.value);

  final int value;

  factory EsiAuthServer(int value) => switch (value) {
        0 => tranquility,
        1 => serenity,
        _ => throw ArgumentError.value(value, 'EsiAuthServer'),
      };

  static const defaultValue = tranquility;

  void setDefault(SharedPreferences prefs) {
    if (!prefs.containsKey(_esiAuthServerKey)) {
      prefs.setInt(_esiAuthServerKey, defaultValue.index);
    }
  }

  Future<void> set(SharedPreferences prefs) async {
    await prefs.setInt(_esiAuthServerKey, index);
  }

  static EsiAuthServer get(SharedPreferences prefs) =>
      EsiAuthServer.values[prefs.getInt(_esiAuthServerKey) ?? 0];

  String get datasourceText => switch (this) {
        tranquility => 'tranquility',
        serenity => 'serenity',
      };
}
