import 'package:powersync/sqlite3.dart' as sqlite;

import 'member.dart';

class Workspace {
  Workspace({
    required this.id,
    required this.userId,
    required this.name,
    required this.description,
    required this.visibility,
    this.members,
  });

  final String id;

  final String userId;

  final String name;

  final String description;

  final String visibility;

  List<Member>? members;

  factory Workspace.fromRow(sqlite.Row row) {
    return Workspace(
        id: row['id'],
        userId: row['userId'],
        name: row['name'],
        description: row['description'],
        visibility: row['visibility'],
        members: []);
  }
}
