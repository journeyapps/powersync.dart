import 'package:flutter/material.dart';
import 'package:trelloappclone_flutter/models/board.dart';
import 'package:trelloappclone_flutter/features/drawer/presentation/index.dart';
import 'package:trelloappclone_flutter/utils/color.dart';

import '../../../utils/service.dart';
import '../domain/workspace_arguments.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();

  static const routeName = '/workspace';
}

class _WorkspaceScreenState extends State<WorkspaceScreen> with Service {
  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as WorkspaceArguments;

    return Scaffold(
      appBar: AppBar(
        title: Text(args.wkspc.name),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
          IconButton(
              onPressed: () {},
              icon: const Icon(Icons.notifications_none_outlined))
        ],
      ),
      drawer: const CustomDrawer(),
      body: DefaultTabController(
          length: 2,
          initialIndex: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const TabBar(
                  labelColor: brandColor,
                  unselectedLabelColor: themeColor,
                  tabs: [
                    Tab(
                      text: "BOARDS",
                    ),
                    Tab(
                      text: "HIGHLIGHTS",
                    )
                  ]),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.8,
                child: TabBarView(children: [
                  Column(
                    children: [
                      Container(
                        width: MediaQuery.of(context).size.width,
                        height: 50,
                        color: whiteShade,
                        alignment: Alignment.centerLeft,
                        child: const Padding(
                            padding: EdgeInsets.only(left: 8.0),
                            child: Text("Your Workspace boards")),
                      ),
                      StreamBuilder(
                        stream: getBoardsStream(args.wkspc.id),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            List<Board> children = snapshot.data as List<Board>;

                            if (children.isNotEmpty) {
                              return Expanded(
                                  child: GridView.builder(
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 2,
                                              childAspectRatio: 1 / 0.7),
                                      itemCount: children.length,
                                      itemBuilder:
                                          (BuildContext context, int index) {
                                        return GestureDetector(
                                          onTap: () {},
                                          child: Card(
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        10.0)),
                                            color: Color(int.parse(
                                                    children[index]
                                                        .background
                                                        .substring(1, 7),
                                                    radix: 16) +
                                                0xFF000000),
                                            child: Align(
                                              alignment: Alignment.bottomLeft,
                                              child: ListTile(
                                                tileColor: themeColor,
                                                title: Text(
                                                  children[index].name,
                                                  style: const TextStyle(
                                                      color: Colors.white),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }));
                            }
                          }
                          return const SizedBox.shrink();
                        },
                      )
                    ],
                  ),
                  Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          const ListTile(
                            leading: Icon(
                              Icons.start,
                              color: brandColor,
                            ),
                            title: Text("GET STARTED"),
                          ),
                          Card(
                            child: Column(
                              children: [
                                Container(
                                  color: brandColor,
                                  height: 100,
                                ),
                                const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text(
                                    "Stay on track and up-to-date",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18),
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text(
                                    "Invite people to boards and cards, add comments, and adjust due dates all from the new Trello Home. We'll show the most important activity here.",
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              ],
                            ),
                          )
                        ],
                      ))
                ]),
              )
            ],
          )),
    );
  }
}
