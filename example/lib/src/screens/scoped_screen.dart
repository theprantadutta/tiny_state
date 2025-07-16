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
          Text(
            'This screen demonstrates how to use `scope` to create isolated state containers.',
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          ScopedCounter(scopeName: 'CounterA'),
          SizedBox(height: 20),
          ScopedCounter(scopeName: 'CounterB'),
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
    final counter = scope.watch<int>('value', 0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            Text(scopeName, style: Theme.of(context).textTheme.headlineSmall),
            ValueListenableBuilder<int>(
              valueListenable: counter,
              builder: (context, value, child) {
                return Text(
                  '$value',
                  style: Theme.of(context).textTheme.displayMedium,
                );
              },
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () =>
                      scope.set('value', (scope.get<int>('value') ?? 0) + 1),
                ),
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () =>
                      scope.set('value', (scope.get<int>('value') ?? 0) - 1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
