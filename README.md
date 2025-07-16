# Tiny State

A minimalistic, intuitive, and powerful state management library for Flutter that helps you manage your app's state with ease.

## Features

- **Global & Scoped State:** Manage state globally or within specific scopes to keep your app organized.
- **Reactive UI:** Automatically update your UI when the state changes using `watch`, `select`, and `computed` methods.
- **State Persistence:** Easily persist and rehydrate your app's state across sessions.
- **Asynchronous Actions:** Built-in support for handling futures and updating the UI based on their status.
- **Developer Friendly:** Simple API that's easy to learn and use, with powerful features for complex scenarios.

## Getting Started

To get started, add `tiny_state` to your `pubspec.yaml`:

```yaml
dependencies:
  tiny_state: ^1.0.0
```

Then, import it into your Dart files:

```dart
import 'package:tiny_state/tiny_state.dart';
```

## Core Concepts

### `watch`

The `watch` method is the primary way to get a `ValueNotifier` for a piece of state. If the state doesn't exist, it will be created with the provided default value.

```dart
final counter = tinyState.watch<int>('counter', 0);
```

### `get`

The `get` method retrieves the current value of a state without subscribing to changes.

```dart
final currentValue = tinyState.get<int>('counter');
```

### `set`

The `set` method updates the value of a state and notifies all listeners.

```dart
tinyState.set<int>('counter', 10);
```

### `update`

The `update` method provides a safe way to update a state based on its current value.

```dart
tinyState.update<int>('counter', (currentValue) => currentValue + 1);
```

### `reset`

The `reset` method reverts a state to its initial default value.

```dart
tinyState.reset('counter');
```

### `delete`

The `delete` method removes a state from the store.

```dart
tinyState.delete('counter');
```

## Example

Our example app demonstrates the core features of `tiny_state` across four different screens:

### Home Screen

The home screen provides a central navigation hub to explore the different features of the library.

![Home Screen](https://via.placeholder.com/300x600.png?text=Home+Screen)

### Basics Screen

This screen covers the fundamental methods for managing state, including `watch`, `get`, `set`, `update`, `reset`, and `delete`.

![Basics Screen](https://via.placeholder.com/300x600.png?text=Basics+Screen)

### Todos Screen

A classic "to-do list" example that showcases how to manage a list of items, including adding, updating, and deleting them.

![Todos Screen](https://via.placeholder.com/300x600.png?text=Todos+Screen)

### Scoped Screen

This screen demonstrates how to use scopes to isolate state and prevent key collisions in larger applications.

![Scoped Screen](https://via.placeholder.com/300x600.png?text=Scoped+Screen)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
