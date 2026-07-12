import 'package:drift/native.dart';
import 'package:s1_app/services/app_database.dart';
import 'package:s1_app/services/app_local_data.dart';

Future<(AppDatabase db, AppLocalData local)> openTestLocalData() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final local = AppLocalData(db);
  await local.load();
  return (db, local);
}
