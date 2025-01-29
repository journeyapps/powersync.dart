import 'package:flutter/material.dart';
import 'package:trelloappclone_flutter/models/listboard.dart';
import 'package:trelloappclone_flutter/models/board.dart';
import 'package:trelloappclone_flutter/models/workspace.dart';
import 'package:trelloappclone_flutter/models/user.dart';
import 'package:trelloappclone_flutter/models/card.dart';

import 'config.dart';

class TrelloProvider extends ChangeNotifier {
  late TrelloUser _user;
  TrelloUser get user => _user;

  List<Workspace> _workspaces = [];
  List<Workspace> get workspaces => _workspaces;

  List<Board> _boards = [];
  List<Board> get boards => _boards;

  String _selectedBackground = backgrounds[0];
  String get selectedBackground => _selectedBackground;

  List<Listboard> _lstbrd = [];
  List<Listboard> get lstbrd => _lstbrd;

  late Board _selectedBoard;
  Board get selectedBoard => _selectedBoard;

  late Workspace _selectedWorkspace;
  Workspace get selectedWorkspace => _selectedWorkspace;

  Cardlist? _selectedCard;
  Cardlist? get selectedCard => _selectedCard;

  void setUser(TrelloUser user) {
    _user = user;
    notifyListeners();
  }

  void setWorkspaces(List<Workspace> wkspcs) {
    _workspaces = wkspcs;
    notifyListeners();
  }

  void setBoards(List<Board> brd) {
    _boards = brd;
    notifyListeners();
  }

  void setSelectedBg(String slctbg) {
    _selectedBackground = slctbg;
    notifyListeners();
  }

  void setListBoard(List<Listboard> lstbrd) {
    _lstbrd = lstbrd;
    notifyListeners();
  }

  void setSelectedBoard(Board brd) {
    _selectedBoard = brd;
    notifyListeners();
  }

  void setSelectedWorkspace(Workspace workspace) {
    _selectedWorkspace = workspace;
    notifyListeners();
  }

  void setSelectedCard(Cardlist? card) {
    _selectedCard = card;
    notifyListeners();
  }
}
