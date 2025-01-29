import 'package:flutter/material.dart';
import 'package:trelloappclone_flutter/utils/service.dart';

import '../../../main.dart';
import '../../../utils/color.dart';

class WorkspaceMenu extends StatefulWidget {
  const WorkspaceMenu({super.key});

  @override
  State<WorkspaceMenu> createState() => _WorkspaceMenuState();
}

class _WorkspaceMenuState extends State<WorkspaceMenu> with Service {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(
              Icons.close,
              size: 30,
            ),
          ),
          actions: [
            IconButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/workspacesettings');
                },
                icon: const Icon(Icons.settings))
          ],
          title: const Text("Workspace menu"),
          centerTitle: false,
        ),
        body: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trello.selectedWorkspace.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const Text.rich(TextSpan(children: [
                        WidgetSpan(
                            child:
                                Icon(Icons.lock, color: dangerColor, size: 15)),
                        TextSpan(
                            text: "Public",
                            style: TextStyle(color: dangerColor))
                      ])),
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                        child: Text(trello.selectedWorkspace.description),
                      ),
                    ],
                  ),
                  const Spacer(),
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.green[400],
                    child: Text(
                      trello.selectedWorkspace.name[0].toUpperCase(),
                      style: const TextStyle(color: whiteShade),
                    ),
                  )
                ],
              ),
              Container(
                padding: const EdgeInsets.only(top: 10.0),
                child: ListTile(
                  tileColor: whiteShade,
                  leading: const Icon(Icons.person_outline),
                  title: const Padding(
                    padding: EdgeInsets.only(top: 10.0, bottom: 15),
                    child: Text("Members"),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18.0),
                        child: InkWell(
                          onTap: () {
                            Navigator.pushNamed(context, '/members');
                          },
                          child: Row(
                            children: buildMemberAvatars(),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 15.0),
                        child: SizedBox(
                          height: 37,
                          width: MediaQuery.of(context).size.width * 0.7,
                          child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: brandColor),
                              onPressed: () {
                                Navigator.pushNamed(context, '/invitemember');
                              },
                              child: const Text("Invite")),
                        ),
                      )
                    ],
                  ),
                ),
              )
            ],
          ),
        ));
  }

  List<Widget> buildMemberAvatars() {
    List<Widget> avatars = [];

    trello.selectedWorkspace.members?.forEach((member) {
      avatars.add(CircleAvatar(
        backgroundColor: brandColor,
        child: Text(member.name[0].toUpperCase()),
      ));
      avatars.add(const SizedBox(
        width: 4,
      ));
    });
    return avatars;
  }
}
