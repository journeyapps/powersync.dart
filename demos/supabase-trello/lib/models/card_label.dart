import 'package:powersync/sqlite3.dart' as sqlite;

class CardLabel {
  final String id;

  final String cardId;

  final String boardId;

  final String workspaceId;

  final String boardLabelId;

  final DateTime dateCreated;

  CardLabel({
    required this.id,
    required this.cardId,
    required this.boardId,
    required this.workspaceId,
    required this.boardLabelId,
    required this.dateCreated,
  });

  factory CardLabel.fromRow(sqlite.Row row) {
    return CardLabel(
        id: row['id'],
        cardId: row['cardId'],
        boardId: row['boardId'],
        workspaceId: row['workspaceId'],
        boardLabelId: row['boardLabelId'],
        dateCreated: DateTime.parse(row['dateCreated']));
  }
}
