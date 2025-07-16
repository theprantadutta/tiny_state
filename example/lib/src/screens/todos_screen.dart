import 'package:flutter/material.dart';
import 'package:tiny_state/tiny_state.dart';
import 'package:uuid/uuid.dart';
import '../models/todo.dart';

class TodosScreen extends StatelessWidget {
  const TodosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final todos = tinyState.watch<List<Todo>>('todos', []);
    final textController = TextEditingController();
    const uuid = Uuid();

    final completedCount = tinyState.computed<int>('completedCount', () {
      final todoList = tinyState.get<List<Todo>>('todos') ?? [];
      return todoList.where((todo) => todo.completed).length;
    });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'This screen shows how to manage a list of objects and use a `computed` state to derive data from it.',
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: textController,
                  decoration: const InputDecoration(
                    labelText: 'Add a new todo',
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  if (textController.text.isNotEmpty) {
                    final currentTodos = List<Todo>.from(
                      tinyState.get<List<Todo>>('todos') ?? [],
                    );
                    currentTodos.add(
                      Todo(title: textController.text, id: uuid.v4()),
                    );
                    tinyState.set<List<Todo>>('todos', currentTodos);
                    textController.clear();
                  }
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: ValueListenableBuilder<int>(
            valueListenable: completedCount,
            builder: (context, count, child) {
              final total = (tinyState.get<List<Todo>>('todos') ?? []).length;
              return Text('$count of $total completed');
            },
          ),
        ),
        Expanded(
          child: ValueListenableBuilder<List<Todo>>(
            valueListenable: todos,
            builder: (context, todoList, child) {
              if (todoList.isEmpty) {
                return const Center(child: Text('No todos yet!'));
              }
              return ListView.builder(
                itemCount: todoList.length,
                itemBuilder: (context, index) {
                  final todo = todoList[index];
                  return ListTile(
                    title: Text(
                      todo.title,
                      style: TextStyle(
                        decoration: todo.completed
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                    leading: Checkbox(
                      value: todo.completed,
                      onChanged: (value) {
                        final currentTodos = List<Todo>.from(
                          tinyState.get<List<Todo>>('todos') ?? [],
                        );
                        currentTodos[index].completed = value!;
                        tinyState.set<List<Todo>>('todos', currentTodos);
                      },
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        final currentTodos = List<Todo>.from(
                          tinyState.get<List<Todo>>('todos') ?? [],
                        );
                        currentTodos.removeAt(index);
                        tinyState.set<List<Todo>>('todos', currentTodos);
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
