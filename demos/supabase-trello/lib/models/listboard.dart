import 'package:powersync/sqlite3.dart' as sqlite;
import 'card.dart';

class Listboard {
  Listboard({
    required this.id,
    required this.workspaceId,
    required this.boardId,
    required this.userId,
    required this.name,
    this.archived,
    this.cards,
    required this.order,
  });

  final String id;

  final String workspaceId;

  final String boardId;

  final String userId;

  final String name;

  final bool? archived;

  final int order;

  List<Cardlist>? cards;

  factory Listboard.fromRow(sqlite.Row row) {
    return Listboard(
        id: row['id'],
        workspaceId: row['workspaceId'],
        boardId: row['boardId'],
        userId: row['userId'],
        name: row['name'],
        archived: row['archived'] == 1,
        order: row['listOrder'],
        cards: []);
  }
}
