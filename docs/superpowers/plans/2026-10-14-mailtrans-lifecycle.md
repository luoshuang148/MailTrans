# MailTrans Lifecycle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Rename to MailTrans and follow Apple Mail launch/quit while honoring manual quit.

**Architecture:** A user LaunchAgent runs an event-driven NSWorkspace lifecycle helper. The menu app persists manual-quit session suppression and gracefully cancels its child tasks.

**Tech Stack:** Objective-C / AppKit, Swift Translation, Python build/agent management, launchd.

**Spec:** ../specs/2026-10-14-mailtrans-lifecycle-design.md

## Global Constraints

- Version 0.8 / build 8; macOS 26.4 / Apple Silicon.
- Preserve bundle IDs, cache root, URL scheme, translation and remote-image policies.
- No windows or Dock icon for host or lifecycle helper; menu remains command-only.
- Manual quit suppresses until next Mail session, including helper restart.
- Only terminate owned applications/tasks; no real mail fixtures or cloud calls.

## Review Focus

- Helper starts after Mail is already running: starts exactly one host.
- Mail closes while async host launch is pending: no orphan host.
- Manual quit then helper restart: same Mail session remains suppressed.
- Multiple Mail instances/duplicate events: stop only after last instance.
- App quit during worker/language preparation: tasks stop and cache cannot resurrect.

### Task 1: Lifecycle observer

**Files:** Create source/MailLifecycle.h/.m, source/LifecycleMain.m, source/LifecycleTests.m, source/LifecycleFixture.m under outputs/mail-translation-probe.

**Interfaces:** MTMailLifecycle initWithMailBundleIdentifier:hostBundleIdentifier:hostURL:preferences:, start, stop, mailSessionToken; shared MTMailSessionToken and preference key.

- [x] Write tests using real NSWorkspace fixture apps. Observe failure with lifecycle class absent.
- [x] Implement session tracking, initial reconciliation, normal termination, no-focus launch, persistent suppression and late-launch handling.
- [x] Run tests for initial state, unrelated apps, launch/quit, manual suppression, helper restart, multiple instances and late host startup.

### Task 2: Host integration and delivery

**Files:** Modify source/ProbeApp.m, AppTests.m, build.py, verify_worker.py, LanguageSetup.swift; create source/manage_lifecycle.py; update current docs.

**Interfaces:** Host and helper share lifecycle preferences; management script enables bundled helper via user LaunchAgent.

- [x] Add failing host shutdown checks using real child processes and isolated cache/preferences.
- [x] Rename visible app surfaces; connect manual quit marker, owned-task cancellation and stop guards.
- [x] Package/sign helper and renamed MailTrans.app; build includes lifecycle test suite.
- [x] Implement enable/disable/status and verify via actual reversible enable/status/disable checks at deployment.
- [x] Full build/test/signature/worker verification; one independent branch review.
- [x] Back up 0.7, install MailTrans, enable LaunchAgent, verify actual Mail launch/quit/manual quit, then restore normal running state.
- [x] Update handoff/tests, integrate into main and push GitHub.
