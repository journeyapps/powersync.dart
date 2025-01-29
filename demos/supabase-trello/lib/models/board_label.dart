import 'package:powersync/sqlite3.dart' as sqlite;

class BoardLabel {
  final String id;

  final String boardId;

  final String workspaceId;

  late String title;

  final String color;

  final DateTime dateCreated;

  BoardLabel({
    required this.id,
    required this.boardId,
    required this.workspaceId,
    required this.title,
    required this.color,
    required this.dateCreated,
  });

  factory BoardLabel.fromRow(sqlite.Row row) {
    return BoardLabel(
        id: row['id'],
        boardId: row['boardId'],
        workspaceId: row['workspaceId'],
        title: row['title'],
        color: row['color'],
        dateCreated: DateTime.parse(row['dateCreated']));
  }
}
