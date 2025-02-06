import 'package:eve_fit_assistant/storage/path.dart';

Future initAllStorage() async {
  await getStorageDir(create: true);
  await getRecordDir(create: true);
  await getBriefRecordDir(create: true);
  await getFullRecordDir(create: true);
}
