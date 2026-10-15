# MailTrans 0.10 development-preview validation

Environment: macOS 26.4 / Apple Silicon arm64 / Xcode 26.6 (17F113) / macOS SDK 26.5. App version 0.10 / build 10; deployment floor remains 26.4.

## Completed local checks

- Baseline 0.9 complete build passed before implementation.
- Real child-process tests first failed without the runner, then passed: large bidirectional pipe I/O, non-consuming stdin, 120-second production timeout with short test deadlines, cancellation before/during launch, output cap, nonzero provider output, early exit, SIGTERM resistance and synchronous shutdown.
- Host regressions first failed for missing pause/retry/setup behavior, then passed. Pause persists with default enabled; manual translation works while paused; exact-message retry recovers or requests reopening expired content; pausing invalidates pending results. Startup tests use isolated cache/preferences.
- Real lifecycle fixture regression first failed for manual setup while Mail is closed, then passed with explicit automatic-launch arguments and observed-session retirement. Existing multiple-instance, manual-quit, helper-restart and late-launch checks remain passing.
- Native management/setup regressions passed with isolated paths and injected system-command boundaries. They cover refusal of transient lifecycle targets, wrong identity/signature, symlinks, running Mail, cancelled uninstall, unknown service state, service-stop failure and exact-app trash order.
- Full integrated build passed seven native suites, cross-process preference sharing and model-status protocol checks; generated bundle passed deep/strict signature verification.
- All 15 portable build/packaging tests passed. The development ZIP was extracted and its actual app validated/signature-verified; the generated SHA-256 matched.
- Setup window was visually inspected with a separate preview harness and isolated status fixtures. This verifies layout and available controls, not a real installation/model state.
- Independent read-only whole-change review found no material correctness/security/regression findings and independently passed 15 portable tests. Its MailKit enabled-state API caveat was incorporated: registration is reported separately and users must confirm the checkbox in Mail.
- Current docs passed 78 relative link/anchor checks before final report links were added.

## Limits

A direct real-translation check of the new worker from the build directory returned model_missing. That check is not passed. Earlier development history records the same distinction between build and installed paths; the underlying cause remains unresolved. This revision's installed-worker/live Mail rendering, downloaded-app Gatekeeper acceptance and independent physical-Mac installation require separate verification. No new app was installed over an existing installation during these checks, and no real-mail fixtures were used.

The release is ad-hoc signed and unnotarized. No Developer ID identity, notarization, cloud fallback or telemetry was introduced. The [first hosted CI run](https://github.com/luoshuang148/MailTrans/actions/runs/38695509237) passed portable tests, ARM native regressions/full build and exact archive/checksum verification; a passing hosted build does not imply live Mail or independent physical-Mac acceptance.

## Published result

[PR #1](https://github.com/luoshuang148/MailTrans/pull/1) was merged after independent review and successful branch/PR CI. [v0.10.0](https://github.com/luoshuang148/MailTrans/releases/tag/v0.10.0) points to CI-verified source commit `e33498546a8961371a75516e7d74f5e737ea9831`; the main merge has the same tree. Release ZIP/checksum were downloaded anonymously after publication and compared byte-for-byte with the CI artifact. SHA-256: `2d2e559754a4a17df96e18b5fd1fce67f68a1230c3728d3417c46b0ef8759f54`. The original v0.9.0 tag and installed application were retained.
