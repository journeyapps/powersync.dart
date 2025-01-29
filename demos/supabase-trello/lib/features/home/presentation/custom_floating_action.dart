import 'package:flutter/material.dart';

class CustomFloatingAction extends StatefulWidget {
  final String title;
  final IconData icon;
  final String route;
  const CustomFloatingAction(this.title, this.icon, this.route, {super.key});

  @override
  State<CustomFloatingAction> createState() => _CustomFloatingActionState();
}

class _CustomFloatingActionState extends State<CustomFloatingAction> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, widget.route);
      },
      child: Text.rich(TextSpan(children: [
        WidgetSpan(
            child: SizedBox(
          width: 150,
          height: 30,
          child: Card(
              child: Center(
            child: Text(widget.title),
          )),
        )),
        const WidgetSpan(
            child: SizedBox(
          width: 20,
        )),
        WidgetSpan(
            child: CircleAvatar(
          backgroundColor: Colors.green[400],
          child: Icon(widget.icon, color: Colors.white, size: 26),
        ))
      ])),
    );
  }
}
