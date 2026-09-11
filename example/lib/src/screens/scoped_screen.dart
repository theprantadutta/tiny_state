import 'package:flutter/material.dart';
import 'package:tiny_state/tiny_state.dart';

class ScopedScreen extends StatelessWidget {
  const ScopedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Both counters use the key "value". Scopes keep them apart — and '
              'a literal "counterA/value" is rejected, so the namespaces can '
              'never collide.',
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 20),
          ScopedCounter(scopeName: 'counterA'),
          SizedBox(height: 20),
          ScopedCounter(scopeName: 'counterB'),
        ],
      ),
    );
  }
}

class ScopedCounter extends StatelessWidget {
  const ScopedCounter({super.key, required this.scopeName});

  final String scopeName;

  @override
  Widget build(BuildContext context) {
    final scope = tinyState.scope(scopeName);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            Text(scopeName, style: Theme.of(context).textTheme.titleMedium),
            TinyBuilder<int>(
              'value',
              0,
              (BuildContext context, int value) => Text(
                '$value',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              scope: scope,
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () =>
                      scope.update<int>('value', (int value) => value + 1),
                ),
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () =>
                      scope.update<int>('value', (int value) => value - 1),
                ),
                // `reset` and not `scope.clear()`: clearing deletes and
                // disposes the notifier this widget is listening to.
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => scope.reset('value'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
