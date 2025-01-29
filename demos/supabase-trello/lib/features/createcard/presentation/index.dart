import 'package:flutter/material.dart';

import '../../../utils/color.dart';

class CreateCard extends StatefulWidget {
  const CreateCard({super.key});

  @override
  State<CreateCard> createState() => _CreateCardState();
}

class _CreateCardState extends State<CreateCard> {
  String? dropdownValue;
  List<String> boards = ["Board 1"];
  String? listdropdownvalue;
  List<String> lists = ["List 1"];
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.pushNamed(context, '/home');
          },
          icon: const Icon(Icons.close),
        ),
        title: const Text("New card"),
        centerTitle: false,
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.check))],
      ),
      body: SingleChildScrollView(
          child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Board"),
            DropdownButton<String>(
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
              items: boards.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
            const Text("List"),
            DropdownButton<String>(
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
                  listdropdownvalue = value!;
                });
              },
              items: lists.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
            Container(
              color: brandColor,
              margin: const EdgeInsets.all(10.0),
              child: Card(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        controller: nameController,
                        decoration:
                            const InputDecoration(hintText: "Card name"),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        controller: descriptionController,
                        decoration:
                            const InputDecoration(hintText: "Card description"),
                      ),
                    ),
                    const ListTile(
                      leading: Icon(Icons.person_add),
                      title: Text("Jane Doe"),
                    ),
                    ListTile(
                      leading: const Icon(Icons.lock_clock),
                      title: const Text("Start date..."),
                      onTap: () {},
                    ),
                    ListTile(
                      title: const Text("Due date..."),
                      onTap: () {},
                    ),
                    ListTile(
                      leading: const Icon(Icons.attachment),
                      title: const Text("Attachment"),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      )),
    );
  }
}
