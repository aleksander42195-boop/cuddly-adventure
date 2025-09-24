# Contributing

## Flow
1. Create branch: feat/..., fix/..., chore/...
2. Keep diffs focused.
3. Run tests (once added) before PR.

## Code Style
- Prefer small SwiftUI view structs.
- Avoid singletons except service facades (Secrets, Haptics).
- Use `AppTheme` tokens for spacing & colors.

## Tests
- Place in `LifehackAppTests/`.
- Snapshot tests (future) go under `Snapshots/`.

## Commit Prefixes
feat:, fix:, chore:, docs:, test:, refactor:, build:.

## Security
Never commit real API keys or PHI. Use mock data in tests.

Thanks!
