import 'package:flutter/material.dart';
import 'package:tiny_state/tiny_state.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fullName = tinyState.computed<String>('fullName', () {
      final first = tinyState.get<String>('firstName') ?? '';
      final last = tinyState.get<String>('lastName') ?? '';
      return '$first $last';
    });
    final themeIndex = tinyState.watch<int>('themeMode', ThemeMode.dark.index);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<String>(
                  valueListenable: fullName,
                  builder: (context, name, child) {
                    return Text(
                      'Welcome, $name',
                      style: Theme.of(context).textTheme.headlineSmall,
                    );
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (value) =>
                            tinyState.set<String>('firstName', value),
                        decoration: const InputDecoration(
                          labelText: 'First Name',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        onChanged: (value) =>
                            tinyState.set<String>('lastName', value),
                        decoration: const InputDecoration(
                          labelText: 'Last Name',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Text('Theme', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 10),
                const Text(
                  'This theme setting is persisted to local storage.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                ValueListenableBuilder<int>(
                  valueListenable: themeIndex,
                  builder: (context, index, child) {
                    return Switch(
                      value: ThemeMode.values[index] == ThemeMode.dark,
                      onChanged: (isDark) {
                        tinyState.set<int>(
                          'themeMode',
                          isDark ? ThemeMode.dark.index : ThemeMode.light.index,
                          persist: true,
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
