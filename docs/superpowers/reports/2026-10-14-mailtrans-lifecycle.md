# SDD ledger — plan: docs/superpowers/plans/2026-10-14-mailtrans-lifecycle.md
Baseline: 2aab48c; clean 0.7 full build and three native suites passed.
Ruling: Native worktree tool unavailable (project context says not a repository); use ignored work/ Git worktree.
Ruling: User's detailed behavior request authorizes direct implementation; user confirmed manual quit suppression until next Mail startup.
Pre-flight: Task 1 lifecycle preferences and session token are consumed by Task 2 host; shared suite remains original host bundle ID.
Task 1: RED — lifecycle-tests-red exits 1, observer absent as expected.

Ruling: Actual fixture tests exposed that workspace launch/terminate notifications exclude LSUIElement apps; official Apple docs confirm. Switch to event-driven runningApplications KVO to cover real host late launch. No polling.
Task 1: complete — real fixture lifecycle suite passed under KVO; full 0.8 build and existing three suites green.
Task 2: RED then GREEN — owned task shutdown and manual quit preference checks failed before implementation, passed in full build after.

Final: fixed concurrent completion state mutation — ThreadCheckedLifecycle late completion RED→GREEN; full four-suite build green.
Final: fixed rapid Mail restart while old host exits — delayed-termination fixture RED→GREEN; full four-suite build green.
Final: Ruling: cold URL delivery before initialization remains a pre-existing observation, with no behavior change in routing — cost is the existing potential manual retry, recorded in handoff.
Final: Ruling: extension recaching source after reload retains existing bounded-cache behavior — no change to retention/privacy.
Final: Ruling: installed launchd/Mail/worker checks will be verified at deployment; a real logout/login is not needed to test current Mail startup and would interrupt user's session.
Final: Ruling: installation documentation is draft until deployment checks succeed; reconcile before final commit.

Deployment: actual Mail quit/relaunch and task cleanup passed; installed signature and worker checks passed.
Deployment found own-bundle UserDefaults suite is unsupported; native bundled regression failed with Foundation diagnostic, then preference factory standard/suite selection passed across CLI/app/helper.
Final: fixed bundled preference sharing — real app bundle and nested helper RED→GREEN; all four native suites plus preference suite passed.
Actual manual menu action invoked via native harness; watcher restarted and honored suppression, next real Mail session resumed and removed marker. GUI menu click unavailable due windowless binding timeout; behavior validated without private mail fixtures.
Task 2: complete — build and installed integration checks passed; final documentation and GitHub integration follow.
