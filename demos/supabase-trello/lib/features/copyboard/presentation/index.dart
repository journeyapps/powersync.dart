import 'package:flutter/material.dart';

import '../../../utils/color.dart';
import '../../../utils/constant.dart';

class CopyBoard extends StatefulWidget {
  const CopyBoard({super.key});

  @override
  State<CopyBoard> createState() => _CopyBoardState();
}

class _CopyBoardState extends State<CopyBoard> {
  final TextEditingController nameController = TextEditingController();
  String? dropdownValue;
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
            icon: const Icon(
              Icons.close,
              size: 30,
            )),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                    border: UnderlineInputBorder(), labelText: "Board name"),
              ),
              const Text("Workspace"),
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: dropdownValue,
                  icon: const Icon(Icons.keyboard_arrow_down),
                  elevation: 16,
                  style: const TextStyle(color: brandColor),
                  underline: Container(
                    height: 2,
                    color: brandColor,
                  ),
                  onChanged: (String? value) {
                    // This is called when the user selects an item.
                    setState(() {
                      dropdownValue = value!;
                    });
                  },
                  items:
                      workspaces.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ),
              const Text("Visibility"),
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
              SwitchListTile(
                value: false,
                onChanged: ((value) {}),
                title: const Text("Keep cards"),
              ),
              const Text(
                "Activities and members will not be copied to the new board",
                style: TextStyle(fontSize: 12),
              )
            ],
          ),
        ),
      ),
    );
  }
}
