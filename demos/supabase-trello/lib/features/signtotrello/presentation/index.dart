import 'package:flutter/material.dart';
import 'package:trelloappclone_flutter/features/signtotrello/domain/sign_arguments.dart';
import 'package:trelloappclone_flutter/utils/color.dart';

import '../../../utils/config.dart';
import '../../../utils/service.dart';

class SignToTrello extends StatefulWidget {
  const SignToTrello({super.key});

  @override
  State<SignToTrello> createState() => _SignToTrelloState();

  static const routeName = '/sign';
}

class _SignToTrelloState extends State<SignToTrello> with Service {
  final TextEditingController emailcontroller = TextEditingController();
  final TextEditingController usernamecontroller = TextEditingController();
  final TextEditingController passwordcontroller = TextEditingController();
  final TextEditingController confirmcontroller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as SignArguments;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            (args.type == Sign.signUp) ? "Sign up" : " Log in to continue"),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(top: 10.0),
          child: Column(
            children: [
              Image.asset(
                logo,
                width: 30,
                height: 30,
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0, top: 10.0),
                child: Text(
                  (args.type == Sign.signUp)
                      ? "Sign up to continue"
                      : "Log in to continue",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.only(left: 20.0, right: 20.0, top: 10.0),
                child: TextField(
                  controller: emailcontroller,
                  textCapitalization: TextCapitalization.none,
                  keyboardType: TextInputType.emailAddress,
                  decoration:
                      const InputDecoration(hintText: "Enter your email"),
                ),
              ),
              (args.type == Sign.signUp)
                  ? Padding(
                      padding: const EdgeInsets.only(
                          left: 20.0, right: 20.0, top: 10.0),
                      child: TextField(
                        controller: usernamecontroller,
                        keyboardType: TextInputType.name,
                        decoration:
                            const InputDecoration(hintText: "Enter your name"),
                      ),
                    )
                  : const SizedBox.shrink(),
              Padding(
                padding: const EdgeInsets.only(
                    left: 20.0, right: 20.0, top: 10.0, bottom: 10.0),
                child: TextField(
                  controller: passwordcontroller,
                  obscureText: true,
                  decoration:
                      const InputDecoration(hintText: "Enter your password"),
                ),
              ),
              (args.type == Sign.signUp)
                  ? Padding(
                      padding: const EdgeInsets.only(
                          left: 20.0, right: 20.0, top: 10.0),
                      child: TextField(
                        controller: confirmcontroller,
                        obscureText: true,
                        decoration: const InputDecoration(
                            hintText: "Confirm your password"),
                      ))
                  : const SizedBox.shrink(),
              (args.type == Sign.signUp)
                  ? const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text(
                          "By signing up, I accept the Atlassian Cloud Terms of Service and acknowledge the Privacy Policy"),
                    )
                  : const SizedBox.shrink(),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                height: 50,
                child: ElevatedButton(
                    onPressed: () {
                      if (args.type == Sign.signUp && validateSignUp()) {
                        signUp(
                            name: usernamecontroller.text,
                            email: emailcontroller.text,
                            password: passwordcontroller.text,
                            context: context);
                      } else if (args.type == Sign.logIn && validateLogin()) {
                        logIn(emailcontroller.text, passwordcontroller.text,
                            context);
                      }
                    },
                    style:
                        ElevatedButton.styleFrom(backgroundColor: brandColor),
                    child: Text(
                        (args.type == Sign.signUp) ? "Sign up" : "Log in")),
              ),
              // ListTile(
              //   onTap: () {},
              //   leading: Icon(
              //     MdiIcons.google,
              //     color: brandColor,
              //   ),
              //   title: const Text(
              //     "CONTINUE WITH GOOGLE",
              //     style: TextStyle(fontWeight: FontWeight.bold),
              //   ),
              // ),
              // ListTile(
              //   onTap: () {},
              //   leading: Icon(
              //     MdiIcons.microsoft,
              //     color: brandColor,
              //   ),
              //   title: const Text(
              //     "CONTINUE WITH MICROSOFT",
              //     style: TextStyle(fontWeight: FontWeight.bold),
              //   ),
              // ),
              // ListTile(
              //   onTap: () {},
              //   leading: Icon(
              //     MdiIcons.apple,
              //     color: brandColor,
              //   ),
              //   title: const Text(
              //     "CONTINUE WITH APPLE",
              //     style: TextStyle(fontWeight: FontWeight.bold),
              //   ),
              // ),
              // GestureDetector(
              //   onTap: () {},
              //   child: Text(
              //     (args.type == Sign.signUp)
              //         ? "Already have an Atlassian account? Log in"
              //         : "Can't log in? Create an account",
              //     style: const TextStyle(
              //         decoration: TextDecoration.underline, color: brandColor),
              //   ),
              // )
            ],
          ),
        ),
      ),
    );
  }

  bool validateSignUp() {
    if (emailcontroller.text.isNotEmpty &&
        emailcontroller.text.isNotEmpty &&
        passwordcontroller.text.isNotEmpty &&
        confirmcontroller.text.isNotEmpty &&
        confirmcontroller.text == passwordcontroller.text) {
      return true;
    }
    return false;
  }

  bool validateLogin() {
    if (emailcontroller.text.isNotEmpty && passwordcontroller.text.isNotEmpty) {
      return true;
    }
    return false;
  }
}
