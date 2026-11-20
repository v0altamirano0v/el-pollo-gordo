import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../core/constants.dart';
import '../core/db_client.dart';
import 'app_database.dart';
import 'schema.dart';

class SqfliteDbClient implements DbClient {
  final DatabaseExecutor _executor;
  final Database? _database;

  SqfliteDbClient(DatabaseExecutor executor, {Database? database})
      : _executor = executor,
        _database = database;

  @override
  Future<int> insert(String table, DbRow values) => _executor.insert(table, values);

  @override
  Future<int> update(String table, DbRow values, {Map<String, Object?> where = const {}}) {
    return _executor.update(
      table,
      values,
      where: buildWhereSql(where),
      whereArgs: whereArgs(where),
    );
  }

  @override
  Future<int> delete(String table, {Map<String, Object?> where = const {}}) {
    return _executor.delete(
      table,
      where: buildWhereSql(where),
      whereArgs: whereArgs(where),
    );
  }

  @override
  Future<List<DbRow>> query(
    String table, {
    Map<String, Object?> where = const {},
    List<DbOrder> orderBy = const [],
    int? limit,
  }) {
    return _executor.query(
      table,
      where: buildWhereSql(where),
      whereArgs: whereArgs(where),
      orderBy: buildOrderSql(orderBy),
      limit: limit,
    );
  }

  @override
  Future<T> transaction<T>(Future<T> Function(DbClient tx) action) {
    final database = _database;
    if (database == null) {
      throw StateError('Las transacciones solo se permiten desde el cliente raíz.');
    }
    return database.transaction((txn) => action(SqfliteDbClient(txn)));
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {
    await _database?.close();
  }
}

class IoAppDatabase extends AppDatabase {
  Future<Database>? _opened;

  @override
  Future<DbClient> open() async {
    final db = await _open();
    return SqfliteDbClient(db, database: db);
  }

  Future<Database> _open() {
    final cached = _opened;
    if (cached != null) return cached;
    final future = _create();
    _opened = future;
    return future;
  }

  Future<Database> _create() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, AppConstants.dbName);
    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        for (final table in Tables.all.reversed) {
          await db.execute('DROP TABLE IF EXISTS $table');
        }
        await _createSchema(db);
      },
    );
  }

  Future<void> _createSchema(Database db) async {
    for (final statement in schemaStatements) {
      await db.execute(statement);
    }
    await seedDatabase(SqfliteDbClient(db, database: db));
  }
}

AppDatabase createPlatformDatabase() => IoAppDatabase();


