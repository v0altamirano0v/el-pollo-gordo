import '../core/db_client.dart';

abstract class AppDatabase {
  Future<DbClient> open();
}
