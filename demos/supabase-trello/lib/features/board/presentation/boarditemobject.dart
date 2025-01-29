import 'package:trelloappclone_flutter/models/card_label.dart';

class BoardItemObject {
  String? title;
  bool? hasDescription;
  List<CardLabel>? cardLabels;

  BoardItemObject({this.title, this.hasDescription, this.cardLabels}) {
    title ??= "";
    hasDescription ??= false;
    cardLabels ??= [];
  }
}
