import 'package:powersync/sqlite3.dart' as sqlite;

class Checklist {
  Checklist({
    required this.id,
    required this.workspaceId,
    required this.cardId,
    required this.name,
    required this.status,
  });

  final String id;

  final String workspaceId;

  final String cardId;

  final String name;

  bool status;

  factory Checklist.fromRow(sqlite.Row row) {
    return Checklist(
        id: row['id'],
        workspaceId: row['workspaceId'],
        cardId: row['cardId'],
        name: row['name'],
        status: row['status'] == 1);
  }
}
