import 'dart:async';

import 'package:drift_riverpod/drift_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_todolist_drift/database.dart';
import 'package:supabase_todolist_drift/powersync.dart';

import 'status_app_bar.dart';
import 'todo_item_dialog.dart';
import 'todo_item_widget.dart';

part 'todo_list_page.g.dart';

@queryProvider
final _todosIn = driftDatabase
    .watchTodos((list) => 'SELECT * FROM todos WHERE list_id = $list;');

void _showAddDialog(BuildContext context, ListItem list) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return TodoItemDialog(list: list);
    },
  );
}

class TodoListPage extends StatelessWidget {
  final ListItem list;

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
      body: TodoListWidget(list: list),
    );
  }
}

final class TodoListWidget extends ConsumerWidget {
  final ListItem list;

  const TodoListWidget({super.key, required this.list});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(_todosIn((list.id,)));

    return items.maybeWhen(
      data: (items) => ListView(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        children: items.map((todo) {
          return TodoItemWidget(todo: todo);
        }).toList(),
      ),
      orElse: () => const CircularProgressIndicator(),
    );
  }
}
