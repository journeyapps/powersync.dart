import 'package:trelloappclone_flutter/models/board.dart';
import 'package:trelloappclone_flutter/models/workspace.dart';

class BoardArguments {
  final Board board;
  final Workspace workspace;

  BoardArguments(this.board, this.workspace);
}
