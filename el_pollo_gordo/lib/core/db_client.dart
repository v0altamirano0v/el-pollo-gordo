typedef DbRow = Map<String, Object?>;

enum SortDir { asc, desc }

class DbOrder {
  final String field;
  final SortDir direction;
  const DbOrder(this.field, [this.direction = SortDir.asc]);
}

abstract class DbClient {
  Future<int> insert(String table, DbRow values);
  Future<int> update(String table, DbRow values, {Map<String, Object?> where = const {}});
  Future<int> delete(String table, {Map<String, Object?> where = const {}});
  Future<List<DbRow>> query(
    String table, {
    Map<String, Object?> where = const {},
    List<DbOrder> orderBy = const [],
    int? limit,
  });
  Future<T> transaction<T>(Future<T> Function(DbClient tx) action);
  Future<void> flush();
  Future<void> close();
}

String buildWhereSql(Map<String, Object?> where) {
  if (where.isEmpty) return '';
  final parts = <String>[];
  for (final key in where.keys) {
    parts.add(where[key] == null ? '$key IS NULL' : '$key = ?');
  }
  return ' WHERE ${parts.join(' AND ')}';
}

List<Object?> whereArgs(Map<String, Object?> where) =>
    where.values.where((v) => v != null).toList(growable: false);

String buildOrderSql(List<DbOrder> orderBy) {
  if (orderBy.isEmpty) return '';
  final parts = orderBy
      .map((o) => '${o.field} ${o.direction == SortDir.desc ? 'DESC' : 'ASC'}')
      .join(', ');
  return ' ORDER BY $parts';
}
