import 'package:flutter/material.dart';
import 'package:trelloappclone_flutter/features/drawer/presentation/index.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      drawer: const CustomDrawer(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const ListTile(
              subtitle: Text("Notifications"),
            ),
            const ListTile(
              title: Text("Open system settings"),
            ),
            const Divider(
              height: 2,
              thickness: 2,
            ),
            const ListTile(
              subtitle: Text("Application theme"),
            ),
            const ListTile(
              title: Text("Select theme"),
            ),
            const Divider(
              height: 2,
              thickness: 2,
            ),
            const ListTile(
              subtitle: Text("Accessibility"),
            ),
            ListTile(
              title: const Text("Color blind friendly mode"),
              trailing: Checkbox(value: false, onChanged: ((value) {})),
            ),
            ListTile(
              title: const Text("Enable animations"),
              trailing: Checkbox(value: true, onChanged: ((value) {})),
            ),
            ListTile(
              title: const Text("Show label names on card front"),
              trailing: Checkbox(value: false, onChanged: ((value) {})),
            ),
            const ListTile(
              subtitle: Text("Sync"),
            ),
            const ListTile(
              title: Text("Sync queue"),
            ),
            const ListTile(
              subtitle: Text("General"),
            ),
            const ListTile(
              title: Text("Profile and visibility"),
            ),
            const ListTile(
              title: Text("Create card details"),
            ),
            const ListTile(
              title: Text("Set app language"),
            ),
            ListTile(
              title: const Text("Delete account"),
              onTap: () {
                showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text(
                          "Delete account?",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        content: const Text(
                            "You must log in on the web to delete your account"),
                        actions: [
                          TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Text("CANCEL")),
                          TextButton(
                              onPressed: () {}, child: const Text("GO TO WEB"))
                        ],
                      );
                    });
              },
            ),
            const ListTile(
              title: Text("About Trello"),
            ),
            const ListTile(
              title: Text("More Atlassian apps"),
            ),
            const ListTile(
              title: Text("Contact support"),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 30.0),
              child: ListTile(
                title: const Text("Log out"),
                onTap: () {
                  Navigator.pushNamed(context, '/');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
