import 'package:flutter/material.dart';

import '../../../utils/constant.dart';

class BoardVisibility extends StatefulWidget {
  const BoardVisibility({super.key});

  @override
  State<BoardVisibility> createState() => _BoardVisibilityState();
}

class _BoardVisibilityState extends State<BoardVisibility> {
  List<bool> checked = [false, false, false];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Visibility"),
      content: SizedBox(
        height: 360,
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: Checkbox(
                  value: checked[0],
                  onChanged: (bool? value) {},
                ),
                title: Text(visibilityConfigurations[0]["type"]!),
                subtitle: Text(visibilityConfigurations[0]["description"]!),
              ),
            ),
            Card(
              child: ListTile(
                leading: Checkbox(
                  value: checked[1],
                  onChanged: (bool? value) {},
                ),
                title: Text(visibilityConfigurations[1]["type"]!),
                subtitle: Text(visibilityConfigurations[1]["description"]!),
              ),
            ),
            Card(
              child: ListTile(
                leading: Checkbox(
                  value: checked[2],
                  onChanged: (bool? value) {},
                ),
                title: Text(visibilityConfigurations[2]["type"]!),
                subtitle: Text(visibilityConfigurations[2]["description"]!),
              ),
            )
          ],
        ),
      ),
      actions: [ElevatedButton(onPressed: () {}, child: const Text("Save"))],
    );
  }
}
