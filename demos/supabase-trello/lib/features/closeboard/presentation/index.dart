import 'package:flutter/material.dart';
import 'package:trelloappclone_flutter/utils/color.dart';

class CloseBoard extends StatefulWidget {
  const CloseBoard({super.key});

  @override
  State<CloseBoard> createState() => _CloseBoardState();
}

class _CloseBoardState extends State<CloseBoard> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Board 1 is now closed"),
      content: SizedBox(
        height: 100,
        child: Column(
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.7,
              child: ElevatedButton(
                  onPressed: () {}, child: const Text("Re-open")),
            ),
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.7,
              child: OutlinedButton(
                  onPressed: () {},
                  child: const Text(
                    "Delete",
                    style: TextStyle(color: dangerColor),
                  )),
            )
          ],
        ),
      ),
    );
  }
}
