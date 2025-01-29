import 'package:powersync/sqlite3.dart' as sqlite;
import 'package:trelloappclone_flutter/models/card_label.dart';

class Cardlist {
  Cardlist({
    required this.id,
    required this.workspaceId,
    required this.listId,
    required this.userId,
    required this.name,
    this.description,
    this.startDate,
    this.dueDate,
    required this.rank,
    this.attachment,
    this.archived,
    this.checklist,
    this.comments,
    this.cardLabels,
  });

  final String id;

  final String workspaceId;

  String listId;

  final String userId;

  String name;

  String? description;

  final DateTime? startDate;

  final DateTime? dueDate;

  int rank;

  final bool? attachment;

  final bool? archived;

  final bool? checklist;

  final bool? comments;

  List<CardLabel>? cardLabels;

  factory Cardlist.fromRow(sqlite.Row row) {
    return Cardlist(
        id: row['id'],
        workspaceId: row['workspaceId'],
        listId: row['listId'],
        userId: row['userId'],
        name: row['name'],
        description: row['description'],
        startDate:
            row['startDate'] != null ? DateTime.parse(row['startDate']) : null,
        dueDate: row['dueDate'] != null ? DateTime.parse(row['dueDate']) : null,
        rank: row['rank'],
        attachment: row['attachment'] == 1,
        archived: row['archived'] == 1,
        checklist: row['checklist'] == 1,
        comments: row['comments'] == 1,
        cardLabels: []);
  }
}
