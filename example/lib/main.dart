import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiny_state/tiny_state.dart';

import 'src/models/todo.dart';
import 'src/persistence/shared_preferences_adapter.dart';
import 'src/screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  tinyState
    ..persistenceAdapter = SharedPreferencesAdapter(
      prefs,
      codecs: {
        // Models need a codec. Without one, a stored todo list would decode to
        // a List<dynamic> of maps and fail the cast back to List<Todo>.
        'todos': PersistedCodec<List<Todo>>(
          encode: (todos) => todos.map((todo) => todo.toJson()).toList(),
          decode: (stored) => (stored! as List)
              .map((entry) => Todo.fromJson(entry as Map<String, dynamic>))
              .toList(),
        ),
      },
    )
    // Surface persistence and computed failures instead of letting them vanish.
    ..onError = (Object error, StackTrace stack, String context) {
      debugPrint('[tiny_state] $context: $error');
    };

  // Declaring keys up front is optional — `watch` creates them on demand — but
  // it keeps defaults and persistence flags in one readable place. Persistence
  // is a property of the key, so nothing downstream repeats the flag.
  tinyState
    ..watch<int>('themeMode', ThemeMode.dark.index, persist: true)
    ..watch<int>('counter', 0)
    ..watch<String>('firstName', 'John')
    ..watch<String>('lastName', 'Doe')
    ..watch<List<Todo>>('todos', const [], persist: true)
    ..watch<String>('note', '', persist: true)
    ..watch<int>('persistedCounter', 0, persist: true)
    ..watch<int>('inMemoryCounter', 0);

  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return TinyBuilder<int>('themeMode', ThemeMode.dark.index, (
      BuildContext context,
      int index,
    ) {
      return MaterialApp(
        title: 'tiny_state Example',
        theme: ThemeData.light(useMaterial3: true),
        darkTheme: ThemeData.dark(useMaterial3: true),
        themeMode: ThemeMode.values[index],
        home: const HomeScreen(),
      );
    });
  }
}
