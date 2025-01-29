import 'package:flutter/material.dart';
import 'package:trelloappclone_flutter/utils/color.dart';

class ArchivedLists extends StatefulWidget {
  const ArchivedLists({super.key});

  @override
  State<ArchivedLists> createState() => _ArchivedListsState();
}

class _ArchivedListsState extends State<ArchivedLists> {
  bool select = false;
  int selected = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: (select)
            ? IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.close,
                  size: 30,
                ),
              )
            : null,
        title: Text((select) ? "&selected  selected" : "Archived lists"),
        centerTitle: false,
        actions: [
          (select)
              ? TextButton(
                  onPressed: () {},
                  child: const Text(
                    "SEND TO BOARD",
                    style: TextStyle(color: whiteShade),
                  ))
              : IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.check_circle_outline))
        ],
      ),
      body: const Center(
        child: Text("No archived lists"),
      ),
    );
  }
}
