import 'package:flutter/material.dart';

import '../../../utils/constant.dart';

class PowerUps extends StatefulWidget {
  const PowerUps({super.key});

  @override
  State<PowerUps> createState() => _PowerUpsState();
}

class _PowerUpsState extends State<PowerUps> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Power-Ups"),
        centerTitle: false,
      ),
      body: ListView.separated(
          itemBuilder: (BuildContext context, index) {
            return ListTile(
              leading: const CircleAvatar(),
              title: Text(powerups[index]["title"]!),
              subtitle: Text(powerups[index]["description"]!),
              trailing: Switch(
                value: false,
                onChanged: ((value) {}),
              ),
            );
          },
          separatorBuilder: (context, index) => const Divider(
                color: Colors.black,
              ),
          itemCount: powerups.length),
    );
  }
}
