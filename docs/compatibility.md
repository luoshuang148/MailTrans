# Compatibility and acceptance checklist

Source version: **0.11.2 / build 13**. Published development pre-release: **0.11.1 / build 12**. Historical acceptance rows below retain the revisions actually tested.

MailTrans 0.11.2 (build 13) targets Apple Silicon and macOS 26.4 or newer with Apple Mail and locally available English→Chinese translation. A full source build requires macOS SDK 26.5 or newer. Intel Macs and older macOS versions are unsupported. Language preparation may need Apple's model download; translating uses the local worker afterward.

CI checks portable packaging, native regressions and full compilation/signature integrity on its hosted ARM image. Its test executables target that runner's OS and do not exercise installed translation models or real mailboxes. A passing CI run does not establish macOS 26.4 behavior, another physical Mac, downloaded-app Gatekeeper acceptance, first-install extension approval or live translation quality. The development ZIP is ad-hoc signed and unnotarized; no Developer ID/notarization result is implied.

Record one row per environment actually tested. Leave untested results explicit. Never include mailbox contents, account names, addresses or message bodies in public reports.

| Environment | macOS / architecture | Xcode / SDK | App revision / checksum | Coverage / result |
| --- | --- | --- | --- | --- |
| Development Mac | macOS 26.4 / arm64 | Xcode 26.6 / SDK 26.5 | 0.11.1 / build 12; SHA-256 `77010bd9646a7803bb2a09a09caa6bd6597bdd5741e82f55ede06972494dd94b` | Seven native suites, cross-process preferences, model-status protocol, full compilation/signatures, 15 portable tests, ZIP/extracted-app signature and checksum checks passed; failure persistence, menu detail, dismissal and `os_log` entries verified; installed 0.11.1 host launched and extension registered; live Mail translation on this revision pending |
| GitHub hosted runner | macOS 26.6 arm64 | Xcode 26.6 / SDK 26.5 | 0.11.1 / build 12; SHA-256 `77010bd9646a7803bb2a09a09caa6bd6597bdd5741e82f55ede06972494dd94b` | [0.11.1 run](https://github.com/luoshuang148/MailTrans/actions/runs/39476721720) passed portable and native tests, full build/signature and packaging; its ZIP matches the local ZIP byte-for-byte; no live Mail/model acceptance |
| Development Mac | macOS 26.4 / arm64 | Xcode 26.6 / SDK 26.5 | 0.11 / build 11; SHA-256 `b5642d97ea6d8485c022f92082e302c664469fdf6b4c797069fd657af6b866da` | Seven native suites, cross-process preferences, model-status protocol, full compilation/signatures, 15 portable tests, ZIP/extracted-app signature and checksum checks passed; installed 0.11 host/extension launched and installed-worker real translation passed; live Mail default-original display and switch-refresh behavior pending |
| Development Mac | macOS 26.4 / arm64 | Xcode 26.6 / SDK 26.5 | 0.10 / build 10 | Seven native suites, cross-process preferences, model-status protocol, full compilation/signatures, 15 portable tests and ZIP/extracted signature checks passed; native setup UI visually checked with isolated status fixtures; actual worker from build path returned model_missing (not passed); live Mail translation on this revision pending |
| GitHub hosted runner | macOS 26.6 arm64 | Xcode 26.6 / SDK 26.5 | 0.11 / build 11; SHA-256 `b5642d97ea6d8485c022f92082e302c664469fdf6b4c797069fd657af6b866da` | [0.11 run](https://github.com/luoshuang148/MailTrans/actions/runs/39373962321) passed portable and native tests, full build/signature and packaging; its ZIP matches the local ZIP byte-for-byte; no live Mail/model acceptance |
| GitHub hosted runner | macOS 26.6.2 / arm64 | Xcode 26.6 / SDK 26.5 | [Passing run and artifact](https://github.com/luoshuang148/MailTrans/actions/runs/38695509237) | Portable tests, native suites, full build/signature and packaging passed; no live Mail/model acceptance |
| Independent physical Mac | Not yet established | Build toolchain if built locally | Record downloaded ZIP checksum | Pending independent validation |

Run the following checks with synthetic messages and note pass/fail, observed behavior and actionable errors:

- **Install:** verify the ZIP checksum and extracted signature. Open the downloaded app with normal macOS security settings. Record any Gatekeeper block and Mail extension approval requirement; do not claim success after disabling security checks.
- **Setup with Mail closed:** open settings, read Mail-opening instructions, open Mail, and check extension enabled/disabled feedback. Dismiss and reopen setup. Mark setup complete and confirm it does not reappear on each automatic launch.
- **Language model:** check missing/available states. Prepare English→Chinese through the native action; report download refusal/failure. Verify a synthetic message translates offline once the model is installed.
- **Mail fidelity:** use the bundled sample and synthetic plain-text/multipart/attachment messages. Check original/Chinese switching, layout, unchanged attachment bytes, Chinese-original bypass and Mail's remote-image policy.
- **Pause and recovery:** pause automatic English translation, confirm the setting survives relaunch, and try explicit manual translation and cached switching. Cancel a running translation, retry its failure, reopen an expired message when instructed, and ensure a subsequent message progresses. Late results must not replace restored originals.
- **Lifecycle:** opt into automatic launch, quit/reopen Mail and verify the menu bar companion follows it. Disable the option and confirm no auto-launch. Record any hosted-session limitation separately from a pass.
- **Update:** open the release-page entry and verify it opens the expected releases page without downloading or replacing the app automatically.
- **Uninstall:** cancel the native confirmation once, then confirm using a disposable test installation. Check the known LaunchAgent is removed before the exact app is trashed; mailbox data, parent folders and Apple language models remain. Record how running Mail is handled.

Local failure-diagnostics and freeze-fix verification reports are kept outside the repository as development evidence; they may describe older behavior, so current user documentation and source take precedence.

For a future notarized release, add Developer ID identity/team verification, successful notarization/stapling/assessment, and opening the actual downloaded, quarantined final artifact on a separate Mac. See [distribution instructions](distribution.md) for the current preview limitations and release process.
