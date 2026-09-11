import 'package:flutter/material.dart';
import 'package:tiny_state/tiny_state.dart';

class BasicsScreen extends StatefulWidget {
  const BasicsScreen({super.key});

  @override
  State<BasicsScreen> createState() => _BasicsScreenState();
}

class _BasicsScreenState extends State<BasicsScreen> {
  VoidCallback? _cancelCounterListener;

  @override
  void initState() {
    super.initState();

    // `listen` and `select` require the key to exist; `watch` is what creates
    // it. Declaring it here keeps the screen self-sufficient instead of
    // relying on main() having run first.
    tinyState.watch<int>('counter', 0);

    // Show a SnackBar on every multiple of five.
    _cancelCounterListener = tinyState.listen<int>('counter', (int value) {
      if (!mounted || value == 0 || value % 5 != 0) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('The count is now $value!'),
          duration: const Duration(seconds: 1),
        ),
      );
    });
  }

  @override
  void dispose() {
    // Always cancel a listen() subscription with the widget that owns it.
    _cancelCounterListener?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // `select` is memoized on (key, id), so calling it from build returns the
    // same listenable on every rebuild instead of creating a new one.
    final isEven = tinyState.select<int, bool>(
      'counter',
      (int value) => value.isEven,
      id: 'isEven',
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Basics',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                const Text(
                  'watch, get, set, update, reset, delete — plus select and '
                  'listen.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TinyBuilder<int>(
                  'counter',
                  0,
                  (BuildContext context, int count) => Text(
                    '$count',
                    style: Theme.of(context).textTheme.displayLarge,
                  ),
                ),
                const SizedBox(height: 10),
                TinyBuilder<bool>.listen(
                  isEven,
                  (BuildContext context, bool even) => Text(
                    even ? 'Even' : 'Odd',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FloatingActionButton(
                      heroTag: 'increment',
                      onPressed: () => tinyState.update<int>(
                        'counter',
                        (int count) => count + 1,
                      ),
                      child: const Icon(Icons.add),
                    ),
                    const SizedBox(width: 16),
                    FloatingActionButton(
                      heroTag: 'decrement',
                      onPressed: () => tinyState.update<int>(
                        'counter',
                        (int count) => count - 1,
                      ),
                      child: const Icon(Icons.remove),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => tinyState.reset('counter'),
                  child: const Text('Reset counter'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
