---
status: accepted
---

# Use GitHub Flow with explicit maintainer bypasses

## Context

DoxyVB6 has one permanent mainline and is currently maintained by one person. External and ordinary pull requests still benefit from independent review, so the default should require one approval. The maintainer cannot meaningfully approve a pull request authored under the same identity, but silently weakening review for every contributor or treating administrator access as standing permission would make integration ambiguous.

The repository also needs an exceptional pull-request-less path for a specifically authorized work item or finite issue series. Both exceptions must remain explicit and auditable without weakening the invariants that keep `main` linear and recoverable.

## Decision

DoxyVB6 uses GitHub Flow with `main` as its only permanent integration branch and one short-lived branch per issue or maintainer-requested work item. Pull requests use squash merge, and GitHub automatically deletes their remote head branches after successful merge.

The ordinary path requires one approval from someone other than the author. Contributors and agents never self-approve.

A specifically identified maintainer-authored pull request may be merged without that approval only after the maintainer explicitly instructs that pull request to be merged. This exception uses the Repository Admin pull-request-only bypass and retains the pull request, required checks, squash merge, audit evidence, and post-merge verification.

Integration without a pull request requires separate explicit authorization scoped to the named work item or frozen finite issue set. It uses only the Organization Admin always-bypass path. The change is still implemented and protected on a short-lived branch, verified, rebased onto the latest `origin/main`, integrated without a force push, and verified again on `origin/main` before completion.

General GitHub write access and instructions to commit, push, close, move to `Done`, or merge without identifying a path do not authorize either bypass. Repository administration rights alone are never authorization.

Protection from deleting or force-pushing `main`, and the linear-history requirement, are enforced as no-bypass invariants. Every integration path retains acceptance-criteria verification, an audit record, post-main verification, and the `Done` gate.

## Consequences

- Ordinary pull requests receive an independent review signal.
- The single maintainer can merge an explicitly identified own pull request without mechanical self-approval.
- Pull-request-less integration remains available for explicitly scoped continuous work without becoming a standing privilege.
- Every completed issue is traceable to a verified commit on `origin/main`.
- `main` remains the sole permanent, linear integration history.
