# Documentation and Evidence Policy

**Language / 언어:** [English](DOCUMENTATION_POLICY.md) | [한국어](DOCUMENTATION_POLICY.ko.md)

## Language navigation

Canonical `*.md` paths are English. Korean editions use `*.ko.md` beside them. Every maintained page begins with an English/Korean selector linking the same document in each language. Internal links stay in the selected language. README.en.md, docs/README.en.md, and docs/KEY_ISSUES.en.md remain compatibility entry points for earlier links.

GitHub renders separate Markdown pages, so a language click changes the document URL; it is not a site-wide saved preference. Opening the repository or a canonical link always shows English. HTML attachments include local language controls. The capacity PDF starts in English and includes clickable Korean/English destinations. Original screenshot/PDF sources are explicitly labeled Korean archives with translated reading editions; binary screenshots are not represented as translated pixels.

English and Korean editions may reflow historical prose for readability. Preserve substantive decisions, dates, counts, identifiers, qualifiers, and stop conditions; do not present an abridgment as a line-for-line transcript. The journal retains repeated historical numbering, and translated technical blocks preserve recorded evidence. Correct stale links and label superseded designs rather than claiming they are current.

## Updating a document

Update both editions in the same PR. Explain a material status change and cite the migration/PR or dated verification. Keep code identifiers, SQL behavior, version numbers, and CLI commands stable across translations. Retain literal Korean UI strings where necessary to operate the Korean application, with explanation in the surrounding language.

Run `npm run check:docs`. The checker verifies pairs, reciprocal selectors, local paths/anchors, language-consistent links, manifest coverage, and absence of six-digit PIN-like values in the account template. CI checks new PR commit messages for Korean characters. Existing history is governed separately below.

## Commit messages and history

Use English-only commit subjects and bodies, including squash-merge text. Translate behavior concretely; avoid mixed-language duplicates. A PR cannot edit its ancestor commit messages. Rewriting them changes hashes for the affected commits and descendants and invalidates signatures on rewritten objects.

The prepared commit-message map and owner procedure are in [history maintenance](HISTORY_MAINTENANCE.md). A separate preview branch may be reviewed before the owner moves main with an explicit expected-head lease. Do not silently force-push a shared branch, change contributor attribution, or treat a normal squash merge as a rewrite of older history.

## Evidence for school and EC use

Distinguish implemented code, dated production observations, synthetic UI verification, unresolved operational adoption, and planned work. Small parity datasets do not establish scale or security certification. Identify human contribution with specific commits/PRs and disclose AI assistance. Do not invent impact metrics, sole authorship, adoption, or admissions outcomes.

No real student roster, PIN, credential, or identity-mapping row belongs in project evidence. A sanitized file does not remove historical Git copies or rotate credentials. The owner must address actual historical exposure before distributing repository access.
