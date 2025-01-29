import 'package:flutter/material.dart';
import 'package:trelloappclone_flutter/utils/constant.dart';

import '../../../utils/color.dart';
import '../../../utils/service.dart';

class CreateWorkspace extends StatefulWidget {
  const CreateWorkspace({super.key});

  @override
  State<CreateWorkspace> createState() => _CreateWorkspaceState();
}

class _CreateWorkspaceState extends State<CreateWorkspace> with Service {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  Map<String, String>? dropdownValue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Workspace"),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8.0),
                child: Text(
                  "Let's build a Workspace",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              const Text(
                "Boost your productivity by making it easier for everyone to access boards in one location",
                style: TextStyle(fontSize: 16),
              ),
              TextField(
                controller: nameController,
                decoration:
                    const InputDecoration(hintText: "Enter workspace name"),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text("Visibility"),
              ),
              DropdownButton<Map<String, String>>(
                isExpanded: true,
                value: dropdownValue,
                icon: const Icon(Icons.keyboard_arrow_down),
                elevation: 16,
                style: const TextStyle(color: brandColor),
                underline: Container(
                  height: 2,
                  color: brandColor,
                ),
                onChanged: (Map<String, String>? value) {
                  // This is called when the user selects an item.
                  setState(() {
                    dropdownValue = value!;
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
              const Padding(
                padding: EdgeInsets.only(top: 10.0),
                child: Text("Description"),
              ),
              TextField(
                controller: descriptionController,
                maxLines: null,
                minLines: 4,
              ),
              Align(
                alignment: Alignment.center,
                child: Container(
                    padding: const EdgeInsets.only(top: 10),
                    width: MediaQuery.of(context).size.width * 0.8,
                    height: 60,
                    child: ElevatedButton(
                        onPressed: () {
                          createWorkspace(context,
                              name: nameController.text,
                              description: descriptionController.text,
                              visibility: dropdownValue!["type"] ?? "");
                        },
                        child: const Text("Create"))),
              )
            ],
          ),
        ),
      ),
    );
  }
}
