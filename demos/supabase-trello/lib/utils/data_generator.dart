// ignore_for_file: use_build_context_synchronously

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:random_name_generator/random_name_generator.dart';
import 'package:trelloappclone_flutter/utils/color.dart';
import 'package:trelloappclone_flutter/utils/config.dart';
import 'package:trelloappclone_flutter/utils/service.dart';
import 'package:trelloappclone_flutter/utils/trello_provider.dart';
import 'package:trelloappclone_flutter/models/listboard.dart';
import 'package:trelloappclone_flutter/models/board.dart';
import 'package:trelloappclone_flutter/models/workspace.dart';
import 'package:trelloappclone_flutter/models/card.dart';
import 'package:trelloappclone_flutter/models/checklist.dart';
import 'package:trelloappclone_flutter/models/comment.dart';

/// This class generates an example workspace with some boards, cards, etc for each
class DataGenerator with Service {
  Random random = Random();
  var randomNames = RandomNames(Zone.us);

  List<String> _generateBoardNames(String workspaceName) {
    String prepend = workspaceName.splitMapJoin(' ',
        onMatch: (match) => '',
        onNonMatch: (text) => text.substring(0, 1).toUpperCase());
    return [
      '$prepend MVP App',
      '$prepend User Auth Service',
      '$prepend Transactions Service',
      '$prepend Reporting Service',
      '$prepend DevOps'
    ];
  }

  List<String> _generateListNames() {
    return ['To Do', 'In Progress', 'To Test', 'Testing', 'To Release', 'Done'];
  }

  List<String> _generateCardNames(String prepend, int nrOfCards) {
    return List.generate(nrOfCards, (index) => '$prepend Card $index');
  }

  createSampleWorkspace(
      String workspaceName, TrelloProvider trello, BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height * 0.1, // 10% from bottom
          right: 20,
          left: 20,
        ),
        content: const Row(
          children: [
            Icon(Icons.sync, color: brandColor),
            SizedBox(width: 12),
            Text('Generating Workspace Data...'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Workspace workspace = await createWorkspace(context,
        name: workspaceName,
        description: 'Example workspace',
        visibility: 'Public');
    for (String boardName in _generateBoardNames(workspaceName)) {
      //create board
      Board newBoard = Board(
          id: randomUuid(),
          workspaceId: workspace.id,
          userId: trello.user.id,
          name: boardName,
          visibility: 'Workspace',
          background: backgrounds[random.nextInt(16)]);
      await createBoard(context, newBoard);

      int listIndex = 1;
      //create lists for each board
      for (String listName in _generateListNames()) {
        Listboard newList = Listboard(
            id: randomUuid(),
            workspaceId: workspace.id,
            boardId: newBoard.id,
            userId: trello.user.id,
            name: listName,
            order: listIndex++);
        await addList(newList);

        //create cards per list
        int cardIndex = 1;
        for (String cardName
            in _generateCardNames(listName, random.nextInt(10))) {
          Cardlist newCard = Cardlist(
              id: randomUuid(),
              workspaceId: workspace.id,
              listId: newList.id,
              userId: trello.user.id,
              name: cardName,
              rank: cardIndex++);
          await addCard(newCard);
          await createComment(Comment(
            id: randomUuid(),
            workspaceId: workspace.id,
            cardId: newCard.id,
            userId: trello.user.id,
            description: '${randomNames.name()} said something interesting',
          ));
          await createChecklist(Checklist(
              id: randomUuid(),
              workspaceId: workspace.id,
              cardId: newCard.id,
              name: '${randomNames.name()} need to check this',
              status: false));
          await createChecklist(Checklist(
              id: randomUuid(),
              workspaceId: workspace.id,
              cardId: newCard.id,
              name: '${randomNames.name()} need to check this',
              status: false));
          await createActivity(
              workspaceId: workspace.id,
              boardId: newBoard.id,
              card: newCard.id,
              description: '${randomNames.name()} updated this card');
        }
      }
    }
  }
}
