import 'package:flutter/material.dart';
import 'package:trelloappclone_flutter/utils/data_generator.dart';

import '../../../main.dart';
import '../../../utils/service.dart';

class GenerateWorkspace extends StatefulWidget {
  const GenerateWorkspace({super.key});

  @override
  State<GenerateWorkspace> createState() => _GenerateWorkspaceState();
}

class _GenerateWorkspaceState extends State<GenerateWorkspace> with Service {
  final TextEditingController nameController = TextEditingController();
  Map<String, String>? dropdownValue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Generate Sample Workspace"),
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
                  "This will create a Workspace with sample data",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              TextField(
                controller: nameController,
                decoration:
                    const InputDecoration(hintText: "Enter workspace name"),
              ),
              // const Padding(
              //   padding: EdgeInsets.only(top: 8.0),
              //   child: Text("Visibility"),
              // ),
              // DropdownButton<Map<String, String>>(
              //   isExpanded: true,
              //   value: dropdownValue,
              //   icon: const Icon(Icons.keyboard_arrow_down),
              //   elevation: 16,
              //   style: const TextStyle(color: brandColor),
              //   underline: Container(
              //     height: 2,
              //     color: brandColor,
              //   ),
              //   onChanged: (Map<String, String>? value) {
              //     // This is called when the user selects an item.
              //     setState(() {
              //       dropdownValue = value!;
              //     });
              //   },
              //   items: visibilityConfigurations
              //       .map<DropdownMenuItem<Map<String, String>>>(
              //           (Map<String, String> value) {
              //     return DropdownMenuItem<Map<String, String>>(
              //       value: value,
              //       child: Text(value["type"]!),
              //     );
              //   }).toList(),
              // ),
              // const Padding(
              //   padding: EdgeInsets.only(top: 10.0),
              //   child: Text("Description"),
              // ),
              // TextField(
              //   controller: descriptionController,
              //   maxLines: null,
              //   minLines: 4,
              // ),
              Align(
                alignment: Alignment.center,
                child: Container(
                    padding: const EdgeInsets.only(top: 10),
                    width: MediaQuery.of(context).size.width * 0.8,
                    height: 60,
                    child: ElevatedButton(
                        onPressed: () {
                          DataGenerator().createSampleWorkspace(
                              nameController.text, trello, context);
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
