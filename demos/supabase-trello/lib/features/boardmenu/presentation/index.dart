import 'package:flutter/material.dart';
import 'package:trelloappclone_flutter/features/visibility/presentation/index.dart';
import 'package:trelloappclone_flutter/main.dart';
import 'package:trelloappclone_flutter/utils/color.dart';

class BoardMenu extends StatefulWidget {
  const BoardMenu({super.key});

  @override
  State<BoardMenu> createState() => _BoardMenuState();
}

class _BoardMenuState extends State<BoardMenu> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(Icons.close),
        ),
        title: const Text("Board menu"),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
          child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  decoration: const BoxDecoration(
                      color: brandColor,
                      borderRadius: BorderRadius.all(Radius.circular(10.0))),
                  child: IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.star_border,
                      size: 30,
                    ),
                  ),
                ),
                Container(
                  decoration: const BoxDecoration(
                      color: brandColor,
                      borderRadius: BorderRadius.all(Radius.circular(10.0))),
                  child: IconButton(
                    onPressed: () {
                      showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return const BoardVisibility();
                          });
                    },
                    icon: const Icon(
                      Icons.people,
                      size: 30,
                    ),
                  ),
                ),
                Container(
                  decoration: const BoxDecoration(
                      color: brandColor,
                      borderRadius: BorderRadius.all(Radius.circular(10.0))),
                  child: IconButton(
                    onPressed: () {
                      Navigator.pushNamed(context, "/copyboard");
                    },
                    icon: const Icon(
                      Icons.copy,
                      size: 30,
                    ),
                  ),
                ),
                Container(
                  decoration: const BoxDecoration(
                      color: brandColor,
                      borderRadius: BorderRadius.all(Radius.circular(10.0))),
                  child: IconButton(
                    onPressed: () {
                      Navigator.pushNamed(context, "/boardsettings");
                    },
                    icon: const Icon(
                      Icons.more_horiz,
                      size: 30,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.only(top: 10.0),
            child: ListTile(
              tileColor: whiteShade,
              leading: const Icon(Icons.person_outline),
              title: const Padding(
                padding: EdgeInsets.only(top: 15.0, bottom: 15.0),
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
                          Navigator.pushNamed(context, "/invitemember");
                        },
                        child: const Text("Invite to workspace"),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 15.0),
            child: Container(
              color: whiteShade,
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text("About this board"),
                onTap: () {
                  Navigator.pushNamed(context, '/aboutboard');
                },
              ),
            ),
          ),
          // Padding(
          //     padding: const EdgeInsets.only(top: 15.0),
          //     child: Container(
          //       color: whiteShade,
          //       child: ListTile(
          //         leading: const Icon(Icons.rocket),
          //         title: const Text("Power-Ups"),
          //         onTap: () {
          //           Navigator.pushNamed(context, '/powerups');
          //         },
          //       ),
          //     )),
          // Padding(
          //     padding: const EdgeInsets.only(top: 15.0),
          //     child: Container(
          //       color: whiteShade,
          //       child: ListTile(
          //         leading: const Icon(Icons.push_pin_outlined),
          //         title: const Text("Pin to home screen"),
          //         onTap: () {},
          //       ),
          //     )),
          // const Padding(
          //   padding: EdgeInsets.all(15.0),
          //   child: Text(
          //     "Activity",
          //     style: TextStyle(fontWeight: FontWeight.bold),
          //   ),
          // ),
          // //TODO: figure out what is going on here
          // Activities(Cardlist(
          //     id: "todo", workspaceId: trello.selectedWorkspace.id, listId: "todo", userId: trello.user.id, name: ""))
        ],
      )),
    );
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
