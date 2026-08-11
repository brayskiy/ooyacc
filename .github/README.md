# CI and branch policy

## Rule 2 — tests must pass (workflow)

[`workflows/ci.yml`](workflows/ci.yml) runs `make test` (which builds ooyacc
and executes the grammar suite in `tests/`):

- **On pull requests** targeting the default branch — validates the work
  branch before it can be merged.
- **On push to the default branch** — confirms the branch stays green after
  a merge.

The job is named **`Build and test`**; that is the status-check context used
by branch protection below.

## Rule 1 — default branch via PR only (branch protection)

A workflow file cannot forbid direct pushes; that is a repository setting.
Apply it once with the helper script (needs `gh` authenticated with admin):

```sh
.github/setup-branch-protection.sh            # current repo, branch master
.github/setup-branch-protection.sh owner/repo main
```

This requires PRs to update the branch (admins included), blocks force
pushes and deletions, and requires the **`Build and test`** check to pass
before merging.

> Note: this repository's default branch is `master`. The workflow triggers
> on both `master` and `main`, so renaming the default branch needs no
> workflow change — only re-run the protection script for the new name.
