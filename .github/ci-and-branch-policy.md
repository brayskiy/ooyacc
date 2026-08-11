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

## Release versioning

Every merge into the default branch (e.g. `develop` → `master`) promotes the
release version. After the `Build and test` job passes on the push, the
`release` job in [`workflows/ci.yml`](workflows/ci.yml) publishes a new
version — so a release is only ever cut from a green build.

**Format: `YY.WW.BB`**

| Part | Meaning | Source |
|------|---------|--------|
| `YY` | last two digits of the year | `date -u +%G` (ISO week-year) |
| `WW` | week number of the year     | `date -u +%V` (ISO 8601 week) |
| `BB` | release / patch number, zero-padded to 2 digits | continues within the same week, restarts at `01` in a new week |

Example: `26.32.01`, then `26.32.02` for the next merge that week; the first
merge of the following week becomes `26.33.01`.

ISO year (`%G`) is paired with ISO week (`%V`) so the two stay consistent at
the December/January boundary (e.g. `31 Dec` may belong to week 01 of the
next year).

**Mechanism.** The version is stored as a **git tag** and a **GitHub
Release** (`--generate-notes` builds the changelog). Tags avoid committing
back to the protected default branch. The job:

- reads existing `YY.WW.*` tags to pick the next `BB`;
- is idempotent — if the merge commit is already tagged (e.g. a re-run) it
  does nothing;
- needs no extra setup: it uses the built-in `GITHUB_TOKEN` with
  `contents: write`.

The latest release/tag is the current app version; check it with
`git describe --tags --abbrev=0` or on the repo's Releases page.

