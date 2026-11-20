# Contributing

## Changelog entries

Use the Trellis version in `.mise.toml`. Run commands through `mise exec --`
if your shell does not activate mise.

Add a fragment for a user-facing change:

```sh
mise exec -- just change --kind Fixed --body "Describe the user-facing fix"
mise exec -- just changelog-preview
mise exec -- trellis doctor
mise exec -- trellis changelog check --base origin/main
```

Trellis stores pending entries in `.changes/unreleased/`. Omit fragments for
documentation-only and development-only changes. CI uses the native `warn`
strictness because Trellis counts all files in this root package as package
changes. Invalid fragments still fail CI. Reviewers check for entries when
behavior changes.

Use native kinds such as `Added`, `Changed`, `Fixed`, and `Breaking`. Trellis
plans versions from these fragments. Preview the result before release
preparation, particularly for breaking changes before 1.0.

Do not edit generated release sections in `CHANGELOG.md`. Trellis keeps their
source in `.changes/dewdrop/`. `just changelog` applies the planned versions
and renders the changelog; it changes local files but does not publish.

## Git-only releases

Dewdrop uses the `git_only` lifecycle. Maintainers release Git tags and GitHub
releases, with no Hex or npm publication. Consumers can use an immutable
`v<version>` tag or a commit SHA, or follow a floating major or minor tag.
A stable `v0.2.0` release creates or updates `v0` and `v0.2`; a later `v0.2.1`
updates both aliases without moving `v0.2.0`. Prereleases create exact tags
only and leave the floating tags unchanged. GitHub releases use exact tags.

The manifest remains at `0.1.0`. Dewdrop had no tags or GitHub releases when we
added Trellis. We moved the existing unreleased Beryl notes into fragments
without changing their text. They currently plan `0.2.0` and `v0.2.0`; this
setup does not create a `v0.1.0` baseline or publish either version.

The release workflow calls the shared Trellis coordinator. On a push to `main`,
it creates or updates `release/pending`. Maintainers review and merge that PR.
After the merge, the workflow runs the existing CI at the merge SHA and requires
success before the coordinator creates tags and GitHub releases. The coordinator
then checks for further release work.

Use **Run workflow** on `main` for an explicit candidate or version request.
`pre=rc` requests a candidate; `pre=none` promotes it. `set` accepts targets such
as `dewdrop=0.2.0`, and `bump` accepts native overrides such as `dewdrop=minor`.
Candidate cycles require manual requests; ordinary pushes do not promote them.
For an interrupted release, rerun all jobs of its original merged-PR workflow
run. A dispatch from newer `main` does not recover publication of that merge.

Keep the exact Trellis pin in `.mise.toml` and the coordinator's
`trellis_version` input in `.github/workflows/release.yml` at the same version.
Update the shared workflow's full commit reference after reviewing its changes.

### Repository setup

Before enabling release preparation, install a release GitHub App on this
repository with **Contents: read and write**, **Pull requests: read and write**,
and **Commit statuses: read and write**. Add its credentials as repository or
accessible organization Actions secrets:

- `RELEASE_APP_ID`
- `RELEASE_APP_PRIVATE_KEY`

The App token lets release PR updates trigger CI. Give the workflow token
permission to write contents and commit statuses and read pull requests, as
declared in the workflow. Permit the App to push `release/pending` under the
repository's rules. Maintainers still approve and merge release PRs.
Permit the workflow token to update floating major and minor tags under any
repository tag rules.

No Hex/npm credentials are needed. Do not dispatch a release to test setup.
