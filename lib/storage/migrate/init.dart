part of 'migrate.dart';

Future<void> initStorage() async {
  await getStorageDir(create: true);
  await getRecordDir(create: true);
  await getBriefRecordFile(create: true);
  await getFullRecordDir(create: true);
}
