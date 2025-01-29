import 'package:flutter/material.dart';
import 'package:trelloappclone_flutter/utils/color.dart';
import 'package:trelloappclone_flutter/utils/service.dart';
import 'package:trelloappclone_flutter/models/member.dart';

import '../../../main.dart';

class InviteMember extends StatefulWidget {
  const InviteMember({super.key});

  @override
  State<InviteMember> createState() => _InviteMemberState();
}

class _InviteMemberState extends State<InviteMember> with Service {
  final TextEditingController emailcontroller = TextEditingController();
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
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(Icons.close, size: 30),
        ),
        title: Text("Invite to ${trello.selectedWorkspace.name}"),
        centerTitle: false,
        // actions: [
        //   IconButton(onPressed: () {}, icon: const Icon(Icons.contacts))
        // ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: TextField(
                  controller: emailcontroller,
                  textCapitalization: TextCapitalization.none,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: "Email"),
                ),
              ),
              Card(
                child: ListTile(
                  textColor: brandColor,
                  title: const Text("Add Existing User"),
                  subtitle: const Text("Add user with email to workspace."),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.add_circle_outline,
                      color: brandColor,
                    ),
                    onPressed: () {
                      inviteUserToWorkspace(
                              emailcontroller.text, trello.selectedWorkspace)
                          .then((succeeded) {
                        if (succeeded) {
                          setState(() {
                            _currentMembers.clear();
                            _currentMembers
                                .addAll(trello.selectedWorkspace.members ?? []);
                          });
                          // ignore: use_build_context_synchronously
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              duration: const Duration(seconds: 3),
                              margin: EdgeInsets.only(
                                // ignore: use_build_context_synchronously
                                bottom: MediaQuery.of(context).size.height *
                                    0.1, // 10% from bottom
                                right: 20,
                                left: 20,
                              ),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.check, color: brandColor),
                                      SizedBox(width: 12),
                                      Text('Added Member'),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                      '${emailcontroller.text} added to workspace.'),
                                ],
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } else {
                          // ignore: use_build_context_synchronously
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              duration: const Duration(seconds: 3),
                              margin: EdgeInsets.only(
                                // ignore: use_build_context_synchronously
                                bottom: MediaQuery.of(context).size.height *
                                    0.1, // 10% from bottom
                                right: 20,
                                left: 20,
                              ),
                              backgroundColor: Colors.red[100],
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.error_outline,
                                          color: Colors.red),
                                      SizedBox(width: 12),
                                      Text('Add Failed'),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                      '${emailcontroller.text} not an existing user.'),
                                ],
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      });
                    },
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 18.0, bottom: 18),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    "Current Board Members",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              _buildMembersList(),
              // Padding(
              //   padding: EdgeInsets.only(bottom: 8.0),
              //   child: Text(
              //     "Work together on a board",
              //     style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              //   ),
              // ),
              // Text(
              //   "Use the search bar or invite link to share this board with others",
              //   textAlign: TextAlign.center,
              // )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMembersList() {
    List<Widget> memberTiles = [];
    for (var member in _currentMembers) {
      memberTiles.add(ListTile(
        leading: CircleAvatar(
          backgroundColor: brandColor,
          child: Text(member.name[0].toUpperCase()),
        ),
        title: Text(member.name),
        trailing: const Text("Admin"),
      ));
    }
    return Column(
      children: memberTiles,
    );
  }
}
