import 'package:flutter/material.dart';

import '../../drawer/presentation/index.dart';

class MyCards extends StatefulWidget {
  const MyCards({super.key});

  @override
  State<MyCards> createState() => _MyCardsState();
}

class _MyCardsState extends State<MyCards> {
  String selectedValue = "Board";
  List<String> list = ["Board", "Date"];
  String? dropdownValue;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Text("My cards by $selectedValue"),
          SizedBox(
              child: DropdownButton<String>(
            value: dropdownValue,
            icon: const Icon(
              Icons.keyboard_arrow_down,
              color: Colors.white,
            ),
            underline: const SizedBox.shrink(),
            elevation: 16,
            onChanged: (String? value) {
              setState(() {
                selectedValue = value!;
              });
            },
            items: list.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          ))
        ]),
        centerTitle: false,
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.search))],
      ),
      drawer: const CustomDrawer(),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(10.0),
          child: Text(
            "When you are assigned to cards they will show up here",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
