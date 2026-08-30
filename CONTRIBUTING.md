# Contributing to DoxyVB6

DoxyVB6 uses [GitHub Flow](https://docs.github.com/en/get-started/using-github/github-flow). `main` is the only permanent integration branch and must remain releasable. [ADR 0002](docs/adr/0002-use-github-flow-with-explicit-maintainer-bypasses.md) records the decision.

## Work branches

- Start each issue or maintainer-requested work item from the current `origin/main` on one short-lived branch.
- Agent-created issue branches use `codex/issue-<number>-<slug>`. Use a descriptive `codex/<slug>` branch for a work item without an issue.
- Do not stack a later issue or work item on an unfinished branch. Finish its integration before starting the next branch from the updated `origin/main`.
- Push unique commits before pausing or transferring work. Do not leave the only copy in uncommitted changes or local-only commits.
- A request to implement an issue authorizes commits and pushes to that branch and creation or updates of its pull request. It does not authorize integration into `main`.

## Repository settings contract

Repository rules and merge settings must enforce these paths:

- ordinary updates to `main` require a pull request and one approval;
- Repository Admin may bypass only through a pull request;
- Organization Admin may always bypass, reserved for explicitly authorized pull-request-less integration;
- squash merge is the only pull-request merge method; and
- GitHub automatically deletes pull-request head branches after successful merge.

Separate no-bypass rules protect `main` from deletion and force-push and require linear history. If live settings differ, report the drift instead of weakening the workflow or selecting another merge method.

## Ordinary pull-request path

1. Create the work branch from the exact current `origin/main`.
2. Implement and verify one work item. Rebase onto the latest `origin/main` before integration; do not merge `main` into the work branch or force-push `main`.
3. For issue work, reference the issue with `Refs #<number>`. Do not use a closing keyword because issue closure follows post-merge verification.
4. Keep the pull request focused and use an English Conventional Commit title. Squash merge only.
5. Obtain one approval from someone other than the author. Never approve your own pull request.
6. Merge only when the maintainer performs the merge or explicitly instructs the identified pull request to be merged.
7. Verify the resulting current `origin/main`, recheck acceptance criteria, and post a verification note with the integration path, `main` commit SHA, acceptance result, and check results.
8. Only then close an issue and move it to `Done`. GitHub may auto-delete the remote branch; delete the local branch after post-merge verification.

## Maintainer-authored pull-request bypass

When no independent reviewer is available, the maintainer may explicitly instruct a specifically identified maintainer-authored pull request to be merged. That instruction permits the Repository Admin pull-request-only bypass for that pull request; it is not a self-approval.

The bypass does not waive the pull request, required checks, squash merge, acceptance criteria, audit evidence, post-merge verification, or the `Done` gate. Record the instruction and bypass path in the verification note. General GitHub write access, commit, push, issue closure, `Done`, or an unqualified request to merge is not sufficient authorization.

## Pull-request-less direct integration

Direct integration is exceptional and requires an explicit instruction that names one work item or a frozen finite issue set and authorizes integration into `main` without a pull request. Only the Organization Admin always-bypass path may be used. Authorization expires when that scope is completed, cancelled, replaced, or materially expanded.

Work still occurs on a short-lived branch. Verify it, push it for protection, rebase and consolidate it onto the latest `origin/main`, then update `main` by a non-force fast-forward. Verify the resulting `origin/main`, record the authorization, bypass path, commit SHA, acceptance result, and checks, and only then complete the issue and delete the work branches.

Direct authorization skips only the pull request and independent review. It never waives checks, acceptance criteria, the audit record, post-integration verification, or the `Done` gate. For a series of two or more issues with no selected integration path, inventory and freeze the set read-only, then ask once before implementation whether direct integration is authorized for that set.

## Completion and recovery

- A local commit, issue branch, or unmerged pull request is not complete. The intended change must be verified on the current `origin/main`.
- Do not delete the only reference to unique unintegrated content.
- Directly integrated remote and local branches are deleted only after their commit is confirmed on `origin/main`.
- Do not retain permanent aggregate, personal backup, or intermediate integration branches.
