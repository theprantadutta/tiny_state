import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiny_state/src/persistence.dart';
import 'package:tiny_state/tiny_state.dart';
import 'src/models/todo.dart';
import 'src/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  tinyState.persistenceAdapter = SharedPreferencesAdapter(prefs);

  // Initialize all the states with default values.
  tinyState.watch<int>('themeMode', ThemeMode.dark.index, persist: true);
  tinyState.watch<int>('counter', 0);
  tinyState.watch<String>('firstName', 'John');
  tinyState.watch<String>('lastName', 'Doe');
  tinyState.watch<List<Todo>>('todos', []);

  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final themeIndex = tinyState.watch<int>('themeMode', ThemeMode.dark.index);
    return ValueListenableBuilder<int>(
      valueListenable: themeIndex,
      builder: (context, index, child) {
        return MaterialApp(
          title: 'tiny_state Advanced Example',
          theme: ThemeData.light(useMaterial3: true),
          darkTheme: ThemeData.dark(useMaterial3: true),
          themeMode: ThemeMode.values[index],
          home: const HomeScreen(),
        );
      },
    );
  }
}
