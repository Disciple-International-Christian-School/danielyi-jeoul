# English Commit History — Owner Procedure

**Language / 언어:** [English](HISTORY_MAINTENANCE.md) | [한국어](HISTORY_MAINTENANCE.ko.md)

## Scope and prepared result

A full scan of 280 commits reachable from main at 537b3dbbb728f5aa76efd07b7b8a1bf08e9a541a found seven Korean-containing messages. [The translation map](commit-message-translations.json) contains English-only replacements for each full message, including bodies. New documentation commits use English.

The [preview tool](../scripts/prepare-english-history.py) defaults to dry run. With --apply it creates only a new local review branch, preserving each tree, parent order, author/committer names, emails, timestamps, and all unmodified messages. Rewritten commits cannot retain valid signatures; signature/mergetag headers are removed from changed objects. Ancestors unaffected by the changes retain their hashes. The tool verifies identical head trees and metadata and refuses a shallow clone, missing translations, an existing preview ref, or a target outside refs/heads/review/.

**The documentation PR does not rewrite existing main history.** GitHub's available commit-creation connector does not expose author/date preservation fields; using it to recreate older commits would change attribution. The prepared owner-run tool avoids that change. It has been exercised on a synthetic merge graph; run its checks on a complete authenticated clone before any remote update.

## GitHub-hosted preview

The `Prepare English history preview` workflow runs once when its preparation files change on this PR branch, and can be run manually after merging. It creates a unique `review/english-history-<run>-<attempt>` branch from the current main, validates identical trees and preserved metadata, and pushes only that new review branch. It never updates main and stops if main moves during preparation. A preview made before the documentation PR merges does not yet contain the PR; regenerate it afterward.

## Prepare locally after owner review of the documentation PR

```bash
git fetch origin
git switch main
git pull --ff-only
python3 scripts/prepare-english-history.py
python3 scripts/prepare-english-history.py --apply
git diff --exit-code main review/english-commit-history
git log review/english-commit-history --format=fuller
```

Review the exact translations, author/date preservation, graph, and the unchanged file tree. If additional Korean messages have appeared, extend the map with verified translations first; the tool stops rather than inventing them.

Optionally push only the preview branch for owner review:

```bash
git push origin review/english-commit-history
```

## Replace shared main only in a coordinated owner maintenance window

A normal PR merge cannot remove or rename ancestor messages. Replacing shared history requires a force-with-lease update after recording the expected current main SHA and creating a backup ref. Reconfirm that no new remote work arrived. Decide separately how to handle other branches/tags that still expose old messages; rewriting main does not rewrite every repository ref.

```bash
# Run only after the owner approves the reviewed preview and coordinates collaborators.
git fetch origin
expected_main=$(git rev-parse refs/remotes/origin/main)
git diff --exit-code "$expected_main" review/english-commit-history
git branch backup/pre-english-history "$expected_main"
git push origin backup/pre-english-history
git push --force-with-lease=refs/heads/main:"$expected_main" origin review/english-commit-history:refs/heads/main
```

The diff guard catches file changes but not a new remote commit with an identical tree: also compare the reviewed source-head SHA from the tool with expected_main before pushing. If they differ, stop and regenerate the preview. Do not use a blind --force. Collaborators must refresh or rebase their local branches after replacement; references/signatures tied to old hashes need review.

Commit-message translation does not remove sensitive historical files. Credential rotation and any approved data-history cleanup are separate owner actions. Backup refs deliberately preserve old objects and must remain access-controlled.

## October 28 merge reconciliation

Added translations for two Korean-containing messages among the nine later main commits through e682248d717b042fb8074ed32a4c9e3819a2daf3. The map now covers nine messages; the earlier 280-commit/seven-message counts remain the initial historical scan. Replacing existing history is separate from merging this documentation PR and is not performed by the merge.
