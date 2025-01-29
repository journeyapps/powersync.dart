import 'package:powersync/sqlite3.dart' as sqlite;
import 'package:trelloappclone_flutter/models/board_label.dart';

class Board {
  Board(
      {required this.id,
      required this.workspaceId,
      required this.userId,
      required this.name,
      this.description,
      required this.visibility,
      required this.background,
      this.starred,
      this.enableCover,
      this.watch,
      this.availableOffline,
      this.label,
      this.emailAddress,
      this.commenting,
      this.memberType,
      this.pinned,
      this.selfJoin,
      this.close,
      this.boardLabels});

  final String id;

  final String workspaceId;

  final String userId;

  final String name;

  final String? description;

  final String visibility;

  final String background;

  final bool? starred;

  final bool? enableCover;

  final bool? watch;

  bool? availableOffline;

  final String? label;

  final String? emailAddress;

  final int? commenting;

  final int? memberType;

  final bool? pinned;

  final bool? selfJoin;

  final bool? close;

  List<BoardLabel>? boardLabels;

  factory Board.fromRow(sqlite.Row row) {
    return Board(
        id: row['id'],
        workspaceId: row['workspaceId'],
        userId: row['userId'],
        name: row['name'],
        description: row['description'],
        visibility: row['visibility'],
        background: row['background'],
        starred: row['starred'] == 1,
        enableCover: row['enableCover'] == 1,
        watch: row['watch'] == 1,
        availableOffline: row['availableOffline'] == 1,
        label: row['label'],
        emailAddress: row['emailAddress'],
        commenting: row['commenting'],
        memberType: row['memberType'],
        pinned: row['pinned'] == 1,
        selfJoin: row['selfJoin'] == 1,
        close: row['close'] == 1,
        boardLabels: []);
  }
}
