import 'package:flutter/material.dart';
import 'package:trelloappclone_flutter/main.dart';
import 'package:trelloappclone_flutter/models/card_label.dart';
import '../../../utils/service.dart';

class EditLabels extends StatefulWidget {
  final String cardId;

  const EditLabels({super.key, required this.cardId});

  @override
  State<EditLabels> createState() => _EditLabelsState();
}

class _EditLabelsState extends State<EditLabels> with Service {
  late List<bool> switchStates; // List to track the state of each switch

  @override
  void initState() {
    super.initState();
    // Initialize the switchStates list with default values (e.g., all false)
    switchStates =
        List<bool>.filled(trello.selectedBoard.boardLabels!.length, false);
    // Set the switchStates list to true for each label that is already on the card
    for (int i = 0; i < trello.selectedBoard.boardLabels!.length; i++) {
      for (int j = 0; j < trello.selectedCard!.cardLabels!.length; j++) {
        if (trello.selectedBoard.boardLabels![i].id ==
            trello.selectedCard!.cardLabels![j].boardLabelId) {
          switchStates[i] = true;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Edit labels"),
      content: SizedBox(
        height: 200,
        child: Column(children: buildWidget()),
      ),
    );
  }

  List<Widget> buildWidget() {
    // Create and initialize a list of TextEditingControllers
    List<TextEditingController> controllers = trello.selectedBoard.boardLabels!
        .map((label) => TextEditingController(text: label.title))
        .toList();

    List<Widget> labelContainers = [];
    for (int i = 0; i < trello.selectedBoard.boardLabels!.length; i++) {
      labelContainers.add(Padding(
        padding: const EdgeInsets.only(bottom: 5.0),
        child: Container(
          height: 35,
          decoration: BoxDecoration(
            color: Color(int.parse(trello.selectedBoard.boardLabels![i].color,
                    radix: 16) +
                0xFF000000),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: TextField(
                    controller: controllers[i],
                    onChanged: (value) {
                      // Update the label title in the database
                      trello.selectedBoard.boardLabels![i].title = value;
                      updateBoardLabel(trello.selectedBoard.boardLabels![i]);
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(5.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: false,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Align(
                  alignment: Alignment.center,
                  child: Transform.scale(
                    scale: 0.75, // Adjust the scale to make the switch smaller
                    child: Switch(
                      value: switchStates[
                          i], // You might want to manage this state properly
                      onChanged: (bool value) async {
                        // Handle toggle logic
                        if (value) {
                          // Add label to card via service.data
                          var cardLabel = await addCardLabel(
                              CardLabel(
                                  id: randomUuid(),
                                  workspaceId: trello.selectedBoard
                                      .boardLabels![i].workspaceId,
                                  boardLabelId:
                                      trello.selectedBoard.boardLabels![i].id,
                                  boardId: trello
                                      .selectedBoard.boardLabels![i].boardId,
                                  cardId: widget.cardId,
                                  dateCreated: DateTime.now()),
                              trello.selectedBoard.boardLabels![i]);
                          trello.selectedCard!.cardLabels!.add(cardLabel);
                        } else {
                          // Remove label from card
                          deleteCardLabel(widget.cardId,
                              trello.selectedBoard.boardLabels![i]);
                          trello.selectedCard!.cardLabels!.removeWhere(
                              (element) =>
                                  element.boardLabelId ==
                                  trello.selectedBoard.boardLabels![i].id);
                        }
                        setState(() {
                          switchStates[i] =
                              value; // Update the state when the switch is toggled
                        });
                      },
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ));
    }
    return labelContainers;
  }
}
