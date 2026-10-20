# Contributing to Namma MedGate

## Local setup

1. Install Flutter and make sure the SDK is available on your PATH.
2. From the repository root, run:
   - `flutter pub get`
   - `flutter test`
3. For local app runs, use:
   - `flutter run`

## Branching

- Create branches from the latest `main`.
- Use short, descriptive branch names such as:
  - `feature/*`
  - `fix/*`
  - `docs/*`

## Architecture

- Use feature first architecture.
- Use logic, presentation, providers model.
- 

## Commit messages

- Keep the first line short and descriptive.

## Where new features should live

Keep business logic in feature-first folders under `lib/features/` and keep presentation widgets thin. For detailed architectural rules, see [AGENTS.md](AGENTS.md).

## Modifying patient schema fields

Patient schema changes must be made in [lib/features/data/patient_schema.dart](lib/features/data/patient_schema.dart) only. That file is the single source of truth for the positional MedGate patient payload format.

## Running tests before opening a PR

Before opening a pull request, run:

```bash
flutter test
```

## Optional Rust acceleration

The optional Rust native acceleration path is not required for contributors. The Dart fallback must remain functional and tested independently, so contributors do not need Rust installed to work on the project.

## Running tests via Docker

Docker is used here to provide a consistent, dependency-stable test environment for analysis and regression runs. It is not meant to replace real on-device testing for NFC, camera, or UI interaction.

1. Build the image once:
   ```bash
   docker compose build
   ```
2. Run the whole suite in the container:
   ```bash
   docker compose run medgate-dev flutter test
   ```
3. Run other commands as needed:
   ```bash
   docker compose run medgate-dev flutter analyze
   ```

Actual on-device validation still requires a real Android device or emulator outside Docker.
