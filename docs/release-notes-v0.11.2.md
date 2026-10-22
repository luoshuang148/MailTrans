# MailTrans v0.11.2 — release draft (not published)

Source version 0.11.2, build 13. Public download remains v0.11.1. Verify the final commit, CI, ZIP checksum, signing and live Mail/model behavior before publishing a new binary.

- Bounded recovery when Mail restores a message before MIME content is available.
- Re-register an enabled extension if its process exits; never enable a user-disabled extension.
- At most six reload attempts per Mail session, with manual reload as a fallback.
- Original-first reading; Apple local translation; no cloud translation API or project telemetry.

Requires Apple Silicon and macOS 26.4+. Source build needs full Xcode and macOS SDK 26.5+. Experimental; ad-hoc signed, not notarized. Live Mail rendering, independent installation and model behavior require separate acceptance; a build alone does not establish them. See compatibility.md for actual test evidence.

Suggested command after validation and user confirmation (NOT executed; verify asset filenames):

```sh
gh release create v0.11.2 --repo luoshuang148/MailTrans --target VERIFIED_COMMIT --prerelease --title 'MailTrans v0.11.2 — Reading-view recovery' --notes-file docs/release-notes-v0.11.2.md --draft
```

Attach verified ZIP and SHA256SUMS from the documented packaging process. A draft is not a public release; publication remains a separate decision. Do not reuse previous release checksums.
