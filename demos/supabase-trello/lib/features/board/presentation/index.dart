import 'package:flutter/material.dart';
import 'package:trelloappclone_flutter/features/carddetails/domain/card_detail_arguments.dart';
import 'package:trelloappclone_flutter/features/carddetails/presentation/index.dart';
import 'package:trelloappclone_flutter/utils/color.dart';
import 'package:trelloappclone_flutter/widgets/thirdparty/board_item.dart';
import 'package:trelloappclone_flutter/widgets/thirdparty/board_list.dart';
import 'package:trelloappclone_flutter/widgets/thirdparty/boardview.dart';
import 'package:trelloappclone_flutter/widgets/thirdparty/boardview_controller.dart';
import 'package:trelloappclone_flutter/models/listboard.dart';
import 'package:trelloappclone_flutter/models/card.dart';

import '../../../main.dart';
import '../../../utils/config.dart';
import '../../../utils/service.dart';
import '../../../utils/widgets.dart';
import '../domain/board_arguments.dart';
import 'boarditemobject.dart';
import 'boardlistobject.dart';

class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});

  @override
  State<BoardScreen> createState() => _BoardScreenState();

  static const routeName = '/board';
}

class _BoardScreenState extends State<BoardScreen> with Service {
  BoardViewController boardViewController = BoardViewController();
  bool showCard = false;
  bool show = false;
  List<BoardList> lists = [];
  final TextEditingController nameController = TextEditingController();
  Map<int, TextEditingController> textEditingControllers = {};
  Map<int, bool> showtheCard = {};
  int selectedList = 0;
  int selectedCard = 0;
  late double width;

  @override
  Widget build(BuildContext context) {
    width = MediaQuery.of(context).size.width * 0.7;
    final args = ModalRoute.of(context)!.settings.arguments as BoardArguments;
    trello.setSelectedBoard(args.board);
    trello.setSelectedWorkspace(args.workspace);

    // ignore: deprecated_member_use
    return WillPopScope(
        onWillPop: () async {
          Navigator.pushNamed(context, "/home");
          return false;
        },
        child: Scaffold(
          appBar: (!show && !showCard)
              ? AppBar(
                  backgroundColor: brandColor,
                  centerTitle: false,
                  title: Text(args.board.name),
                  actions: [
                    IconButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/boardmenu');
                        },
                        icon: const Icon(Icons.more_horiz))
                  ],
                )
              : AppBar(
                  leading: IconButton(
                      onPressed: () {
                        setState(() {
                          nameController.clear();
                          textEditingControllers[selectedList]!.clear();
                          show = false;
                          showCard = false;
                          showtheCard[selectedCard] = false;
                        });
                      },
                      icon: const Icon(Icons.close)),
                  title: Text((show) ? "Add list" : "Add card"),
                  centerTitle: false,
                  actions: [
                    IconButton(
                        onPressed: () {
                          if (show) {
                            addList(Listboard(
                                id: randomUuid(),
                                workspaceId: args.workspace.id,
                                boardId: args.board.id,
                                userId: trello.user.id,
                                name: nameController.text,
                                order: trello.lstbrd.length));
                            nameController.clear();
                            setState(() {
                              show = false;
                            });
                          } else {
                            addCard(Cardlist(
                                id: randomUuid(),
                                workspaceId: args.workspace.id,
                                listId: trello.lstbrd[selectedList].id,
                                userId: trello.user.id,
                                name:
                                    textEditingControllers[selectedList]!.text,
                                rank:
                                    trello.lstbrd[selectedList].cards!.length));
                            textEditingControllers[selectedList]!.clear();
                            setState(() {
                              showCard = false;
                              showtheCard[selectedCard] = false;
                            });
                          }
                        },
                        icon: const Icon(Icons.check))
                  ],
                ),
          body: Padding(
              padding: const EdgeInsets.all(10.0),
              child: StreamBuilder(
                  stream: getListsByBoardStream(args.board),
                  builder: (BuildContext context,
                      AsyncSnapshot<List<Listboard>> snapshot) {
                    if (snapshot.hasData) {
                      List<Listboard> listBoards =
                          snapshot.data as List<Listboard>;
                      return BoardView(
                        lists: loadBoardView(listBoards),
                        boardViewController: boardViewController,
                      );
                    }
                    return const SizedBox.shrink();
                  })),
        ));
  }

  Widget buildBoardItem(
      BoardItemObject itemObject, List<BoardListObject> data) {
    return BoardItem(
        onStartDragItem: (listIndex, itemIndex, state) {},
        onDropItem: (listIndex, itemIndex, oldListIndex, oldItemIndex, state) {
          // if listIndex is null, then item was dropped outside of list reset the state
          if (listIndex == null) {
            return;
          }

          if (itemIndex == null || itemIndex > data[listIndex].items!.length) {
            return;
          }

          // Move item to new list
          var item = data[oldListIndex!].items?[oldItemIndex!];
          data[oldListIndex].items!.removeAt(oldItemIndex!);
          data[listIndex].items!.insert(itemIndex, item!);

          var card = trello.lstbrd[oldListIndex].cards![oldItemIndex];

          // update card listId
          card.listId = trello.lstbrd[listIndex].id;
          updateCard(card);

          trello.lstbrd[oldListIndex].cards!.removeAt(oldItemIndex);
          trello.lstbrd[listIndex].cards!.insert(itemIndex, card);

          // reset rank based on index
          trello.lstbrd[listIndex].cards!.asMap().forEach((index, card) {
            card.rank = index;
            updateCard(card);
          });
        },
        onTapItem: (listIndex, itemIndex, state) {
          Navigator.pushNamed(context, CardDetails.routeName,
                  arguments: CardDetailArguments(
                      trello.lstbrd[listIndex].cards![itemIndex],
                      trello.selectedBoard,
                      trello.lstbrd[listIndex]))
              .then((value) => setState(() {}));
        },
        item: Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    itemObject.title!,
                  ),
                ),
              ),
              Wrap(
                children: <Widget>[
                  // Add a horizontal space
                  const SizedBox(width: 0),
                  // Example labels with colored Chips
                  ...itemObject.cardLabels!.map((cardLabel) => Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2), // Horizontal margin
                      child: LabelDiplay(
                          color: trello.selectedBoard.boardLabels!
                              .firstWhere((boardLabel) =>
                                  boardLabel.id == cardLabel.boardLabelId)
                              .color,
                          label: trello.selectedBoard.boardLabels!
                              .firstWhere((boardLabel) =>
                                  boardLabel.id == cardLabel.boardLabelId)
                              .title))),
                ],
              ),
              //Add icon to the column if card has description
              if (itemObject.hasDescription!)
                const Padding(
                  padding: EdgeInsets.fromLTRB(8, 2, 8, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(Icons.description, size: 16),
                  ),
                ),
            ])));
  }

  Widget _createBoardList(
      BoardListObject list, List<BoardListObject> data, int index) {
    List<BoardItem> items = [];
    for (int i = 0; i < list.items!.length; i++) {
      items.insert(i, buildBoardItem(list.items![i], data) as BoardItem);
    }

    textEditingControllers.putIfAbsent(index, () => TextEditingController());
    showtheCard.putIfAbsent(index, () => false);

    items.insert(
        list.items!.length,
        BoardItem(
          onTapItem: (listIndex, itemIndex, state) {
            setState(() {
              selectedList = listIndex;
              selectedCard = index;
              showCard = true;
              showtheCard[index] = true;
            });
          },
          item: (!showtheCard[index]!)
              ? ListTile(
                  leading: const Text.rich(TextSpan(
                    children: <InlineSpan>[
                      WidgetSpan(
                          child: Icon(
                        Icons.add,
                        size: 19,
                        color: whiteShade,
                      )),
                      WidgetSpan(
                        child: SizedBox(
                          width: 5,
                        ),
                      ),
                      TextSpan(
                          text: "Add card",
                          style: TextStyle(color: whiteShade)),
                    ],
                  )),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.image,
                      color: whiteShade,
                    ),
                    onPressed: () {},
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: TextField(
                    controller: textEditingControllers[index],
                    decoration: const InputDecoration(hintText: "Card name"),
                  ),
                ),
        ));

    return BoardList(
      onStartDragList: (listIndex) {},
      onTapList: (listIndex) async {},
      onDropList: (listIndex, oldListIndex) {
        var tmpList = data[oldListIndex!];

        data.removeAt(oldListIndex);
        data.insert(listIndex!, tmpList);

        updateListOrder(tmpList.listId!, listIndex);

        var movedList = trello.lstbrd[oldListIndex];

        trello.lstbrd.removeAt(oldListIndex);
        trello.lstbrd.insert(listIndex, movedList);

        // reset rank based on index
        trello.lstbrd.asMap().forEach((index, list) {
          updateListOrder(list.id, index);
        });
      },
      headerBackgroundColor: brandColor,
      backgroundColor: brandColor,
      header: [
        Expanded(
            child: Padding(
                padding: const EdgeInsets.all(5),
                child: ListTile(
                  leading: SizedBox(
                    width: 180,
                    child: Text(
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      maxLines: 2,
                      list.title!,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                  trailing: PopupMenuButton<String>(
                      child: const Icon(Icons.more_vert),
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(
                              child: ListTile(
                                enabled: false,
                                title: Text(listMenu[1]),
                              ),
                            ),
                            PopupMenuItem<String>(
                              child: ListTile(
                                enabled: false,
                                title: Text(listMenu[2]),
                              ),
                            ),
                            PopupMenuItem<String>(
                              child: ListTile(
                                enabled: false,
                                title: Text(listMenu[3]),
                              ),
                            ),
                            const PopupMenuItem<String>(
                                child: Divider(
                              height: 1,
                              thickness: 1,
                            )),
                            PopupMenuItem<String>(
                              child: ListTile(
                                enabled: false,
                                title: Text(listMenu[4]),
                                trailing:
                                    const Icon(Icons.keyboard_arrow_right),
                              ),
                            ),
                            const PopupMenuItem<String>(
                                child: Divider(
                              height: 1,
                              thickness: 1,
                            )),
                            PopupMenuItem<String>(
                              child: ListTile(
                                enabled: false,
                                title: Text(listMenu[5]),
                              ),
                            ),
                            PopupMenuItem<String>(
                              child: ListTile(
                                title: Text(listMenu[6]),
                                onTap: () {
                                  archiveCardsInList(trello.lstbrd[index])
                                      .then((numCardsArchived) {
                                    // ignore: use_build_context_synchronously
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        duration: const Duration(seconds: 2),
                                        margin: EdgeInsets.only(
                                          // ignore: use_build_context_synchronously
                                          bottom: MediaQuery.of(context)
                                                  .size
                                                  .height *
                                              0.1, // 10% from bottom
                                          right: 20,
                                          left: 20,
                                        ),
                                        content: Row(
                                          children: [
                                            const Icon(Icons.archive_outlined,
                                                color: brandColor),
                                            const SizedBox(width: 12),
                                            Text(
                                                '$numCardsArchived Cards Archived'),
                                          ],
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    // ignore: use_build_context_synchronously
                                    Navigator.of(context).pop();
                                  });
                                },
                              ),
                            ),
                            PopupMenuItem<String>(
                              child: ListTile(
                                enabled: false,
                                title: Text(listMenu[7]),
                              ),
                            ),
                          ]),
                ))),
      ],
      items: items,
    );
  }

  List<BoardListObject> generateBoardListObject(List<Listboard> lists) {
    final List<BoardListObject> listData = [];

    for (int i = 0; i < lists.length; i++) {
      listData.add(BoardListObject(
          title: lists[i].name,
          listId: lists[i].id,
          items: generateBoardItemObject(lists[i].cards!)));
    }

    return listData;
  }

  List<BoardItemObject> generateBoardItemObject(List<Cardlist> crds) {
    final List<BoardItemObject> items = [];
    for (int i = 0; i < crds.length; i++) {
      items.add(BoardItemObject(
          title: crds[i].name,
          cardLabels: crds[i].cardLabels,
          hasDescription: (crds[i].description != null) ? true : false));
    }
    return items;
  }

  // ignore: non_constant_identifier_names
  List<BoardList> loadBoardView(List<Listboard> Listboards) {
    List<BoardListObject> data = generateBoardListObject(Listboards);
    lists = [];

    for (int i = 0; i < data.length; i++) {
      lists.add(_createBoardList(data[i], data, i) as BoardList);
    }

    lists.insert(
        data.length,
        BoardList(
          items: [
            BoardItem(
                item: GestureDetector(
              onTap: () {
                setState(() {
                  show = true;
                });
              },
              child: Container(
                  alignment: Alignment.center,
                  width: width,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10.0),
                    color: brandColor,
                  ),
                  child: (!show)
                      ? const Text(
                          "Add list",
                          style: TextStyle(color: whiteShade),
                        )
                      : Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: TextField(
                            controller: nameController,
                            decoration:
                                const InputDecoration(hintText: "List name"),
                          ),
                        )),
            ))
          ],
        ));
    return lists;
  }
}
