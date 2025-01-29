import 'package:powersync/sqlite3.dart' as sqlite;

class Activity {
  final String id;
  final String workspaceId;

  final String? boardId;

  final String userId;

  final String? cardId;

  final String description;

  final DateTime dateCreated;

  Activity({
    required this.id,
    required this.workspaceId,
    this.boardId,
    required this.userId,
    this.cardId,
    required this.description,
    required this.dateCreated,
  });

  factory Activity.fromRow(sqlite.Row row) {
    return Activity(
        id: row['id'],
        workspaceId: row['workspaceId'],
        boardId: row['boardId'],
        userId: row['userId'],
        cardId: row['cardId'],
        description: row['description'],
        dateCreated: DateTime.parse(row['dateCreated']));
  }
}
