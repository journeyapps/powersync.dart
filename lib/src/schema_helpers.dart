import 'package:sqlite_async/sqlite3_common.dart';
import 'package:sqlite_async/utils.dart';

import 'schema.dart';

const String maxOpId = '9223372036854775807';

final invalidSqliteCharacters = RegExp(r'''["'%,\.#\s\[\]]''');

/// Since view names don't have a static prefix, mark views as auto-generated by adding a comment.
final _autoGenerated = '-- powersync-auto-generated';

String createViewStatement(Table table) {
  final columnNames =
      table.columns.map((column) => quoteIdentifier(column.name)).join(', ');

  if (table.insertOnly) {
    final nulls = table.columns.map((column) => 'NULL').join(', ');
    return 'CREATE VIEW ${quoteIdentifier(table.viewName)}("id", $columnNames) AS SELECT NULL, $nulls WHERE 0 $_autoGenerated';
  }
  final select = table.columns.map(mapColumn).join(', ');
  return 'CREATE VIEW ${quoteIdentifier(table.viewName)}("id", $columnNames) AS SELECT "id", $select FROM ${quoteIdentifier(table.internalName)} $_autoGenerated';
}

String mapColumn(Column column) {
  return "CAST(json_extract(data, ${quoteJsonPath(column.name)}) as ${column.type.sqlite})";
}

List<String> createViewTriggerStatements(Table table) {
  if (table.localOnly) {
    return createViewTriggerStatementsLocal(table);
  } else if (table.insertOnly) {
    return createViewTriggerStatementsInsert(table);
  }
  final viewName = table.viewName;
  final type = table.name;
  final internalNameE = quoteIdentifier(table.internalName);

  final jsonFragment = table.columns
      .map((column) =>
          "${quoteString(column.name)}, NEW.${quoteIdentifier(column.name)}")
      .join(', ');
  final jsonFragmentOld = table.columns
      .map((column) =>
          "${quoteString(column.name)}, OLD.${quoteIdentifier(column.name)}")
      .join(', ');
  // Names in alphabetical order
  return [
    """
CREATE TRIGGER ${quoteIdentifier('ps_view_delete_$viewName')}
INSTEAD OF DELETE ON ${quoteIdentifier(viewName)}
FOR EACH ROW
BEGIN
  DELETE FROM $internalNameE WHERE id = OLD.id;
  INSERT INTO ps_crud(tx_id, data) SELECT current_tx, json_object('op', 'DELETE', 'type', ${quoteString(type)}, 'id', OLD.id) FROM ps_tx WHERE id = 1;
  INSERT INTO ps_oplog(bucket, op_id, op, row_type, row_id, hash, superseded)
    SELECT '\$local',
           1,
           'REMOVE',
           ${quoteString(type)},
           OLD.id,
           0,
           0;
  INSERT OR REPLACE INTO ps_buckets(name, pending_delete, last_op, target_op) VALUES('\$local', 1, 0, $maxOpId);
END""",
    """
CREATE TRIGGER ${quoteIdentifier('ps_view_insert_$viewName')}
INSTEAD OF INSERT ON ${quoteIdentifier(viewName)}
FOR EACH ROW
BEGIN
  SELECT CASE
    WHEN (NEW.id IS NULL)
    THEN RAISE (FAIL, 'id is required')
  END;
  INSERT INTO $internalNameE(id, data)
    SELECT NEW.id, json_object($jsonFragment);
  INSERT INTO ps_crud(tx_id, data) SELECT current_tx, json_object('op', 'PUT', 'type', ${quoteString(type)}, 'id', NEW.id, 'data', json(powersync_diff('{}', json_object($jsonFragment)))) FROM ps_tx WHERE id = 1;
  INSERT INTO ps_oplog(bucket, op_id, op, row_type, row_id, hash, superseded)
    SELECT '\$local',
           1,
           'REMOVE',
           ${quoteString(type)},
           NEW.id,
           0,
           0;
  INSERT OR REPLACE INTO ps_buckets(name, pending_delete, last_op, target_op) VALUES('\$local', 1, 0, $maxOpId);
END""",
    """
CREATE TRIGGER ${quoteIdentifier('ps_view_update_$viewName')}
INSTEAD OF UPDATE ON ${quoteIdentifier(viewName)}
FOR EACH ROW
BEGIN
  SELECT CASE
    WHEN (OLD.id != NEW.id)
    THEN RAISE (FAIL, 'Cannot update id')
  END;
  UPDATE $internalNameE
        SET data = json_object($jsonFragment)
        WHERE id = NEW.id;
  INSERT INTO ps_crud(tx_id, data) SELECT current_tx, json_object('op', 'PATCH', 'type', ${quoteString(type)}, 'id', NEW.id, 'data', json(powersync_diff(json_object($jsonFragmentOld), json_object($jsonFragment)))) FROM ps_tx WHERE id = 1;
  INSERT INTO ps_oplog(bucket, op_id, op, row_type, row_id, hash, superseded)
    SELECT '\$local',
           1,
           'REMOVE',
           ${quoteString(type)},
           NEW.id,
           0,
           0;
  INSERT OR REPLACE INTO ps_buckets(name, pending_delete, last_op, target_op) VALUES('\$local', 1, 0, $maxOpId);
END"""
  ];
}

List<String> createViewTriggerStatementsLocal(Table table) {
  final viewName = table.viewName;
  final internalNameE = quoteIdentifier(table.internalName);

  final jsonFragment = table.columns
      .map((column) =>
          "${quoteString(column.name)}, NEW.${quoteIdentifier(column.name)}")
      .join(', ');
  // Names in alphabetical order
  return [
    """
CREATE TRIGGER ${quoteIdentifier('ps_view_delete_$viewName')}
INSTEAD OF DELETE ON ${quoteIdentifier(viewName)}
FOR EACH ROW
BEGIN
  DELETE FROM $internalNameE WHERE id = OLD.id;
END""",
    """
CREATE TRIGGER ${quoteIdentifier('ps_view_insert_$viewName')}
INSTEAD OF INSERT ON ${quoteIdentifier(viewName)}
FOR EACH ROW
BEGIN
  INSERT INTO $internalNameE(id, data)
    SELECT NEW.id, json_object($jsonFragment);
END""",
    """
CREATE TRIGGER ${quoteIdentifier('ps_view_update_$viewName')}
INSTEAD OF UPDATE ON ${quoteIdentifier(viewName)}
FOR EACH ROW
BEGIN
  SELECT CASE
    WHEN (OLD.id != NEW.id)
    THEN RAISE (FAIL, 'Cannot update id')
  END;
  UPDATE $internalNameE
        SET data = json_object($jsonFragment)
        WHERE id = NEW.id;
END"""
  ];
}

List<String> createViewTriggerStatementsInsert(Table table) {
  final type = table.name;
  final viewName = table.viewName;

  final jsonFragment = table.columns
      .map((column) =>
          "${quoteString(column.name)}, NEW.${quoteIdentifier(column.name)}")
      .join(', ');
  return [
    """
CREATE TRIGGER ${quoteIdentifier('ps_view_insert_$viewName')}
INSTEAD OF INSERT ON ${quoteIdentifier(viewName)}
FOR EACH ROW
BEGIN
  INSERT INTO ps_crud(tx_id, data) SELECT current_tx, json_object('op', 'PUT', 'type', ${quoteString(type)}, 'id', NEW.id, 'data', json(powersync_diff('{}', json_object($jsonFragment)))) FROM ps_tx WHERE id = 1;
END"""
  ];
}

/// Sync the schema to the local database.
/// Must be wrapped in a transaction.
void updateSchema(CommonDatabase db, Schema schema) {
  for (var table in schema.tables) {
    table.validate();
  }

  _createTablesAndIndexes(db, schema);

  final existingViewRows = db.select(
      "SELECT name FROM sqlite_master WHERE type='view' AND sql GLOB '*$_autoGenerated'");

  Set<String> toRemove = {for (var row in existingViewRows) row['name']};

  for (var table in schema.tables) {
    toRemove.remove(table.name);

    var createViewOp = createViewStatement(table);
    var triggers = createViewTriggerStatements(table);
    var existingRows = db.select(
        "SELECT sql FROM sqlite_master WHERE (type = 'view' AND name = ?) OR (type = 'trigger' AND tbl_name = ?) ORDER BY type DESC, name ASC",
        [table.name, table.name]);
    if (existingRows.isNotEmpty) {
      final dbSql = existingRows.map((row) => row['sql']).join('\n\n');
      final generatedSql =
          [createViewOp, for (var trigger in triggers) trigger].join('\n\n');
      if (dbSql == generatedSql) {
        // No change - keep it.
        continue;
      } else {
        // View and/or triggers changed - delete and re-create.
        db.execute('DROP VIEW ${quoteIdentifier(table.name)}');
      }
    } else {
      // New - create
    }
    db.execute(createViewOp);
    for (final op in triggers) {
      db.execute(op);
    }
  }

  for (var name in toRemove) {
    db.execute('DROP VIEW ${quoteIdentifier(name)}');
  }
}

/// Sync the schema to the local database.
///
/// Does not create triggers or temporary views.
///
/// Must be wrapped in a transaction.
void _createTablesAndIndexes(CommonDatabase db, Schema schema) {
  // Make sure to refresh tables in the same transaction as updating them
  final existingTableRows = db.select(
      "SELECT name FROM sqlite_master WHERE type='table' AND name GLOB 'ps_data_*'");
  final existingIndexRows = db.select(
      "SELECT name, sql FROM sqlite_master WHERE type='index' AND name GLOB 'ps_data_*'");

  final Set<String> remainingTables = {};
  final Map<String, String> remainingIndexes = {};
  for (final row in existingTableRows) {
    remainingTables.add(row['name'] as String);
  }
  for (final row in existingIndexRows) {
    remainingIndexes[row['name'] as String] = row['sql'] as String;
  }

  for (final table in schema.tables) {
    if (table.insertOnly) {
      // Does not have a physical table
      continue;
    }
    final tableName = table.internalName;
    final exists = remainingTables.contains(tableName);
    remainingTables.remove(tableName);
    if (exists) {
      continue;
    }

    db.execute("""CREATE TABLE ${quoteIdentifier(tableName)}
    (
    id   TEXT PRIMARY KEY NOT NULL,
    data TEXT
    )""");

    if (!table.localOnly) {
      db.execute("""INSERT INTO ${quoteIdentifier(tableName)}(id, data)
    SELECT id, data
    FROM ps_untyped
    WHERE type = ?""", [table.name]);
      db.execute("""DELETE
    FROM ps_untyped
    WHERE type = ?""", [table.name]);
    }

    for (final index in table.indexes) {
      final fullName = index.fullName(table);
      final sql = index.toSqlDefinition(table);
      if (remainingIndexes.containsKey(fullName)) {
        final existingSql = remainingIndexes[fullName];
        if (existingSql == sql) {
          continue;
        } else {
          db.execute('DROP INDEX ${quoteIdentifier(fullName)}');
        }
      }
      db.execute(sql);
    }
  }

  for (final indexName in remainingIndexes.keys) {
    db.execute('DROP INDEX ${quoteIdentifier(indexName)}');
  }

  for (final tableName in remainingTables) {
    final typeMatch = RegExp("^ps_data__(.+)\$").firstMatch(tableName);
    if (typeMatch != null) {
      // Not local-only
      final type = typeMatch[1];
      db.execute(
          'INSERT INTO ps_untyped(type, id, data) SELECT ?, id, data FROM ${quoteIdentifier(tableName)}',
          [type]);
    }
    db.execute('DROP TABLE ${quoteIdentifier(tableName)}');
  }
}

String? friendlyTableName(String table) {
  final re = RegExp(r"^ps_data__(.+)$");
  final re2 = RegExp(r"^ps_data_local__(.+)$");
  final match = re.firstMatch(table) ?? re2.firstMatch(table);
  return match?.group(1);
}
