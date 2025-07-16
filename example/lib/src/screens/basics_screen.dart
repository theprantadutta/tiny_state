import 'package:flutter/material.dart';
import 'package:tiny_state/tiny_state.dart';

class BasicsScreen extends StatefulWidget {
  const BasicsScreen({super.key});

  @override
  State<BasicsScreen> createState() => _BasicsScreenState();
}

class _BasicsScreenState extends State<BasicsScreen> {
  VoidCallback? _counterListener;

  @override
  void initState() {
    super.initState();
    // Listen to the counter and show a SnackBar on every multiple of 5.
    _counterListener = tinyState.listen<int>('counter', (value) {
      if (mounted && value != 0 && value % 5 == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('The count is now $value!'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    // It's crucial to cancel the listener when the widget is disposed.
    _counterListener?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final counter = tinyState.watch<int>('counter', 0);
    final isEven = tinyState.select<int, bool>('counter', (val) => val.isEven);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Basics',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                const Text(
                  'This screen demonstrates the core methods:\n`watch`, `select`, `set`, `get`, `listen`, and `delete`.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ValueListenableBuilder<int>(
                  valueListenable: counter,
                  builder: (context, count, child) {
                    return Text(
                      '$count',
                      style: Theme.of(context).textTheme.displayLarge,
                    );
                  },
                ),
                const SizedBox(height: 10),
                ValueListenableBuilder<bool>(
                  valueListenable: isEven,
                  builder: (context, even, child) {
                    return Text(
                      even ? 'Even' : 'Odd',
                      style: Theme.of(context).textTheme.labelLarge,
                    );
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FloatingActionButton(
                      heroTag: 'increment',
                      onPressed: () => tinyState.update<int>(
                        'counter',
                        (count) => count + 1,
                      ),
                      child: const Icon(Icons.add),
                    ),
                    const SizedBox(width: 16),
                    FloatingActionButton(
                      heroTag: 'decrement',
                      onPressed: () => tinyState.update<int>(
                        'counter',
                        (count) => count - 1,
                      ),
                      child: const Icon(Icons.remove),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => tinyState.reset('counter'),
                  child: const Text('Reset Counter'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
