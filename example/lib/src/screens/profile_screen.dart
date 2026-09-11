import 'package:flutter/material.dart';
import 'package:tiny_state/tiny_state.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Two inputs, one derived value. Dependencies are discovered from the
    // `get` calls below — nothing is registered by hand.
    final fullName = tinyState.computed<String>('fullName', () {
      final first = tinyState.get<String>('firstName') ?? '';
      final last = tinyState.get<String>('lastName') ?? '';
      return '$first $last'.trim();
    });

    // A second computed, built on the first. Derived state composes.
    final initials = tinyState.computed<String>('initials', () {
      final parts = (tinyState.get<String>('fullName') ?? '')
          .split(' ')
          .where((String part) => part.isNotEmpty);
      return parts.map((String part) => part[0].toUpperCase()).join();
    });

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TinyBuilder<String>.listen(
                  initials,
                  (BuildContext context, String value) => CircleAvatar(
                    radius: 28,
                    child: Text(value.isEmpty ? '?' : value),
                  ),
                ),
                const SizedBox(height: 12),
                TinyBuilder<String>.listen(
                  fullName,
                  (BuildContext context, String name) => Text(
                    'Welcome, $name',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: tinyState.get<String>('firstName'),
                        onChanged: (String value) =>
                            tinyState.set<String>('firstName', value),
                        decoration: const InputDecoration(
                          labelText: 'First name',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        initialValue: tinyState.get<String>('lastName'),
                        onChanged: (String value) =>
                            tinyState.set<String>('lastName', value),
                        decoration: const InputDecoration(
                          labelText: 'Last name',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Text('Theme', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text(
                  'Declared with persist: true, so every change is saved '
                  'without repeating the flag here.',
                  textAlign: TextAlign.center,
                ),
                TinyBuilder<int>(
                  'themeMode',
                  ThemeMode.dark.index,
                  (BuildContext context, int index) => Switch(
                    value: ThemeMode.values[index] == ThemeMode.dark,
                    onChanged: (bool isDark) => tinyState.set<int>(
                      'themeMode',
                      (isDark ? ThemeMode.dark : ThemeMode.light).index,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
