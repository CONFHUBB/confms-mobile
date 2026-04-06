---
name: getit-dependency-injection
description: >
  When working with GetIt dependency injection in this Flutter app. Use this skill whenever
  registering new services, stores, repositories, or use cases in GetIt modules.
  Also trigger when creating new feature modules, debugging registration order issues,
  or encountering "not registered" errors at runtime. Covers the layered DI architecture
  used in this codebase: data → domain → features.
---

# GetIt Dependency Injection

## When to use

- Adding a new feature module
- Registering new stores, use cases, repositories, or services
- Debugging `GetIt` "is not registered" errors
- Understanding registration order and dependencies

## Architecture Overview

DI is organized in **layers**, registered in strict order:

```
ServiceLocator.configureDependencies()
├── 1. DataLayerInjection
│   ├── LocalModule        (SharedPrefs, SecureStorage, Sembast)
│   ├── NetworkModule       (DioClient, RestClient, Interceptors)
│   └── RepositoryModule    (Repository implementations)
├── 2. DomainLayerInjection
│   └── UsecaseModule       (All use cases)
├── 3. FeatureLayerInjection
│   └── StoreModule         (Core/shared stores: Session, Class, Revise)
└── 4. Feature Modules (registered individually)
    ├── ProfileModule       (MUST be before AuthModule)
    ├── AuthModule
    ├── StreakModule
    ├── CourseSelectionModule
    ├── StudyMapModule
    ├── StudyOldModule
    └── GachaModule
```

**Registration order matters.** A store that depends on a use case will crash if the use case isn't registered first.

## Creating a New Feature Module

Follow this template:

```dart
import 'package:get_it/get_it.dart';
import 'package:mela/di/service_locator.dart';

class MyFeatureModule {
  static void configure() {
    final getIt = GetIt.instance;

    // 1. Register feature-specific services/APIs (if any)
    // getIt.registerLazySingleton<MyApi>(() => MyApi(getIt<DioClient>()));

    // 2. Register stores
    getIt.registerSingleton<MyFeatureStore>(
      MyFeatureStore(
        getIt<SomeUseCase>(),       // from domain layer
        getIt<SessionStore>(),       // from core stores
      ),
    );
  }
}
```

Then register it in `service_locator.dart`:

```dart
// In ServiceLocator.configureDependencies():
MyFeatureModule.configure();
```

## Registration Types

| Method | Use When | Example |
|---|---|---|
| `registerSingleton<T>(instance)` | Shared across the app, created immediately | `LoginStore`, `SessionStore` |
| `registerLazySingleton<T>(() => instance)` | Shared but defer creation until first use | `SocketService` |
| `registerFactory<T>(() => instance)` | New instance every time it's requested | `ErrorStore`, `FormStore`, use cases |

## Critical Rules

1. **Never call `getIt<T>()` inside a store constructor body** — inject via constructor parameters instead
2. **Register dependencies before dependents** — e.g., `ProfileModule` before `AuthModule` (AuthModule's `LoginStore` needs `GetUserProfileUsecase`)
3. **Use `registerFactory` for use cases** — they are stateless and cheap to create
4. **Use `registerSingleton` for stores** — most stores are shared across screens
5. **Put feature DI in `features/<name>/di/<name>_module.dart`** — keep it co-located with the feature
6. **Cross-layer references go one direction**: UI → Domain → Data (never backwards)

## Adding a New Use Case

1. Create the use case in `domain/usecase/`:
   ```dart
   class GetSomethingUsecase {
     final SomeRepository _repository;
     GetSomethingUsecase(this._repository);
     Future<Something> call({required String params}) => _repository.getSomething(params);
   }
   ```

2. Register in `domain/di/module/usecase_module.dart`:
   ```dart
   getIt.registerFactory(() => GetSomethingUsecase(getIt<SomeRepository>()));
   ```

3. Inject into your store via the feature module.

## Adding a New Repository

1. Define interface in `domain/repository/`:
   ```dart
   abstract class SomeRepository {
     Future<Something> getSomething(String id);
   }
   ```

2. Implement in `data/repository/`:
   ```dart
   class SomeRepositoryImpl implements SomeRepository {
     final DioClient _dioClient;
     SomeRepositoryImpl(this._dioClient);

     @override
     Future<Something> getSomething(String id) async {
       final response = await _dioClient.get('/api/something/$id');
       return Something.fromJson(response);
     }
   }
   ```

3. Register in `data/di/module/repository_module.dart`:
   ```dart
   getIt.registerSingleton<SomeRepository>(
     SomeRepositoryImpl(getIt<DioClient>()),
   );
   ```

## Debugging "Not Registered" Errors

Check these in order:
1. Is the type registered? Search for `register.*<TypeName>` across DI modules
2. Is it registered before the code that requests it? Check order in `service_locator.dart`
3. Are you using the correct type? `getIt<Interface>()` not `getIt<Implementation>()`
4. Is the module's `configure()` actually called in `service_locator.dart`?
