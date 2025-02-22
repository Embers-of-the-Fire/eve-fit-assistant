part of 'migrate.dart';

Future<void> initStorage() async {
  await getStorageDir(create: true);

  await getFitDir(create: true);
  await getFitBriefFile(create: true);
  await getFitFullDir(create: true);

  await getCharacterDir(create: true);
  await getCharacterBriefFile();
  await getCharacterFullDir(create: true);
}
