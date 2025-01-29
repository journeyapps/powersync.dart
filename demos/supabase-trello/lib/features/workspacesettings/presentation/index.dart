import 'package:flutter/material.dart';
import 'package:trelloappclone_flutter/utils/color.dart';

import '../../../main.dart';
import '../../visibility/presentation/index.dart';

class WorkspaceSettings extends StatefulWidget {
  const WorkspaceSettings({super.key});

  @override
  State<WorkspaceSettings> createState() => _WorkspaceSettingsState();
}

class _WorkspaceSettingsState extends State<WorkspaceSettings> {
  final TextEditingController nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    nameController.text = trello.selectedWorkspace.name;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Workspace settings"),
        centerTitle: false,
      ),
      body: Column(
        children: [
          ListTile(
            leading: const Text("Name"),
            trailing: SizedBox(
                width: MediaQuery.of(context).size.width * 0.4,
                child: EditableText(
                  textAlign: TextAlign.end,
                  controller: nameController,
                  focusNode: FocusNode(),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: brandColor),
                  cursorColor: brandColor,
                  backgroundCursorColor: brandColor,
                  onSubmitted: (value) {
                    Navigator.pushNamed(context, '/home');
                  },
                )),
          ),
          ListTile(
            leading: const Text("Visibility"),
            trailing: GestureDetector(
              child: const Text("Public"),
              onTap: () {
                showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return const BoardVisibility();
                    });
              },
            ),
          ),
          const Align(
            alignment: Alignment.center,
            child: Text("Not all settings are editable on mobile"),
          )
        ],
      ),
    );
  }
}
