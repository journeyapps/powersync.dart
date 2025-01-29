import 'package:flutter/material.dart';
import 'package:trelloappclone_flutter/models/board.dart';
import 'package:trelloappclone_flutter/models/workspace.dart';
import 'package:trelloappclone_flutter/features/drawer/presentation/index.dart';
import 'package:trelloappclone_flutter/utils/color.dart';

import '../../../utils/service.dart';
import '../../../utils/widgets.dart';

class OfflineBoards extends StatefulWidget {
  const OfflineBoards({super.key});

  @override
  State<OfflineBoards> createState() => _OfflineBoardsState();
}

class _OfflineBoardsState extends State<OfflineBoards> with Service {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Offline boards"),
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.search))],
      ),
      drawer: const CustomDrawer(),
      body: SingleChildScrollView(
          child: StreamBuilder(
              stream: getWorkspacesStream(),
              builder: (BuildContext context,
                  AsyncSnapshot<List<Workspace>> snapshot) {
                if (snapshot.hasData) {
                  List<Workspace> children = snapshot.data as List<Workspace>;

                  if (children.isNotEmpty) {
                    return Column(children: buildWorkspacesAndBoards(children));
                  }
                }
                return const SizedBox.shrink();
              })),
    );
  }

  List<Widget> buildWorkspacesAndBoards(List<Workspace> wkspcs) {
    List<Widget> workspacesboards = [];
    Widget workspace;

    for (int i = 0; i < wkspcs.length; i++) {
      workspace = ListTile(
        tileColor: whiteShade,
        leading: Text(wkspcs[i].name),
      );

      workspacesboards.add(workspace);

      workspacesboards.add(StreamBuilder(
          stream: getBoardsStream(wkspcs[i].id),
          builder: (BuildContext context, AsyncSnapshot<List<Board>> snapshot) {
            if (snapshot.hasData) {
              List<Board> children = snapshot.data as List<Board>;

              if (children.isNotEmpty) {
                return Column(children: buildBoards(children, wkspcs[i]));
              }
            }
            return const SizedBox.shrink();
          }));
    }
    //  }
    return workspacesboards;
  }

  List<Widget> buildBoards(List<Board> brd, Workspace wkspcs) {
    List<Widget> boards = [];
    for (int j = 0; j < brd.length; j++) {
      boards.add(ListTile(
        leading: ColorSquare(bckgrd: brd[j].background),
        title: Text(brd[j].name),
        onTap: () {},
        trailing: Switch(
          value: brd[j].availableOffline ?? false,
          activeColor: brandColor,
          onChanged: (bool value) {
            setState(() {
              brd[j].availableOffline = value;
              updateOfflineStatus(brd[j]);
            });
          },
        ),
      ));
    }
    return boards;
  }
}
