import 'package:flutter/material.dart';
import 'package:trelloappclone_flutter/utils/color.dart';

class LabelDiplay extends StatefulWidget {
  final String label;
  final String color;
  const LabelDiplay({required this.label, required this.color, super.key});

  @override
  State<LabelDiplay> createState() => _LabelDiplayState();
}

class _LabelDiplayState extends State<LabelDiplay> {
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
        decoration: BoxDecoration(
            color: Color(int.parse(widget.color, radix: 16) + 0xFF000000),
            borderRadius: const BorderRadius.all(Radius.circular(5.0))),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Text(
              widget.label,
              style: TextStyle(
                  color: ((int.parse(widget.color, radix: 16)) > 186
                      ? Colors.black
                      : Colors.white)),
            ),
          ),
        ));
  }
}

class ColorSquare extends StatefulWidget {
  final String bckgrd;
  const ColorSquare({required this.bckgrd, super.key});

  @override
  State<ColorSquare> createState() => _ColorSquareState();
}

class _ColorSquareState extends State<ColorSquare> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40.0,
      width: 40.0,
      decoration: BoxDecoration(
          color: Color(
              int.parse(widget.bckgrd.substring(1, 7), radix: 16) + 0xFF000000),
          borderRadius: const BorderRadius.all(Radius.circular(5.0))),
    );
  }
}

class BlueRectangle extends StatefulWidget {
  const BlueRectangle({super.key});

  @override
  State<BlueRectangle> createState() => _BlueRectangleState();
}

class _BlueRectangleState extends State<BlueRectangle> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100.0,
      width: 300.0,
      decoration: const BoxDecoration(
          color: brandColor,
          borderRadius: BorderRadius.all(Radius.circular(5.0))),
    );
  }
}
