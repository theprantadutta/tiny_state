import 'package:flutter/material.dart';
import 'package:tiny_state/tiny_state.dart';
import 'package:uuid/uuid.dart';

import '../models/todo.dart';

class TodosScreen extends StatefulWidget {
  const TodosScreen({super.key});

  @override
  State<TodosScreen> createState() => _TodosScreenState();
}

class _TodosScreenState extends State<TodosScreen> {
  static const _uuid = Uuid();
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;

    // `update` must return a NEW list — mutating the existing one in place
    // would compare equal and never notify.
    tinyState.update<List<Todo>>(
      'todos',
      (List<Todo> todos) => [...todos, Todo(id: _uuid.v4(), title: title)],
    );
    _controller.clear();
  }

  void _toggle(String id, bool completed) {
    tinyState.update<List<Todo>>(
      'todos',
      (List<Todo> todos) => [
        for (final todo in todos)
          if (todo.id == id) todo.copyWith(completed: completed) else todo,
      ],
    );
  }

  void _remove(String id) {
    tinyState.update<List<Todo>>(
      'todos',
      (List<Todo> todos) => todos.where((Todo todo) => todo.id != id).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Derived state: re-evaluated automatically whenever 'todos' changes.
    final completedCount = tinyState.computed<int>(
      'completedCount',
      () => (tinyState.get<List<Todo>>('todos') ?? const [])
          .where((Todo todo) => todo.completed)
          .length,
    );

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'A list of models, a computed count derived from it, and a codec '
            'so the whole list survives a restart.',
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  onSubmitted: (_) => _add(),
                  decoration: const InputDecoration(
                    labelText: 'New todo',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(onPressed: _add, icon: const Icon(Icons.add)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: TinyBuilder<int>.listen(
            completedCount,
            (BuildContext context, int count) => Text(
              '$count completed',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        Expanded(
          child: TinyBuilder<List<Todo>>('todos', const [], (
            BuildContext context,
            List<Todo> todos,
          ) {
            if (todos.isEmpty) {
              return const Center(child: Text('Nothing here yet.'));
            }
            return ListView.builder(
              itemCount: todos.length,
              itemBuilder: (BuildContext context, int index) {
                final todo = todos[index];
                return CheckboxListTile(
                  value: todo.completed,
                  title: Text(
                    todo.title,
                    style: TextStyle(
                      decoration: todo.completed
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  onChanged: (bool? value) => _toggle(todo.id, value ?? false),
                  secondary: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _remove(todo.id),
                  ),
                );
              },
            );
          }),
        ),
      ],
    );
  }
}
