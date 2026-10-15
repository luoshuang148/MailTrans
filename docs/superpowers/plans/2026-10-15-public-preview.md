# MailTrans 0.10 Public Preview Implementation Plan

> **For agentic workers:** Use test-driven implementation with a final independent whole-branch review. Steps use checkbox syntax for tracking.

**Goal:** Let new users configure MailTrans without Terminal and recover from stalled translations; produce a verifiable development build.

**Architecture:** Preserve host/extension/worker boundaries, add a bounded child-process runner, native setup/management helpers, and reproducible packaging/CI. Runtime integration stays in ProbeApp; independent new-file UI and distribution work may run concurrently without shared-file edits.

**Tech Stack:** Objective-C/AppKit/MailKit, Swift Translation, Python standard library, GitHub Actions.

**Spec:** ../specs/2026-10-15-public-preview-design.md

## Global Constraints

- Version 0.10 / build 10; application floor macOS 26.4, Apple Silicon; stable identifiers.
- Preserve mailbox originals, Chinese bypass, remote-image settings, no telemetry/cloud fallback.
- Default automatic translation on; pause persists and only cancels automatic work.
- Worker timeout 120 seconds; output cap 8 MiB; kill grace 0.5 seconds; only owned process.
- GUI management works without Python; no notarization claim or new credentials.
- Keep existing installed app untouched until integrated checks pass; preserve 0.9.0 tag.

## Review Focus

- A worker ignores stdin/SIGTERM or floods output: bounded termination with queue recovery.
- Restore/clear/pause/quit races before launch or after result: no late writes or child leaks.
- Manual translation/cached switching while automatic mode paused: still works.
- First launch with Mail absent, disabled extension or missing language model: actionable setup.
- Wrong app/uninstall cancellation/service removal failure: no unrelated data deleted.

### Task 1: Runtime resilience and user control

**Files:** create source/MTProcessRunner.h/.m, ProcessRunnerTests.m; modify ProbeApp.m and AppTests.m (all under outputs/mail-translation-probe).
**Interfaces:** bounded runner consumes an NSTask plus NSData input and timeout; reports output, exit status or structured runner error. ProbeApp owns runner/task and cancels by active key. Persist automatic setting in lifecyclePreferences with default YES. Expose showSetup, toggleAutomaticTranslation:, cancelCurrentTranslation:, retryLastFailure:.

- [x] Write/run failing real-child tests for timeout, cancellation, large stdin, output cap and SIGTERM resistance.
- [x] Implement runner and run focused regression checks.
- [x] Write/run failing host tests for persistent pause, manual translation, retry expiration, queue recovery and late result cancellation.
- [x] Integrate menu/error state and preserve existing regressions; verify and commit.

### Task 2: Native setup and lifecycle management

**Files:** new source/MTSetupController.h/.m, MTAppManagement.h/.m and focused tests; no edits to ProbeApp.m or build.py by the independent implementer.
**Interfaces:** setup initWithPreferences:, languagePreparationHandler/cacheClearHandler/quitHandler callbacks, showWindow, markSetupComplete. Management validates current app and touches only known per-user agent and exact app bundle. Report required compiler/framework inputs.

- [x] Test actual plist generation, invalid target refusal, cancellation/no-op, and setup without Mail with isolated paths/preferences.
- [x] Implement native setup, public extension/model queries, lifecycle management, release/help/sample actions, safe uninstall confirmation.
- [x] Run focused checks; report integration instructions and commit only owned files.

### Task 3: Build, packaging and CI

**Files:** modify source/build.py; new source/package_release.py, build/package Python tests; .github/workflows/ci.yml; docs/distribution.md, docs/compatibility.md. No ProbeApp/AppTests changes by independent implementer.
**Interfaces:** build compiles runner/UI/management and tests; modes distinguish native regression verification from full app/model testing. package emits app ZIP + SHA256 and development status.

- [x] Write/run failing portable tests for packaging validation, clean app-only ZIP and executable permissions.
- [x] Implement packaging, environment-aware build and native-tests-only mode; set version 0.10/build 10.
- [x] Add least-privilege CI for portable tests/native checks; verify against official available ARM hosted images and expose incompatible full-app toolchains honestly.
- [x] Run tests, inspect artifact and commit owned files. Do not upload credentials or publish a release independently.

### Task 4: Integrate, review and deliver

- [x] Integrate setup callbacks and first-launch behavior with runtime; run fresh complete build/tests and signature validation.
- [x] Update English/Chinese docs/changelog and replace stale installation/menus/release claims.
- [x] Independently review changes; fix material findings with reproductions.
- [ ] Push feature branch, verify GitHub CI, integrate to main when checks pass.
- [ ] Produce development ZIP/checksum and v0.10.0 pre-release with exact limitations; verify download/tag/source consistency.
- [x] Report external needs: paid membership for notarization and independent Mac compatibility testing.
