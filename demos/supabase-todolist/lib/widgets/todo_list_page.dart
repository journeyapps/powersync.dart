import 'dart:async';

import 'package:flutter/material.dart';
import 'package:powersync_flutter_demo/models/todo_item.dart';

import './status_app_bar.dart';
import './todo_item_dialog.dart';
import './todo_item_widget.dart';
import '../models/todo_list.dart';

void _showAddDialog(BuildContext context, TodoList list) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return TodoItemDialog(list: list);
    },
  );
}

class TodoListPage extends StatelessWidget {
  final TodoList list;

  const TodoListPage({super.key, required this.list});

  @override
  Widget build(BuildContext context) {
    final button = FloatingActionButton(
      onPressed: () {
        _showAddDialog(context, list);
      },
      tooltip: 'Add Item',
      child: const Icon(Icons.add),
    );

    return Scaffold(
        appBar: StatusAppBar(title: list.name),
        floatingActionButton: button,
        body: TodoListWidget(list: list));
  }
}

class TodoListWidget extends StatefulWidget {
  final TodoList list;

  const TodoListWidget({super.key, required this.list});

  @override
  State<StatefulWidget> createState() {
    return TodoListWidgetState();
  }
}

class TodoListWidgetState extends State<TodoListWidget> {
  List<TodoItem> _data = [];
  StreamSubscription? _subscription;

  TodoListWidgetState();

  @override
  void initState() {
    super.initState();
    final stream = widget.list.watchItems();
    _subscription = stream.listen((data) {
      if (!context.mounted) {
        return;
      }
      setState(() {
        _data = data;
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    _subscription?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: TodoList.watchSyncStatus().map((e) => e.hasSynced),
      builder: (context, snapshot) {
        if (snapshot.data ?? false) {
          return const Text('Busy with sync');
        }

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          children: _data.map((todo) {
            return TodoItemWidget(todo: todo);
          }).toList(),
        );
      },
    );
  }
}
