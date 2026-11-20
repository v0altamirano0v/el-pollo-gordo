String? _sqfliteWhere(Map<String, Object?> where) {
    final sql = buildWhereSql(where).trim();
    if (sql.isEmpty) return null;
    return sql.replaceFirst(RegExp(r'^WHERE\s+', caseSensitive: false), '');
  }

  String? _sqfliteOrderBy(List<DbOrder> orderBy) {
    final sql = buildOrderSql(orderBy).trim();
    if (sql.isEmpty) return null;
    return sql.replaceFirst(RegExp(r'^ORDER\s+BY\s+', caseSensitive: false), '');
  }

  @override
  Future<int> insert(String table, DbRow values) => _executor.insert(table, values);

  @override
  Future<int> update(String table, DbRow values, {Map<String, Object?> where = const {}}) {
    final args = whereArgs(where);
    return _executor.update(
      table,
      values,
      where: _sqfliteWhere(where),
      whereArgs: args.isEmpty ? null : args,
    );
  }

  @override
  Future<int> delete(String table, {Map<String, Object?> where = const {}}) {
    final args = whereArgs(where);
    return _executor.delete(
      table,
      where: _sqfliteWhere(where),
      whereArgs: args.isEmpty ? null : args,
    );
  }

  @override
  Future<List<DbRow>> query(
    String table, {
    Map<String, Object?> where = const {},
    List<DbOrder> orderBy = const [],
    int? limit,
  }) {
    final args = whereArgs(where);
    return _executor.query(
      table,
      where: _sqfliteWhere(where),
      whereArgs: args.isEmpty ? null : args,
      orderBy: _sqfliteOrderBy(orderBy),
      limit: limit,
    );
  }
