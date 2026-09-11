import 'package:flutter/material.dart';
import 'package:tiny_state/tiny_state.dart';

class PersistenceScreen extends StatelessWidget {
  const PersistenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Type a note, then hot-restart. The note and the persisted counter '
            'survive; the in-memory counter resets. Reset deletes the stored '
            'entry, so the code default wins next launch.',
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
                  TinyBuilder<String>('note', '', (
                    BuildContext context,
                    String value,
                  ) {
                    return TextFormField(
                      key: ValueKey<bool>(value.isEmpty),
                      initialValue: value,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Write something...',
                      ),
                      // No `persist:` flag here — the key was declared
                      // persisted at watch time.
                      onChanged: (String text) =>
                          tinyState.set<String>('note', text),
                    );
                  }),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.clear),
                      label: const Text('Reset note'),
                      onPressed: () => tinyState.reset('note'),
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
                  stateKey: 'persistedCounter',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _CounterCard(
                  title: 'In-memory',
                  stateKey: 'inMemoryCounter',
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
  const _CounterCard({required this.title, required this.stateKey});

  final String title;
  final String stateKey;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            TinyBuilder<int>(
              stateKey,
              0,
              (BuildContext context, int value) => Text(
                '$value',
                style: Theme.of(context).textTheme.displaySmall,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () =>
                      tinyState.update<int>(stateKey, (int value) => value + 1),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => tinyState.reset(stateKey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
