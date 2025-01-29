import 'package:flutter/material.dart';
import 'package:trelloappclone_flutter/utils/color.dart';
import 'package:trelloappclone_flutter/utils/config.dart';

import '../../../utils/widgets.dart';
import '../../closeboard/presentation/index.dart';

class BoardSettings extends StatefulWidget {
  const BoardSettings({super.key});

  @override
  State<BoardSettings> createState() => _BoardSettingsState();
}

class _BoardSettingsState extends State<BoardSettings> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Board settings")),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const BlueRectangle(),
            Padding(
              padding: const EdgeInsets.only(top: 15.0),
              child: Container(
                color: whiteShade,
                child: const ListTile(
                  leading: Text("Name"),
                  trailing: Text("Board 1"),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 3.0),
              child: Container(
                color: whiteShade,
                child: const ListTile(
                  leading: Text("Workspace"),
                  trailing: Text("Workspace 1"),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 3.0),
              child: Container(
                color: whiteShade,
                child: ListTile(
                  leading: const Text("Background"),
                  trailing: ColorSquare(
                    bckgrd: backgrounds[0],
                  ),
                  onTap: () {
                    Navigator.pushNamed(context, "/boardbackground");
                  },
                ),
              ),
            ),
            // Padding(
            //   padding: const EdgeInsets.only(top: 3.0),
            //   child: Container(
            //     color: whiteShade,
            //     child: ListTile(
            //       leading: const Text("Enable card cover images"),
            //       trailing: Switch(value: true, onChanged: ((value) {})),
            //     ),
            //   ),
            // ),
            // Padding(
            //   padding: const EdgeInsets.only(top: 3.0),
            //   child: Container(
            //     color: whiteShade,
            //     child: ListTile(
            //         leading: const Text("Watch"),
            //         trailing: Switch(value: false, onChanged: ((value) {}))),
            //   ),
            // ),
            // Padding(
            //   padding: const EdgeInsets.only(top: 3.0),
            //   child: Container(
            //     color: whiteShade,
            //     child: ListTile(
            //         leading: const Text("Available offline"),
            //         trailing: Switch(value: false, onChanged: ((value) {}))),
            //   ),
            // ),
            // Padding(
            //   padding: const EdgeInsets.only(top: 3.0),
            //   child: Container(
            //     color: whiteShade,
            //     child: ListTile(
            //       leading: const Text("Edit labels"),
            //       onTap: () {
            //         showDialog(
            //             context: context,
            //             builder: (BuildContext context) {
            //               return const EditLabels();
            //             });
            //       },
            //     ),
            //   ),
            // ),
            // Padding(
            //   padding: const EdgeInsets.only(top: 3.0),
            //   child: Container(
            //     color: whiteShade,
            //     child: ListTile(
            //       leading: const Text("Email-to-board settings"),
            //       onTap: () {
            //         Navigator.pushNamed(context, "/emailtoboard");
            //       },
            //     ),
            //   ),
            // ),
            // Padding(
            //   padding: const EdgeInsets.only(top: 3.0),
            //   child: Container(
            //     color: whiteShade,
            //     child: ListTile(
            //       leading: const Text("Archived cards"),
            //       onTap: () {
            //         Navigator.pushNamed(context, "/archivedcards");
            //       },
            //     ),
            //   ),
            // ),
            // Padding(
            //   padding: const EdgeInsets.only(top: 3.0),
            //   child: Container(
            //     color: whiteShade,
            //     child: ListTile(
            //       leading: const Text("Archived lists"),
            //       onTap: () {
            //         Navigator.pushNamed(context, "/archivedlists");
            //       },
            //     ),
            //   ),
            // ),
            Padding(
              padding: const EdgeInsets.only(top: 15.0),
              child: Container(
                color: whiteShade,
                child: const ListTile(
                  leading: Text("Visibility"),
                  trailing: Text("Public"),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 3.0),
              child: Container(
                color: whiteShade,
                child: const ListTile(
                  leading: Text("Commenting"),
                  trailing: Text("Members"),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 3.0),
              child: Container(
                color: whiteShade,
                child: const ListTile(
                  leading: Text("Adding members"),
                  trailing: Text("Members"),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 15.0),
              child: Container(
                color: whiteShade,
                child: ListTile(
                    leading: const Text("Self join"),
                    trailing: Switch(
                      value: true,
                      onChanged: ((value) {}),
                    )),
              ),
            ),
            const Padding(
                padding: EdgeInsets.only(top: 10.0),
                child:
                    Text("Any Workspace member can edit and join the board")),
            Padding(
              padding: const EdgeInsets.only(top: 15.0, bottom: 50),
              child: Container(
                color: whiteShade,
                child: ListTile(
                  leading: const Text("Close board"),
                  onTap: () {
                    showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return const CloseBoard();
                        });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
