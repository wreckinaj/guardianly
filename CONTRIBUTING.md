# Contributing Guide

This guide explains how to set up, code, test, review, and release contributions so they meet our **Definition of Done (DoD)**.

---

## Code of Conduct

We follow the [Contributor Covenant](https://www.contributor-covenant.org/version/2/1/code_of_conduct/) Code of Conduct.

- Be respectful and professional in all interactions.
- Provide constructive feedback.
- Report inappropriate behavior or security concerns privately to the project maintainers (via Discord or GitHub).

---

## Getting Started

### Prerequisites
- **Flutter SDK:** 3.35.7 or newer  
- **Dart SDK:** 3.6.2 or newer  
- **Android Studio / VS Code / Xcode** (depending on your target platform)
- **Git** and a GitHub account

### Setup
```bash
git clone https://github.com/wreckinaj/guardianly.git
cd guardianly
flutter pub get

### Environment Variables
- Copy `.env.example` → `.env`
- Never commit `.env` files or secrets.
- `.env` is included in `.gitignore`.

### Running the App
```bash
flutter run

## Branching & Workflow

- **Workflow:** Feature branch model (GitFlow-style)  
- **Default branch:** `main`  
- **Branch naming conventions:**
  - `feature/<short-description>`
  - `fix/<issue-id>-<short-description>`
  - `docs/<topic>`
- Always branch off `main`
- Rebase regularly to stay up to date
- All changes must be merged via pull requests (PRs) — never push directly to `main`

---

## Issues & Planning

- Use **GitHub Issues** to track all bugs, features, and tasks  
- Use the provided **issue templates**
- Apply appropriate labels (e.g., `bug`, `enhancement`, `documentation`)
- Assign yourself before starting work
- Discuss significant architecture or UX decisions in **GitHub Discussions** before starting implementation

---

## Commit Messages

We use [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) for consistent, parseable commit history.

**Format:**
    <type>(scope): short description

**Examples:**
    feat(auth): add Google login support
    fix(api): handle timeout exceptions
    docs(readme): clarify installation steps

**Types:**
- `feat` – new feature  
- `fix` – bug fix  
- `docs` – documentation change  
- `refactor` – code restructuring  
- `test` – adding or improving tests  
- `chore` – build or tooling updates  

Reference related issues like `#42` when applicable.

---

## Code Style, Linting & Formatting

We enforce consistent style across all Flutter and Dart code.

- **Linter:** Flutter analyzer  
  - Config file: `analysis_options.yaml`  
  - Run locally:
    flutter analyze

- **Formatter:** Dart formatter  
  - Run locally:
    dart format .

- PRs must have **zero lint errors** before merge.
- Lint rules are declared in `analysis_options.yaml` (and we may reference `analysis_limits.yaml` for stricter project rules).

---

## Testing

All code changes must include appropriate tests.

**Framework:** `flutter_test`

**Test types:**
- Unit tests for logic
- Widget tests for UI behavior
- Integration tests for full app flows (where applicable)

Run tests locally:
    flutter test

Expectations:
- All tests must pass before merge.
- Cover happy paths and edge cases.
- Aim for a reasonable coverage threshold (e.g., ≥ 80% for new/changed code); CI will report coverage.
- Integration tests should be added for platform-critical flows (login, payment, permissions) as the project matures.

---

## Pull Requests & Reviews

### PR Requirements
- Branch from `main`.
- Complete the PR template.
- Include a descriptive title and summary.
- Reference issues (e.g., `Fixes #123`) when applicable.
- All required checks must pass:
  - Lint (`flutter analyze`)
  - Tests (`flutter test`)
  - Builds (`flutter build` for targeted platforms)
  - Security scan (CodeQL or equivalent)
  - Dependency checks (Dependabot)
- Keep PRs focused and small when feasible (recommended < 300 lines of changes).

### Review Process
- At least **1 approval** required (more for large changes).
- Reviewers look for readability, correctness, test coverage, and compliance with lint rules.
- Request changes if something is unclear — the author must address comments before merging.
- Use **Squash and Merge** to keep `main` history tidy unless an alternative is preferred.

---

## CI/CD

We use **GitHub Actions** for CI.

### Workflows (example files)
- `.github/workflows/ci.yml` — Lint, Test, Build for Android/iOS/Desktop (platform-specific runners)
- `.github/workflows/codeql.yml` — Static security analysis (note: CodeQL does not support Dart; run a placeholder or rely on other tools)
- `.github/dependabot.yml` — Automatic dependency updates for `pub` and GitHub Actions

### CI Jobs (required)
- **Lint** — `flutter analyze`
- **Format check** — `dart format --output=none --set-exit-if-changed .` (optional)
- **Test** — `flutter test`
- **Build** — Platform builds on appropriate runners:
  - Android: `ubuntu-latest`
  - iOS: `macos-latest` (builds use `--no-codesign` or `flutter build ipa --no-codesign`)
  - Windows: `windows-latest` (desktop build)
- **Security** — Dependabot + any static analysis tools (CodeQL for other languages, or Dart-specific scanners)
- **Artifacts** — Optionally upload build artifacts (APK, IPA, EXE) for QA.

### Merge Gate
PRs may only be merged when:
- All CI jobs succeed.
- Required approvals are obtained.
- Branch is up to date with `main`.

---

## Security & Secrets

- Never commit API keys, passwords, tokens, or other secrets.
- Use `.env` (listed in `.gitignore`) for local secrets; do not commit `.env`.
- Store production secrets in GitHub Secrets (Settings → Secrets) or a secrets manager.
- Dependabot monitors dependencies; resolve alerts promptly.
- If a secret is accidentally committed:
  - Revoke/rotate the secret immediately.
  - Remove it from history (e.g., `git filter-repo` or GitHub support if needed).
  - Create a PR documenting the remediation.
- Report security vulnerabilities privately to maintainers — do not open public issues for active exploits.

---

## Documentation Expectations

When changing behavior, code, or public APIs:
- Update `README.md` for setup or usage changes.
- Add or modify files in `docs/` for new features or architectural notes.
- Provide inline docstrings for public functions/classes.
- Update `CHANGELOG.md` (or GitHub Releases notes) for notable changes.
- Ensure examples and configuration snippets in docs are accurate and tested.

---

## Release Process

- **Versioning:** Semantic Versioning (SemVer) — `MAJOR.MINOR.PATCH`.
- **Tagging a release:**
    git tag -a vX.Y.Z -m "Release notes"
    git push origin vX.Y.Z
- **Changelog:** Keep `CHANGELOG.md` or use GitHub Releases to write release notes.
- **Build artifacts:** CI may create and upload artifacts for QA (APK, IPA, Desktop binaries).
- **Deployment:** Production deployment steps (store uploads, Play Store / App Store, self-hosting) should be documented and require maintainer approval.
- **Rollback:** If a release causes critical failures, revert the release commit and/or tag and re-deploy the previous stable release. Document the rollback steps in the release notes.

---

## Support & Contact

- Maintainers: list core maintainers (GitHub handles / emails).
- Primary communication: project Discord (`#guardianly-dev`) and GitHub Discussions.
- For urgent security issues: contact maintainers directly (private channel).
- Expected response window for PRs/issues: 24–48 hours (may vary by maintainer availability).

---

## Definition of Done (DoD)

A contribution is considered done when:
- ✅ Code is pushed to a feature branch following naming conventions.
- ✅ All unit and widget tests pass in CI.
- ✅ `flutter analyze` produces no lint errors.
- ✅ PR has required approvals.
- ✅ Branch is up to date with `main` and all status checks pass.
- ✅ Documentation (README, docs/, inline comments) updated as needed.
- ✅ No sensitive data was introduced.
- ✅ CI builds succeed for intended target platforms.

---

_Thanks for contributing — your work helps make Guardianly better and safer for everyone._
