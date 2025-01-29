import 'package:trelloappclone_flutter/models/board.dart';
import 'package:trelloappclone_flutter/models/card.dart';
import 'package:trelloappclone_flutter/models/listboard.dart';

class CardDetailArguments {
  final Cardlist crd;
  final Board brd;
  final Listboard lst;

  CardDetailArguments(this.crd, this.brd, this.lst);
}
