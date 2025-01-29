import 'boarditemobject.dart';

class BoardListObject {
  String? title;
  String? listId;
  List<BoardItemObject>? items;

  BoardListObject({this.title, this.listId, this.items}) {
    listId ??= "0";
    title ??= "";
    items ??= [];
  }
}
