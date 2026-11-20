import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../core/db_client.dart';
import 'app_database.dart';
import 'schema.dart';

class WebDbClient implements DbClient {
  final SharedPreferences _prefs;
  final Map<String, List<DbRow>> _data = {
    for (final table in Tables.all) table: <DbRow>[],
  };

  WebDbClient(this._prefs);

  Future<void> load() async {
    final raw = _prefs.getString(AppConstants.webStorageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = json.decode(raw) as Map<String, dynamic>;
        for (final table in Tables.all) {
          final rows = decoded[table];
          if (rows is List) {
            _data[table] = rows
                .map((e) => Map<String, Object?>.from(e as Map))
                .toList();
          }
        }
        return;
      } catch (_) {
        // Si el JSON es inválido se reinicia con datos semilla.
      }
    }
    await seedDatabase(this);
    await flush();
  }

  @override
  Future<int> insert(String table, DbRow values) async {
    final rows = _rows(table);
    final row = Map<String, Object?>.from(values);
    if (row['id'] == null) {
      var max = 0;
      for (final r in rows) {
        final id = r['id'];
        if (id is int && id > max) max = id;
      }
      row['id'] = max + 1;
    }
    rows.add(row);
    await flush();
    return row['id'] as int;
  }

  @override
  Future<int> update(String table, DbRow values, {Map<String, Object?> where = const {}}) async {
    var count = 0;
    for (final row in _rows(table)) {
      if (_matches(row, where)) {
        row.addAll(values);
        count++;
      }
    }
    if (count > 0) await flush();
    return count;
  }

  @override
  Future<int> delete(String table, {Map<String, Object?> where = const {}}) async {
    final before = _rows(table).length;
    _rows(table).removeWhere((row) => _matches(row, where));
    final removed = before - _rows(table).length;
    if (removed > 0) await flush();
    return removed;
  }

  @override
  Future<List<DbRow>> query(
    String table, {
    Map<String, Object?> where = const {},
    List<DbOrder> orderBy = const [],
    int? limit,
  }) async {
    var rows = _rows(table).where((row) => _matches(row, where)).toList();
    if (orderBy.isNotEmpty) {
      rows.sort((a, b) {
        for (final order in orderBy) {
          final av = a[order.field];
          final bv = b[order.field];
          final cmp = _compare(av, bv);
          if (cmp != 0) {
            return order.direction == SortDir.desc ? -cmp : cmp;
          }
        }
        return 0;
      });
    }
    if (limit != null && rows.length > limit) {
      rows = rows.sublist(0, limit);
    }
    return rows.map((r) => Map<String, Object?>.from(r)).toList();
  }

  @override
  Future<T> transaction<T>(Future<T> Function(DbClient tx) action) => action(this);

  @override
  Future<void> flush() => _prefs.setString(AppConstants.webStorageKey, json.encode(_data));

  @override
  Future<void> close() async {}

  List<DbRow> _rows(String table) => _data.putIfAbsent(table, () => <DbRow>[]);

  bool _matches(DbRow row, Map<String, Object?> where) {
    for (final entry in where.entries) {
      final value = row[entry.key];
      if (entry.value == null && value != null) return false;
      if (entry.value != null && value != entry.value) return false;
    }
    return true;
  }

  int _compare(Object? a, Object? b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    if (a is num && b is num) return a.compareTo(b);
    return a.toString().compareTo(b.toString());
  }
}

class WebAppDatabase extends AppDatabase {
  @override
  Future<DbClient> open() async {
    final prefs = await SharedPreferences.getInstance();
    final client = WebDbClient(prefs);
    await client.load();
    return client;
  }
}

AppDatabase createPlatformDatabase() => WebAppDatabase();

