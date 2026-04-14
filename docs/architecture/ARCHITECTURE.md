# Architecture

The app now follows a `feature-first + core/shared` structure.

## Top-Level Layout

- `lib/app`
  App bootstrap and root app wiring.
- `lib/core`
  Cross-cutting infrastructure that is not owned by a single feature.
  Examples: constants, providers, platform/device services, storage helpers, generic utils.
- `lib/shared`
  Reusable presentation helpers and formatters that can be used by multiple features.
- `lib/features`
  Business capabilities, each owning its own `domain`, `data`, and `presentation` layers.

## Feature Rules

Each feature should prefer this structure when it has enough complexity:

```text
features/<feature>/
  domain/
    entities/
    repositories/
  data/
    models/
    repositories/
    datasources/
    local/
  presentation/
    providers/
    screens/
    widgets/
```

Use a lighter structure only when a feature is genuinely small.

## Ownership Rules

- Put code in `core` only if it is truly shared across multiple features.
- Put code in `shared` only if it is UI/formatting reuse, not business logic.
- If a model, repository, provider, or datasource belongs to one feature, keep it inside that feature.
- Avoid reintroducing global buckets like old `lib/models`, `lib/providers`, or `lib/repositories`.

## Current Examples

- `auth`
  Owns auth entities, repository contracts, repository implementations, and auth screens.
- `profile`
  Owns profile entities, profile models, goal logic, avatar logic, and profile screens.
- `workout`
  Owns workout entities, workout models, local cache schema, repositories, providers, and workout flow screens.
- `home`
  Owns home-specific providers and widgets, but reads profile/workout data through their feature providers.

For a concrete example of the newer MVVM-style split used in the workout recording flow, see:

- `docs/architecture/MVVM_WORKOUT_RECORDING.md`

## Practical Guidance

- Add new screens under the feature that owns the use case.
- Add new providers next to the feature UI that consumes them unless they are core infrastructure.
- Keep imports moving inward:
  `presentation -> domain/data/core/shared`
- Avoid sideways feature coupling when possible. Prefer depending on repository/provider contracts or shared entities.

## Intentional Exceptions

- `core/storage/database_helper.dart`
  Still exists because the old local SQLite database is shared by both profile and workout-related local datasources.
- `features/workout/data/local`
  Holds the Isar-backed workout cache and schema because it is workout-specific infrastructure.
