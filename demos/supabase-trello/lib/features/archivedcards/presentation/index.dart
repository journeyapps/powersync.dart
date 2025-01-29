import 'package:flutter/material.dart';

import '../../../utils/color.dart';

class ArchivedCards extends StatefulWidget {
  const ArchivedCards({super.key});

  @override
  State<ArchivedCards> createState() => _ArchivedCardsState();
}

class _ArchivedCardsState extends State<ArchivedCards> {
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
        title: Text((select) ? "&selected  selected" : "Archived cards"),
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
        child: Text("No archived cards"),
      ),
    );
  }
}
