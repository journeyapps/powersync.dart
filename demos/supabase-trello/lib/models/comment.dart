import 'package:powersync/sqlite3.dart' as sqlite;

class Comment {
  Comment({
    required this.id,
    required this.workspaceId,
    required this.cardId,
    required this.userId,
    required this.description,
  });

  final String id;

  final String workspaceId;

  final String cardId;

  final String userId;

  final String description;

  factory Comment.fromRow(sqlite.Row row) {
    return Comment(
        id: row['id'],
        workspaceId: row['workspaceId'],
        cardId: row['cardId'],
        userId: row['userId'],
        description: row['description']);
  }
}
