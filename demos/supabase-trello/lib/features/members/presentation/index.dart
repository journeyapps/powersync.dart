import 'package:flutter/material.dart';
import 'package:trelloappclone_flutter/utils/color.dart';
import 'package:trelloappclone_flutter/utils/service.dart';
import 'package:trelloappclone_flutter/models/member.dart';

import '../../../main.dart';

class Members extends StatefulWidget {
  const Members({super.key});

  @override
  State<Members> createState() => _MembersState();
}

class _MembersState extends State<Members> with Service {
  final List<Member> _currentMembers = [];

  @override
  void initState() {
    super.initState();
    _currentMembers.addAll(trello.selectedWorkspace.members ?? []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Members"),
        centerTitle: false,
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/invitemember');
              },
              child: const Text(
                "INVITE",
                style: TextStyle(color: whiteShade),
              ))
        ],
      ),
      body: SingleChildScrollView(
          child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Members (${_currentMembers.length})"),
            ListView(
              shrinkWrap: true,
              children: _buildMembersList(),
            )
          ],
        ),
      )),
    );
  }

  List<Widget> _buildMembersList() {
    List<Widget> memberTiles = [];
    for (var member in _currentMembers) {
      memberTiles.add(ListTile(
        leading: CircleAvatar(
          backgroundColor: brandColor,
          child: Text(member.name[0].toUpperCase()),
        ),
        title: Text(member.name),
        trailing: Text(
          member.role,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onTap: () {
          showModalBottomSheet(
              context: context,
              builder: (BuildContext context) {
                return SizedBox(
                  height: MediaQuery.of(context).size.height * 0.4,
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: brandColor,
                              child: Text(member.name[0].toUpperCase()),
                            ),
                            title: Text(member.name),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(member.role),
                          ),
                          const Text(
                              "Can view, create and edit Workspace boards, and change settings for the workspace"),
                          Align(
                            alignment: Alignment.center,
                            child: Container(
                              padding: const EdgeInsets.only(top: 8.0),
                              width: MediaQuery.of(context).size.width * 0.8,
                              height: 50,
                              child: ElevatedButton(
                                  onPressed: () {
                                    removeMemberFromWorkspace(
                                            member, trello.selectedWorkspace)
                                        .then((updatedWorkspace) {
                                      setState(() {
                                        _currentMembers.clear();
                                        _currentMembers.addAll(
                                            updatedWorkspace.members ?? []);
                                      });
                                    });
                                    Navigator.of(context).pop();
                                  },
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: dangerColor),
                                  child: Text(member.userId == trello.user.id
                                      ? "Leave workspace"
                                      : "Remove from workspace")),
                            ),
                          )
                        ]),
                  ),
                );
              });
        },
      ));
    }

    return memberTiles;
  }
}
