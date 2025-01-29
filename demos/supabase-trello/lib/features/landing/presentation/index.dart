import 'package:flutter/material.dart';
import 'package:trelloappclone_flutter/features/landing/presentation/bottomsheet.dart';

import '../../../utils/color.dart';
import '../../../utils/config.dart';
import '../../../utils/constant.dart';
import '../../../utils/service.dart';

class Landing extends StatefulWidget {
  const Landing({super.key});

  @override
  State<Landing> createState() => _LandingState();
}

class _LandingState extends State<Landing> with Service {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.asset(
              logo,
              width: 30,
              height: 30,
            ),
          ),
          Image.asset(
            landingImage,
            height: MediaQuery.of(context).size.height * 0.4,
          ),
          const Padding(
            padding: EdgeInsets.all(25.0),
            child: Text(
              headline,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            margin: const EdgeInsets.all(8.0),
            width: MediaQuery.of(context).size.width * 0.8,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                    context: context,
                    builder: (BuildContext context) {
                      return const LandingBottomSheet(Sign.signUp);
                    });
              },
              child: const Text("Sign up"),
            ),
          ),
          Container(
            margin: const EdgeInsets.all(8.0),
            width: MediaQuery.of(context).size.width * 0.8,
            height: 50,
            child: OutlinedButton(
              onPressed: () {
                showModalBottomSheet(
                    context: context,
                    builder: (BuildContext context) {
                      return const LandingBottomSheet(Sign.logIn);
                    });
              },
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(width: 1.0, color: brandColor)),
              child: const Text("Log in"),
            ),
          ),
          const Text(
            terms,
            textAlign: TextAlign.center,
          ),
          const SizedBox(
            height: 10,
          ),
          const Text(
            contact,
            style: TextStyle(decoration: TextDecoration.underline),
          )
        ],
      )),
    );
  }
}
