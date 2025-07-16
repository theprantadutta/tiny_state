### 🧠 What I am Building: `tiny_state` – A Micro Global State Manager

I am making a **global, reactive state manager** that:

* Requires **no context**
* Requires **no widgets to rebuild trees**
* Works via **String-based keys (like a lightweight key-value store)**
* Is **typed**, but with dynamic fallback (opt-in)
* Has **watch + update** functionality
* Can be accessed from anywhere — inside business logic, services, or UI
* Feels like using a **ValueNotifier**, but global and enhanced

---

## ✅ MVP Core API (Minimum Viable Product)

### 1. **Watch**

```dart
final count = tinyState.watch<int>('counter', 0);
```

* Initializes with a default value if the key doesn’t exist
* Returns a `ValueNotifier<T>` so you can `.value`, `.addListener`, `.removeListener`
* This is the reactive part

### 2. **Set**

```dart
tinyState.set<int>('counter', 42);
```

* Updates the state and notifies all listeners if the value has changed
* Type-safe; throws if type mismatch (optional strict mode)

### 3. **Get**

```dart
final value = tinyState.get<int>('counter');
```

* Returns the current value
* Null-safe or with fallback if you like: `get('key') ?? defaultValue`

### 4. **Delete**

```dart
tinyState.delete('counter');
```

* Deletes the key and its listeners

---

## 🌟 Feature Buffet (Level-up my snack bar 🍔)

Let’s take this from MVP to fully snack-packed, Gen Z-approved, star-rated state manager:

---

### 🧩 1. **Type-safe, Generic API**

Every state key has an inferred type on first init. Further updates/read require the same type (optional strict mode).

```dart
tinyState.watch<String>('userName', 'Guest');
tinyState.set<String>('userName', 'Pranta');
```

> **🔥 Why?** Catch bugs early, no runtime WTFs.

---

### 🔁 2. **Selectors**

Allow watching *a transformation* of the state.

```dart
tinyState.select<int, bool>('counter', (count) => count.isEven);
```

> **🔥 Why?** Reactive logic without widget rebuilds. Use for derived values.

---

### ⛓️ 3. **Computed State**

Create state that derives from other states — auto-updates when dependencies change.

```dart
tinyState.computed<int>('total', () {
  return tinyState.get<int>('a') + tinyState.get<int>('b');
});
```

> Internally tracks dependencies and re-evaluates.

---

### 🕹️ 4. **Listeners with Lifecycle**

```dart
tinyState.listen<String>('status', (val) {
  print('Status changed: $val');
}, fireImmediately: true, once: false);
```

* Listen once
* Listen forever
* Listen and fire immediately
* Cancel with `dispose()` function

---

### 📦 5. **Scoped/Namespaced State**

```dart
tinyState.scope('profile').watch('username', 'anon');
```

* Organize states logically (`auth`, `profile`, `theme`, etc.)
* Prevents accidental key collisions

---

### 🌐 6. **Persistent State (Optional Plugin)**

Auto-save to shared\_preferences, hive, or local DB

```dart
tinyState.watch('themeMode', 'dark', persist: true);
```

> Automatically loads and saves values across app launches.

---

### 🧪 7. **Devtools / Debug Panel**

Expose an optional widget or log that shows:

* Current state
* Subscribed keys
* Listener count per key

```dart
tinyState.debug(); // dumps all keys + values + watchers
```

---

### 🧼 8. **Reset / Clear All**

```dart
tinyState.clear(); // clears all states and listeners
```

---

### 🔐 9. **Immutable Mode**

You can optionally freeze values to force immutability

```dart
tinyState.set('config', const Config(...), immutable: true);
```

---

### 🛠️ 10. **Custom Notifier Support**

Use my own notifier class for advanced use-cases.

```dart
tinyState.registerNotifier<MyNotifier>('fancy', MyNotifier());
```

---

### 🔄 11. **Async State / Futures**

Built-in handling for async values, like FutureBuilder-lite:

```dart
tinyState.watchFuture<String>('apiResult', fetchData());
```

---

## 🚀 Final API Examples – Devs Will LOVE This

```dart
// Reactive UI
ValueListenableBuilder(
  valueListenable: tinyState.watch<int>('counter', 0),
  builder: (_, count, __) => Text('Count: $count'),
);

// Logic update
void increment() {
  final current = tinyState.get<int>('counter');
  tinyState.set<int>('counter', current + 1);
}

// Listen globally
tinyState.listen<int>('counter', (newVal) {
  print('New count: $newVal');
});
```

---

## 🧠 Developer Persona

Perfect for:

* Flutter devs who hate overengineering
* Small teams
* Devs building internal tools
* Hobbyists and solo makers
* Pro devs who want control, not ceremony

---

## 🛡️ Bonus Plugin Ideas

* 🔌 Persistence Plugin
* 🧵 Riverpod/Provider adapter
* 🕶️ Debug Console widget (like Redux DevTools)
* 🕸️ Web sync (shared state across tabs)

---

## 💬 Marketing One-liner Ideas:

* “ValueNotifier walked so `tiny_state` could sprint.”
* “State management you’ll actually want to use.”
* “Snack-bar of state, not the buffet.”
* “Zero boilerplate, infinite chill.”

---
