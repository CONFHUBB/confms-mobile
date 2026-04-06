---
name: mathiq-architecture
description: >
  The architecture and conventions of the Mathiq (Mela) Flutter app. Use this skill when
  adding new features, creating new screens, understanding the project structure,
  or when confused about where code should go. Also trigger when the user mentions
  project structure, feature modules, clean architecture, layer separation,
  naming conventions, or asks "where should I put this code?"
---

# Mathiq App Architecture

## When to use

- Adding a new feature or screen
- Understanding the project folder structure
- Deciding where a file should live
- Following naming conventions
- Understanding the data flow through layers

## Project Structure

```
mela/lib/
├── core/               # Shared infrastructure
│   ├── animations/     # Reusable animation wrappers
│   ├── constants/      # App-wide constants, colors, theme, routes
│   ├── data/           # Core data utilities (Dio configs)
│   ├── domain/         # Core domain (base use case class)
│   ├── extensions/     # Dart extension methods
│   ├── services/       # App-wide services (connectivity, socket, Google sign-in)
│   ├── stores/         # Shared MobX stores (SessionStore, ErrorStore, FormStore)
│   └── utils/          # Utilities (logger, Dio error parsing, routes)
├── data/               # Data layer
│   ├── di/             # Data layer DI modules
│   ├── local/          # Local storage (Sembast)
│   ├── network/        # Dio client, APIs, interceptors, exceptions
│   ├── repository/     # Repository implementations
│   ├── securestorage/  # Encrypted storage for tokens
│   └── sharedpref/     # SharedPreferences wrapper
├── di/                 # App-level DI (ServiceLocator, StoreModule)
├── domain/             # Domain layer
│   ├── di/             # Domain DI modules
│   ├── entity/         # Domain entities (shared)
│   ├── params/         # Use case parameter classes
│   ├── repository/     # Repository interfaces (abstract)
│   └── usecase/        # Use case implementations
├── features/           # Feature modules (each self-contained)
│   ├── auth/           # Authentication (login, signup, forgot password)
│   ├── study_new/      # Main study flow (stages, theory, practice)
│   ├── gacha/          # Gacha reward system
│   ├── arena/          # PvP battles
│   ├── streak/         # Daily streak tracking
│   ├── leaderboard/    # Rankings
│   ├── profile/        # User profile, stats, achievements
│   ├── settings/       # App settings
│   ├── onboarding/     # Splash screen, onboarding
│   ├── course_selection/ # Grade/topic selection
│   ├── parent_dashboard/ # Parent view
│   └── ai_chat/        # AI tutor chat
├── l10n/               # Localization (Vietnamese)
├── shared/             # Shared UI widgets
└── themes/             # Theme definitions
```

## Feature Module Structure

Every feature follows this pattern:

```
features/<feature_name>/
├── data/               # Feature-specific APIs, models, data sources
│   ├── api/            # REST API classes
│   └── models/         # JSON serializable models
├── di/                 # Feature DI module
│   └── <feature>_module.dart
├── domain/             # Feature-specific domain
│   ├── entities/       # Domain entities
│   ├── repository/     # Repository interface (abstract)
│   └── usecases/       # Use cases
├── store/              # MobX stores (or ui/store/)
│   ├── <feature>_store.dart
│   └── <feature>_store.g.dart
├── service/            # Feature-specific services (optional)
└── ui/                 # Screens and widgets
    ├── <screen_name>.dart
    └── widgets/
```

## Data Flow

```
UI (Observer + Store) → Store (@action) → UseCase → Repository → API/DioClient → Backend
```

- **UI** reads observables via `Observer` widget, calls store actions
- **Store** manages state with MobX, calls use cases
- **UseCase** single-responsibility business logic, calls repository
- **Repository** (abstract in domain, concrete in data) calls API
- **API** uses `DioClient` for HTTP, returns raw maps or models
- **Entity** (domain) vs **Model** (data) — entity is clean, model has `fromJson`/`toJson`

## Naming Conventions

| Type | Convention | Example |
|---|---|---|
| Store file | `<name>_store.dart` | `gacha_store.dart` |
| Entity file | `<name>_entity.dart` | `streak_entity.dart` |
| Model file | `<name>_model.dart` | `user_model.dart` |
| Use case file | `<verb>_<noun>_usecase.dart` | `get_streak_usecase.dart` |
| API file | `<name>_api.dart` | `study_map_api.dart` |
| DI module | `<feature>_module.dart` | `auth_module.dart` |
| Screen file | `<name>_screen.dart` | `profile_screen.dart` |
| Widget file | `<name>_widget.dart` | `theory_question_widget.dart` |

## Key Singleton — SessionStore

`SessionStore` is the central auth/state hub. It holds:
- `parent` — the logged-in user (parent account)
- `currentChild` — the active child profile (with XP, hearts, tokens)
- `accessToken` — the JWT token

All feature stores that need user identity inject `SessionStore` and read `currentChildId`.

## App Locale

The app is Vietnamese (`vi`). Use `AppLocalizations` for any user-facing strings.

## State Management

MobX with code generation. See the `mobx-state-management` skill for detailed patterns.

## Dependency Injection

GetIt with modular registration. See the `getit-dependency-injection` skill for detailed patterns.
