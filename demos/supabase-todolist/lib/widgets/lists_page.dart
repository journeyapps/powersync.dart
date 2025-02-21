import 'dart:async';

import 'package:flutter/material.dart';
import 'package:powersync/powersync.dart';

import './list_item.dart';
import './list_item_dialog.dart';
import '../main.dart';
import '../models/todo_list.dart';

void _showAddDialog(BuildContext context) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return const ListItemDialog();
    },
  );
}

class ListsPage extends StatelessWidget {
  const ListsPage({super.key});

  @override
  Widget build(BuildContext context) {
    const content = ListsWidget();

    final button = FloatingActionButton(
      onPressed: () {
        _showAddDialog(context);
      },
      tooltip: 'Create List',
      child: const Icon(Icons.add),
    );

    final page = MyHomePage(
      title: 'Todo Lists',
      content: content,
      floatingActionButton: button,
    );
    return page;
  }
}

class ListsWidget extends StatefulWidget {
  const ListsWidget({super.key});

  @override
  State<StatefulWidget> createState() {
    return _ListsWidgetState();
  }
}

class _ListsWidgetState extends State<ListsWidget> {
  static final _listsPriority = BucketPriority(1);

  List<TodoList> _data = [];
  bool hasSynced = false;
  StreamSubscription? _subscription;
  StreamSubscription? _syncStatusSubscription;

  _ListsWidgetState();

  @override
  void initState() {
    super.initState();
    final stream = TodoList.watchListsWithStats();
    _subscription = stream.listen((data) {
      if (!context.mounted) {
        return;
      }
      setState(() {
        _data = data;
      });
    });
    _syncStatusSubscription = TodoList.watchSyncStatus().listen((status) {
      if (!context.mounted) {
        return;
      }
      setState(() {
        hasSynced = status.statusForPriority(_listsPriority).hasSynced ?? false;
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    _subscription?.cancel();
    _syncStatusSubscription?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return !hasSynced
        ? const Text("Busy with sync...")
        : ListView(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            children: _data.map((list) {
              return ListItemWidget(list: list);
            }).toList(),
          );
  }
}
