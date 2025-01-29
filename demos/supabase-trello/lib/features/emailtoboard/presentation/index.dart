import 'package:flutter/material.dart';
import 'package:trelloappclone_flutter/utils/color.dart';

class EmailToBoard extends StatefulWidget {
  const EmailToBoard({super.key});

  @override
  State<EmailToBoard> createState() => _EmailToBoardState();
}

class _EmailToBoardState extends State<EmailToBoard> {
  final TextEditingController emailController = TextEditingController();
  String? dropdownValue;
  String? dropdownPosition;
  List<String> list = ["To Do"];
  List<String> position = ["Bottom"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Email-to-board settings"),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Your email address for this board"),
              TextField(
                controller: emailController,
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text("Copy this address"),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text("Email me this address"),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.mark_email_read_outlined),
                title: const Text("Generate a new email address"),
                onTap: () {},
              ),
              const Divider(
                height: 2,
                thickness: 1,
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 8.0, top: 8.0),
                child: Text(
                  "Your emailed cards appear in...",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const Text(
                "List",
                style:
                    TextStyle(color: brandColor, fontWeight: FontWeight.bold),
              ),
              DropdownButton<String>(
                isExpanded: true,
                value: dropdownValue,
                icon: const Icon(Icons.keyboard_arrow_down),
                elevation: 16,
                style: const TextStyle(color: themeColor),
                underline: Container(
                  height: 2,
                  color: brandColor,
                ),
                onChanged: (String? value) {
                  setState(() {
                    dropdownValue = value!;
                  });
                },
                items: list.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
              const Text(
                "Position",
                style:
                    TextStyle(color: brandColor, fontWeight: FontWeight.bold),
              ),
              DropdownButton<String>(
                isExpanded: true,
                value: dropdownPosition,
                icon: const Icon(Icons.keyboard_arrow_down),
                elevation: 16,
                style: const TextStyle(color: themeColor),
                underline: Container(
                  height: 2,
                  color: brandColor,
                ),
                onChanged: (String? value) {
                  setState(() {
                    dropdownPosition = value!;
                  });
                },
                items: position.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 18.0),
                child: Divider(
                  height: 2,
                  thickness: 1,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 18.0),
                child: Text(
                  "Tip: Don't share this email address. Anyone who has it can add cards as you. When composing emails , the card title goes in the subject and the card description in the body",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
