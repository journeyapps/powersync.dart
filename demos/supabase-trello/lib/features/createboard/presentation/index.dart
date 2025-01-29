import 'package:flutter/material.dart';
import 'package:trelloappclone_flutter/main.dart';
import 'package:trelloappclone_flutter/models/board.dart';
import 'package:trelloappclone_flutter/models/workspace.dart';

import '../../../utils/color.dart';
import '../../../utils/constant.dart';
import '../../../utils/service.dart';

class CreateBoard extends StatefulWidget {
  const CreateBoard({super.key});

  @override
  State<CreateBoard> createState() => _CreateBoardState();
}

class _CreateBoardState extends State<CreateBoard> with Service {
  final TextEditingController nameController = TextEditingController();
  Workspace? dropdownValue;
  List<String> workspaces = [];
  Map<String, String>? visibilityDropdownValue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.close)),
        title: const Text("Create board"),
        centerTitle: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(hintText: "Enter Board name"),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: DropdownButton<Workspace>(
                hint: const Text("Workspace"),
                isExpanded: true,
                value: dropdownValue,
                icon: const Icon(Icons.keyboard_arrow_down),
                elevation: 16,
                style: const TextStyle(color: brandColor),
                underline: Container(
                  height: 2,
                  color: brandColor,
                ),
                onChanged: (Workspace? value) {
                  setState(() {
                    dropdownValue = value!;
                  });
                },
                items: trello.workspaces
                    .map<DropdownMenuItem<Workspace>>((Workspace value) {
                  return DropdownMenuItem<Workspace>(
                    value: value,
                    child: Text(value.name),
                  );
                }).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: DropdownButton<Map<String, String>>(
                hint: const Text("Visibility"),
                isExpanded: true,
                value: visibilityDropdownValue,
                icon: const Icon(Icons.keyboard_arrow_down),
                elevation: 16,
                style: const TextStyle(color: brandColor),
                underline: Container(
                  height: 2,
                  color: brandColor,
                ),
                onChanged: (Map<String, String>? value) {
                  setState(() {
                    visibilityDropdownValue = value!;
                  });
                },
                items: visibilityConfigurations
                    .map<DropdownMenuItem<Map<String, String>>>(
                        (Map<String, String> value) {
                  return DropdownMenuItem<Map<String, String>>(
                    value: value,
                    child: Text(value["type"]!),
                  );
                }).toList(),
              ),
            ),
            Row(
              children: [
                const Text("Board backgroud"),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, '/boardbackground')
                        .then((_) => setState(() {}));
                  },
                  child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                          color: Color(int.parse(
                                  trello.selectedBackground.substring(1, 7),
                                  radix: 16) +
                              0xFF000000))),
                ),
              ],
            ),
            Align(
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.only(top: 10),
                width: MediaQuery.of(context).size.width * 0.8,
                height: 60,
                child: ElevatedButton(
                  onPressed: () {
                    createBoard(
                        context,
                        Board(
                            id: randomUuid(),
                            workspaceId: dropdownValue!.id,
                            userId: trello.user.id,
                            name: nameController.text,
                            visibility: visibilityDropdownValue!["type"]!,
                            background: trello.selectedBackground));
                  },
                  child: const Text("Create board"),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
