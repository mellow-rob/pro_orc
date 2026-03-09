# Contributing to Pro Orc

Thanks for your interest in contributing! Pro Orc is a native macOS menubar app built with Flutter, and we welcome contributions of all kinds.

## Prerequisites

- **macOS** (Pro Orc is a native macOS app)
- **Flutter SDK** (stable channel)
- **Xcode Command Line Tools** (`xcode-select --install`)

## Development Setup

```bash
git clone https://github.com/mellow-rob/pro_orc.git
cd pro_orc/pro_orc
flutter pub get
flutter run -d macos
```

## Running Tests

```bash
cd pro_orc
flutter test              # All unit tests
flutter analyze           # Static analysis (should show no errors)
```

Both commands must pass before submitting a pull request.

## Code Style

- **Package imports only** — no relative imports
- **Immutable patterns** — create new objects, never mutate existing ones
- **German UI strings** — user-facing text is in German (e.g. "Privat", "Oeffentlich")
- **Services return empty/null on errors** — no exceptions for expected failures
- See `CLAUDE.md` for full architecture details and conventions

## Pull Request Process

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-change`)
3. Make your changes
4. Run `flutter test` and `flutter analyze`
5. Submit a pull request with a clear description of what changed and why

## Reporting Issues

Use GitHub Issues with the provided templates:

- **Bug Report** — for crashes, broken behavior, or unexpected results
- **Feature Request** — for new ideas or improvements

Please include your macOS version and Pro Orc version when reporting bugs.

## Architecture Overview

Pro Orc uses a three-layer architecture:

```
Presentation (Flutter widgets)
  -> Riverpod Providers (state management)
    -> Pure Dart Services (business logic)
```

All services are pure Dart with no Flutter imports, making them unit-testable and isolate-safe. See `CLAUDE.md` for the full breakdown.
