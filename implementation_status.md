# `tiny_state` Feature Implementation Status

This document tracks the implementation progress of the features defined in `features.md`.

## ✅ MVP Core API (Minimum Viable Product)

- [x] **Watch:** Implemented (`tinyState.watch<T>('key', defaultValue)`)
- [x] **Set:** Implemented (`tinyState.set<T>('key', value)`)
- [x] **Get:** Implemented (`tinyState.get<T>('key')`)
- [x] **Delete:** Implemented (`tinyState.delete('key')`)

**Conclusion:** The core MVP is **100% complete and tested.**

---

## 🌟 Feature Buffet (Next Steps)

- [x] **1. Type-safe, Generic API:** The core is generic, but we can add stricter type checking.
- [x] **2. Selectors:** Implemented (`tinyState.select<T, R>('key', (value) => ...)`)
- [x] **3. Computed State:** Implemented (`tinyState.computed<T>('key', () => ...)`).
- [x] **4. Listeners with Lifecycle:** Implemented (`tinyState.listen<T>(...)`).
- [x] **5. Scoped/Namespaced State:** Implemented (`tinyState.scope('name')`).
- [x] **6. Persistent State (Optional Plugin):** Implemented via `TinyStatePersistenceAdapter`.
- [ ] **7. Devtools / Debug Panel:** Not implemented.
- [x] **8. Reset / Clear All:** Implemented (`tinyState.clear()` and `tinyState.delete('key')`).
- [ ] **9. Immutable Mode:** Not implemented.
- [ ] **10. Custom Notifier Support:** Not implemented.
- [x] **11. Async State / Futures:** Implemented (`tinyState.watchFuture(...)`).