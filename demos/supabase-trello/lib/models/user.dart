import 'package:powersync/sqlite3.dart' as sqlite;

class TrelloUser {
  TrelloUser({
    required this.id,
    this.name,
    required this.email,
    required this.password,
  });

  final String id;

  final String? name;

  final String email;

  final String password;

  factory TrelloUser.fromRow(sqlite.Row row) {
    return TrelloUser(
        id: row['id'],
        name: row['name'],
        email: row['email'],
        password: row['password']);
  }
}
