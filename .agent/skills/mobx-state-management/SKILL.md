---
name: mobx-state-management
description: >
  When working with MobX stores in this Flutter app. Use this skill whenever creating, modifying,
  or debugging MobX stores, observables, actions, computed values, or Observer widgets.
  Also trigger when the user mentions state management, store patterns, reactivity,
  code generation with build_runner/mobx_codegen, or when debugging widget rebuild issues.
---

# MobX State Management

## When to use

- Creating a new feature store
- Adding observables, actions, or computed values
- Debugging widget not rebuilding or rebuilding too much
- Running `build_runner` for code generation
- Connecting stores to UI with `Observer` widget

## Store Structure Pattern

Every store in this codebase follows this exact pattern:

```dart
import 'package:mobx/mobx.dart';

part 'feature_store.g.dart';

class FeatureStore = _FeatureStore with _$FeatureStore;

abstract class _FeatureStore with Store {
  // Dependencies injected via constructor
  final SomeRepository _repo;
  final SessionStore _sessionStore;

  _FeatureStore(this._repo, this._sessionStore);

  // --- OBSERVABLES ---
  @observable
  bool isLoading = false;

  @observable
  SomeEntity? data;

  @observable
  String? errorMessage;

  // --- COMPUTED ---
  @computed
  bool get hasData => data != null;

  // --- ACTIONS ---
  @action
  Future<void> fetchData() async {
    isLoading = true;
    try {
      final profileId = _sessionStore.currentChildId ?? '';
      data = await _repo.getData(profileId);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
    }
  }
}
```

## Critical Rules

1. **Always use the three-part declaration**: `class X = _X with _$X;` + `abstract class _X with Store`
2. **Always add `part 'filename.g.dart';`** — without this, code gen produces nothing
3. **Every state mutation must be inside `@action`** — direct field assignment outside `@action` silently fails to notify observers
4. **Run code gen after every store change**: `dart run build_runner build --delete-conflicting-outputs`
5. **Wrap UI that reads observables in `Observer`**:
   ```dart
   Observer(
     builder: (_) => Text(store.data?.name ?? 'Loading...'),
   )
   ```
6. **Use `@computed` for derived values** — they are cached and only recomputed when dependencies change
7. **Inject dependencies via constructor** — never use `getIt` inside the store body, pass dependencies through the constructor and register in the DI module

## Common Traps

- **Forgetting `@action` on async methods** — the `finally` block won't trigger UI updates
- **Using `ObservableFuture` incorrectly** — prefer simple `bool isLoading` + `@action` pattern over `ObservableFuture` for new stores (the `StreakStore` uses both patterns; simpler is better)
- **Modifying observable inside `try` without `@action`** — silent failure, no observer notification
- **Not checking `mounted` in UI** — after `await`, the widget may be disposed. Always check in the widget, not the store
- **Forgetting to re-run `build_runner`** — the `.g.dart` file becomes stale, runtime errors

## Store Lifecycle

| Registration | When |
|---|---|
| `registerSingleton` | Global stores shared across screens (SessionStore, LoginStore, ClassStore) |
| `registerFactory` | One-per-use stores (ErrorStore, FormStore) |
| `registerLazySingleton` | Expensive stores initialized on first access |

## Connecting Store to UI

```dart
class MyScreen extends StatefulWidget {
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  final _store = getIt<FeatureStore>();

  @override
  void initState() {
    super.initState();
    _store.fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        if (_store.isLoading) return const CircularProgressIndicator();
        if (_store.errorMessage != null) return Text(_store.errorMessage!);
        return Text(_store.data?.name ?? 'No data');
      },
    );
  }
}
```

## Code Generation Command

```bash
cd mela
dart run build_runner build --delete-conflicting-outputs
```

To watch for changes continuously during development:
```bash
dart run build_runner watch --delete-conflicting-outputs
```
