import 'package:flutter/material.dart';
import 'package:trelloappclone_flutter/features/activity/presentation/index.dart';
import 'package:trelloappclone_flutter/models/checklist.dart';
import 'package:trelloappclone_flutter/utils/color.dart';
import 'package:trelloappclone_flutter/main.dart';

import '../../../utils/service.dart';
import '../../../utils/widgets.dart';
import '../../editlabels/presentation/index.dart';
import '../../viewmembers/presentation/index.dart';
import '../domain/card_detail_arguments.dart';

class CardDetails extends StatefulWidget {
  const CardDetails({super.key});

  @override
  State<CardDetails> createState() => _CardDetailsState();

  static const routeName = '/carddetail';
}

class _CardDetailsState extends State<CardDetails> with Service {
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController checklistController = TextEditingController();
  bool showChecklist = false;
  bool addCardDescription = false;
  bool editCardName = false;
  Map<int, bool> checked = {};

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as CardDetailArguments;

    trello.setSelectedCard(args.crd);
    descriptionController.text = args.crd.description ?? " ";
    nameController.text = args.crd.name;

    return Scaffold(
      appBar: (showChecklist || addCardDescription || editCardName)
          ? AppBar(
              leading: IconButton(
                onPressed: () {
                  setState(() {
                    showChecklist = false;
                    addCardDescription = false;
                    editCardName = false;
                  });
                },
                icon: const Icon(Icons.close, size: 30),
              ),
              title: Text(() {
                if (showChecklist) {
                  return "Add Checklist";
                } else if (addCardDescription) {
                  return "Add card description";
                } else if (editCardName) {
                  return "Edit card name";
                } else {
                  return "";
                }
              }()),
              actions: [
                  IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: () {
                      if (showChecklist) {
                        createChecklist(Checklist(
                            id: randomUuid(),
                            workspaceId: args.crd.workspaceId,
                            cardId: args.crd.id,
                            name: checklistController.text,
                            status: false));
                        checklistController.clear();
                        setState(() {
                          showChecklist = false;
                        });
                      } else if (addCardDescription || editCardName) {
                        if (addCardDescription &&
                            descriptionController.text.isNotEmpty) {
                          args.crd.description = descriptionController.text;
                        }

                        if (editCardName && nameController.text.isNotEmpty) {
                          args.crd.name = nameController.text;
                        }

                        updateCard(args.crd);
                        descriptionController.clear();
                        nameController.clear();
                        setState(() {
                          addCardDescription = false;
                          editCardName = false;
                        });
                      }
                    },
                  )
                ])
          : AppBar(
              leading: IconButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.close, size: 30),
              ),
              actions: [
                  PopupMenuButton<Text>(
                    itemBuilder: (context) {
                      return [
                        PopupMenuItem(
                          onTap: () =>
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                            showDialog<String>(
                                context: context,
                                builder: (BuildContext context) => AlertDialog(
                                      title: const Text('Delete Card'),
                                      content: const Text(
                                          'Are you sure you want to delete this card?'),
                                      actions: <Widget>[
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, 'Cancel'),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () => {
                                            deleteCard(args.crd),
                                            // Remove popup
                                            Navigator.pop(context, 'Delete'),
                                            // Go one view back
                                            Navigator.pop(context, 'Delete'),
                                          },
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ));
                          }),
                          value: const Text("Delete Card"),
                          child: const ListTile(
                            leading: Icon(Icons.delete),
                            title: Text(
                              "Delete Card",
                            ),
                          ),
                        ),
                      ];
                    },
                  )
                  // IconButton(
                  //   icon: const Icon(Icons.more_vert),
                  //   onPressed: () {},
                  // )
                ]),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ListTile(
              title: TextField(
                style: const TextStyle(
                  fontSize: 20.0, // Set your desired font size here
                ),
                controller: nameController,
                onTap: () {
                  setState(() {
                    editCardName = true;
                  });
                },
                decoration: const InputDecoration(hintText: "Edit card name"),
              ),
            ),
            RichText(
                text: TextSpan(
                    text: args.brd.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: themeColor),
                    children: <TextSpan>[
                  const TextSpan(
                      text: ' in list ', style: TextStyle(fontSize: 12)),
                  TextSpan(text: args.lst.name)
                ])),
            const Padding(
              padding: EdgeInsets.only(top: 8.0, bottom: 8.0),
              child: Text(
                "Quick actions",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8.0, right: 8.0),
              child: Row(
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.4,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          showChecklist = true;
                        });
                      },
                      label: const Text("Add Checklist"),
                      icon: const CircleAvatar(
                        backgroundColor: brandColor,
                        radius: 15,
                        child: Icon(Icons.checklist),
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.4,
                    child: ElevatedButton.icon(
                      onPressed: null,
                      label: const Text("Add Attachment"),
                      icon: const CircleAvatar(
                        backgroundColor: brandColor,
                        radius: 15,
                        child: Icon(Icons.attachment),
                      ),
                    ),
                  )
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.short_text),
              title: TextField(
                controller: descriptionController,
                keyboardType: TextInputType.multiline,
                minLines: 1,
                maxLines: 1024,
                onTap: () {
                  setState(() {
                    addCardDescription = true;
                  });
                },
                decoration:
                    const InputDecoration(hintText: "Add card description"),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.label),
              title: Row(
                children: <Widget>[
                  const Text("Labels"),
                  // Add a horizontal space
                  const SizedBox(width: 8),
                  // Example labels with colored Chips
                  ...trello.selectedCard!.cardLabels!.map(
                    (cardLabel) => Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4), // Horizontal margin
                        child: LabelDiplay(
                            color: trello.selectedBoard.boardLabels!
                                .firstWhere((boardLabel) =>
                                    boardLabel.id == cardLabel.boardLabelId)
                                .color,
                            label: trello.selectedBoard.boardLabels!
                                .firstWhere((boardLabel) =>
                                    boardLabel.id == cardLabel.boardLabelId)
                                .title)),
                  ),
                ],
              ),
              onTap: () {
                final result = showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return EditLabels(cardId: args.crd.id);
                    });

                result.then((value) {
                  setState(() {});
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text("Members"),
              onTap: () {
                showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return const ViewMembers();
                    });
              },
            ),
            ListTile(
              leading: const Icon(Icons.date_range_outlined),
              title: const Text("Start date"),
              onTap: () {},
            ),
            ListTile(
              leading: const Text("Checklist"),
              trailing: IconButton(
                  onPressed: () {
                    setState(() {
                      deleteChecklist(args.crd);
                    });
                  },
                  icon: const Icon(Icons.delete)),
            ),
            FutureBuilder(
                future: getChecklists(args.crd),
                builder: ((context, snapshot) {
                  if (snapshot.hasData) {
                    List<Checklist> children = snapshot.data as List<Checklist>;

                    if (children.isNotEmpty) {
                      return Column(children: buildChecklists(children));
                    }
                  }
                  return const SizedBox.shrink();
                })),
            Visibility(
              visible: showChecklist,
              child: TextField(
                controller: checklistController,
              ),
            ),
            const Text("Activity"),
            Activities(args.crd)
          ]),
        ),
      ),
      //TODO: Add this back in when we get comments working properly
      // bottomNavigationBar: Container(
      //   padding: const EdgeInsets.only(bottom: 5.0),
      //   color: whiteShade,
      //   width: MediaQuery.of(context).size.width * 0.8,
      //   height: 80,
      //   child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      //     const CircleAvatar(),
      //     SizedBox(
      //       width: MediaQuery.of(context).size.width * 0.7,
      //       child: TextField(
      //         decoration: InputDecoration(
      //             hintText: "Add comment",
      //             suffix: IconButton(
      //                 onPressed: () {}, icon: const Icon(Icons.send))),
      //       ),
      //     ),
      //     IconButton(onPressed: () {}, icon: const Icon(Icons.attachment))
      //   ]),
      // ),
    );
  }

  List<Widget> buildChecklists(List<Checklist> chcklst) {
    List<Widget> lists = [];

    for (int i = 0; i < chcklst.length; i++) {
      checked.putIfAbsent(i, () => false);
      checked[i] = chcklst[i].status;
      lists.add(
        CheckboxListTile(
          title: Text(chcklst[i].name),
          value: checked[i],
          onChanged: (bool? value) {
            setState(() {
              checked[i] = value!;
            });
            chcklst[i].status = value!;
            updateChecklist(chcklst[i]);
          },
        ),
      );
    }

    return lists;
  }
}
