import 'package:flutter/material.dart';
import 'package:tiny_state/tiny_state.dart';

class PersistenceScreen extends StatelessWidget {
  const PersistenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final note = tinyState.watch<String>('note', '', persist: true);
    final persistedCounter = tinyState.watch<int>(
      'persistedCounter',
      0,
      persist: true,
    );
    final inMemoryCounter = tinyState.watch<int>('inMemoryCounter', 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Type a note, then hot-restart the app. The note survives. '
            'The persisted counter survives. The plain in-memory counter resets.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Persisted note',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<String>(
                    valueListenable: note,
                    builder: (context, value, _) {
                      return TextFormField(
                        initialValue: value,
                        key: ValueKey(value.isEmpty ? 'empty' : 'has-note'),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Write something...',
                        ),
                        onChanged: (text) => tinyState.set<String>(
                          'note',
                          text,
                          persist: true,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear note'),
                      onPressed: () =>
                          tinyState.set<String>('note', '', persist: true),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _CounterCard(
                  title: 'Persisted',
                  notifier: persistedCounter,
                  onIncrement: () => tinyState.update<int>(
                    'persistedCounter',
                    (v) => v + 1,
                    persist: true,
                  ),
                  onReset: () =>
                      tinyState.set<int>('persistedCounter', 0, persist: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CounterCard(
                  title: 'In-memory',
                  notifier: inMemoryCounter,
                  onIncrement: () => tinyState.update<int>(
                    'inMemoryCounter',
                    (v) => v + 1,
                  ),
                  onReset: () => tinyState.set<int>('inMemoryCounter', 0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CounterCard extends StatelessWidget {
  const _CounterCard({
    required this.title,
    required this.notifier,
    required this.onIncrement,
    required this.onReset,
  });

  final String title;
  final ValueNotifier<int> notifier;
  final VoidCallback onIncrement;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            ValueListenableBuilder<int>(
              valueListenable: notifier,
              builder: (context, value, _) {
                return Text(
                  '$value',
                  style: Theme.of(context).textTheme.displayMedium,
                );
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: onIncrement,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: onReset,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
