// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:trelloappclone_flutter/features/generateworkspace/presentation/index.dart';
import 'package:trelloappclone_flutter/utils/trello_provider.dart';
import 'package:trelloappclone_flutter/protocol/data_client.dart';
import 'package:logging/logging.dart';

import 'features/aboutboard/presentation/index.dart';
import 'features/archivedcards/presentation/index.dart';
import 'features/archivedlists/presentation/index.dart';
import 'features/board/presentation/index.dart';
import 'features/boardbackground/presentation/index.dart';
import 'features/boardmenu/presentation/index.dart';
import 'features/boardsettings/presentation/index.dart';
import 'features/carddetails/presentation/index.dart';
import 'features/copyboard/presentation/index.dart';
import 'features/createboard/presentation/index.dart';
import 'features/createcard/presentation/index.dart';
import 'features/createworkspace/presentation/index.dart';
import 'features/emailtoboard/presentation/index.dart';
import 'features/home/presentation/index.dart';
import 'features/invitemember/presentation/index.dart';
import 'features/landing/presentation/index.dart';
import 'features/members/presentation/index.dart';
import 'features/mycards/presentation/index.dart';
import 'features/notifications/presentation/index.dart';
import 'features/offlineboards/presentation/index.dart';
import 'features/powerups/presentation/index.dart';
import 'features/settings/presentation/index.dart';
import 'features/signtotrello/presentation/index.dart';
import 'features/workspace/presentation/index.dart';
import 'features/workspacemenu/presentation/index.dart';
import 'features/workspacesettings/presentation/index.dart';

// Sets up a singleton client object that can be used to talk to the server from
// anywhere in our app.
// The client is set up to connect to a Powersync project already set up.
var dataClient = DataClient();

TrelloProvider trello = TrelloProvider();

void main() async {
  // Log info from PowerSync
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    // if (kDebugMode) {
    print(
        '[${record.loggerName}] ${record.level.name}: ${record.time}: ${record.message}');

    if (record.error != null) {
      print(record.error);
    }
    if (record.stackTrace != null) {
      print(record.stackTrace);
    }
    // }
  });

  WidgetsFlutterBinding
      .ensureInitialized(); //required to get sqlite filepath from path_provider before UI has initialized
  await dataClient.initialize();
  if (dataClient.isLoggedIn()) {
    TrelloUser? user = await dataClient.getLoggedInUser();
    trello.setUser(user!);
  }
  runApp(ChangeNotifierProvider(
      create: (context) => TrelloProvider(), child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Trello App Clone',
        theme: ThemeData(
          textTheme: Theme.of(context).textTheme.apply(
                fontFamily: GoogleFonts.poppins().fontFamily,
              ),
        ),
        initialRoute: dataClient.isLoggedIn() ? '/home' : '/',
        routes: {
          '/': (context) => const Landing(),
          '/home': (context) => const Home(),
          '/notifications': (context) => const Notifications(),
          '/workspacemenu': (context) => const WorkspaceMenu(),
          '/workspacesettings': (context) => const WorkspaceSettings(),
          '/members': (context) => const Members(),
          '/invitemember': (context) => const InviteMember(),
          '/createworkspace': (context) => const CreateWorkspace(),
          '/createboard': (context) => const CreateBoard(),
          '/generateworkspace': (context) => const GenerateWorkspace(),
          '/boardbackground': (context) => const BoardBackground(),
          '/createcard': (context) => const CreateCard(),
          BoardScreen.routeName: (context) => const BoardScreen(),
          '/boardmenu': (context) => const BoardMenu(),
          '/copyboard': (context) => const CopyBoard(),
          '/boardsettings': (context) => const BoardSettings(),
          '/archivedlists': (context) => const ArchivedLists(),
          '/archivedcards': (context) => const ArchivedCards(),
          '/emailtoboard': (context) => const EmailToBoard(),
          '/aboutboard': (context) => const AboutBoard(),
          '/powerups': (context) => const PowerUps(),
          CardDetails.routeName: (context) => const CardDetails(),
          '/mycards': (context) => const MyCards(),
          '/offlineboards': (context) => const OfflineBoards(),
          '/settings': (context) => const Settings(),
          SignToTrello.routeName: (context) => const SignToTrello(),
          '/workspace': (context) => const WorkspaceScreen()
        });
  }
}
