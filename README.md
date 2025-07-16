# Tiny State: State Management You'll Actually Want to Use

[![Build and Test](https://github.com/theprantadutta/tiny_state/actions/workflows/build.yml/badge.svg)](https://github.com/theprantadutta/tiny_state/actions/workflows/build.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A minimalistic, intuitive, and powerful state management library for Flutter that feels like using a `ValueNotifier`, but global and enhanced. It's designed to be simple, fast, and require zero boilerplate.

## Philosophy: The "Snack Bar" of State Management

`tiny_state` is designed for developers who find other state management solutions like Provider, Riverpod, or BLoC to be overly complex for their needs. It's the "snack bar" of state, not the "all-you-can-eat buffet."

-   **When to use `tiny_state`**: It's perfect for small to medium-sized projects, rapid prototyping, or managing simple, global state (like theme, user authentication, or shopping cart).
-   **When to use other solutions**: For large-scale applications with complex dependency graphs and intricate state logic, more robust solutions like **Riverpod** or **BLoC** are recommended. `tiny_state` is not designed to replace them, but to offer a simpler alternative for simpler problems.

## Features

Based on our `implementation_status.md`, here are the features currently available:

-   ✅ **Global & Scoped State:** Manage state globally or within specific scopes (`tinyState.scope('name')`) to keep your app organized.
-   ✅ **Reactive UI:** Automatically update your UI when the state changes using `watch`, `select`, and `computed` methods.
-   ✅ **Type-Safe API:** Catch bugs early with a type-safe API that uses generics.
-   ✅ **Selectors:** Watch a transformed, derived value from a piece of state (`tinyState.select(...)`).
-   ✅ **Computed State:** Create state that automatically updates when its dependencies change (`tinyState.computed(...)`).
-   ✅ **Lifecycle Listeners:** Listen to state changes with fine-grained control (`fireImmediately`, `once`).
-   ✅ **State Persistence:** Easily persist and rehydrate your app's state across sessions using a `TinyStatePersistenceAdapter`.
-   ✅ **Async State:** Built-in support for handling futures and updating the UI based on their status (`tinyState.watchFuture(...)`).
-   ✅ **Reset & Clear:** Easily reset a state to its default value or clear all states at once.

## Core API

### `watch`

Initializes state if it doesn't exist and returns a `ValueNotifier<T>` to make your UI reactive.

```dart
final counter = tinyState.watch<int>('counter', 0);
```

### `get`

Retrieves the current value of a state without subscribing to changes.

```dart
final currentValue = tinyState.get<int>('counter');
```

### `set`

Updates the value of a state and notifies all listeners.

```dart
tinyState.set<int>('counter', 10);
```

### `update`

Provides a safe way to update a state based on its current value, preventing race conditions.

```dart
tinyState.update<int>('counter', (currentValue) => currentValue + 1);
```

### `reset`

Reverts a state to its initial default value.

```dart
tinyState.reset('counter');
```

### `delete`

Removes a state from the store.

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
