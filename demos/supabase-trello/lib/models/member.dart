import 'package:powersync/sqlite3.dart' as sqlite;

class Member {
  Member({
    required this.id,
    required this.workspaceId,
    required this.userId,
    required this.name,
    required this.role,
  });

  final String id;

  final String workspaceId;

  final String userId;

  final String name;

  final String role;

  factory Member.fromRow(sqlite.Row row) {
    return Member(
        id: row['id'],
        workspaceId: row['workspaceId'],
        userId: row['userId'],
        name: row['name'],
        role: row['role']);
  }
}
