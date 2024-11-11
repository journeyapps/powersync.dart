import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import './powersync.dart';
import 'widgets/benchmark_items_page.dart';
import './widgets/query_widget.dart';
import './widgets/status_app_bar.dart';

void main() async {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    if (kDebugMode) {
      print(
          '[${record.loggerName}] ${record.level.name}: ${record.time}: ${record.message}');

      if (record.error != null) {
        print(record.error);
      }
      if (record.stackTrace != null) {
        print(record.stackTrace);
      }
    }
  });

  WidgetsFlutterBinding
      .ensureInitialized(); //required to get sqlite filepath from path_provider before UI has initialized
  await openDatabase();
  runApp(const MyApp());
}

const defaultQuery = 'select * from benchmark_items';

const listsPage = BenchmarkItemsPage();
const homePage = listsPage;

const sqlConsolePage = Scaffold(
    appBar: StatusAppBar(title: 'SQL Console'),
    body: QueryWidget(defaultQuery: defaultQuery));

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'PowerSync Benchmarks',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: homePage);
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage(
      {super.key,
      required this.title,
      required this.content,
      this.floatingActionButton});

  final String title;
  final Widget content;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: StatusAppBar(title: title),
      body: content,
      floatingActionButton: floatingActionButton,
      drawer: Drawer(
        // Add a ListView to the drawer. This ensures the user can scroll
        // through the options in the drawer if there isn't enough vertical
        // space to fit everything.
        child: ListView(
          // Important: Remove any padding from the ListView.
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(''),
            ),
            ListTile(
              title: const Text('SQL Console'),
              onTap: () {
                var navigator = Navigator.of(context);
                navigator.pop();

                navigator.push(MaterialPageRoute(
                  builder: (context) => sqlConsolePage,
                ));
              },
            ),
          ],
        ),
      ),
    );
  }
}
