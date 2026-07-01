# Contributing to PaglaMLX

Thanks for your interest in contributing! This document covers the basics.

## Getting Started

1. Fork the repository.
2. Clone your fork: `git clone https://github.com/<your-username>/PaglaMLX.git`
3. Open `Package.swift` in Xcode or build from the command line: `swift build`
4. Create a feature branch: `git checkout -b feat/my-change`

## Development

### Requirements

- macOS 14.0+
- Xcode 15+ or Command Line Tools
- Python 3.12+ with `mlx-lm`, `fastapi`, `uvicorn`, `httpx`

### Build

```bash
swift build
```

### Run

```bash
swift run
```

### DMG packaging

```bash
./build_dmg.sh
```

### Documentation

The docs live in `docs/` (Docusaurus). To preview:

```bash
cd docs
npm install
npm start
```

## Pull Request Guidelines

- Keep commits small and atomic.
- Prefix commit messages with the scope: `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`.
- Update documentation if you change behaviour.
- Update the Docusaurus docs if you add or modify a feature visible to users.
- Ensure the build passes: `swift build -c release`
- No need to bump the version — that happens at release time.

## Code Style

- Match the existing code style (Swift, SwiftUI, `@Observable`).
- Avoid speculative refactors and unnecessary abstractions.
- Preserve the existing architecture (Routing Gateway, ModelOrchestrator, IntegrationManager).
- Validate every change by building before committing.

## What to Work On

Check the [Issues](https://github.com/paglagpt/PaglaMLX/issues) page for open bugs and feature requests. If you have an idea that's not listed, open an issue first to discuss it.

## Questions?

Open a [Discussion](https://github.com/paglagpt/PaglaMLX/discussions) or ask in the issue tracker.
