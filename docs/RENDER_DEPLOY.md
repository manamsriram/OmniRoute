# Render Deploy — Following Upstream Releases

This fork auto-tracks upstream OmniRoute's release branches without manual branch-name
edits, via two workflows:

## 1. `sync-latest-release.yml`

Runs every 6 hours (and on-demand via `workflow_dispatch`):

1. Runs `scripts/find_latest_release_branch.sh` against `https://github.com/diegosouzapw/OmniRoute.git`,
   which does `git ls-remote --heads` on `refs/heads/release/*`, strips the `release/v` prefix,
   and sorts the remaining versions with `sort -V` (true semver-aware sort, so `v3.8.9` sorts
   before `v3.8.10` — unlike plain lexicographic sort).
2. Fetches that exact upstream branch (e.g. `release/v3.8.49`).
3. Force-checks-out the fork's local `deploy` branch to that upstream ref (`git checkout -B deploy upstream/release/vX.Y.Z`) — `deploy` becomes a byte-for-byte mirror.
4. Force-pushes `deploy` to `origin`.

`deploy` is the one branch name that never changes, regardless of what upstream calls its
current release.

## 2. `build-ghcr.yml`

Triggers on every push to `deploy` (i.e. right after a sync) and on `workflow_dispatch`.
Builds the Docker image and pushes it to GHCR with two tags:

- `latest-release` — always the newest build
- `vX.Y.Z` — the exact version read from `package.json` on the `deploy` branch at build time

## 3. Branch to use if deploying from source

Point Render's service at branch **`deploy`** on this fork. No further changes needed —
`deploy` always reflects the newest upstream release branch once the sync workflow runs.

## 4. Image to use if deploying from GHCR

```
ghcr.io/<your-github-username>/<repo-name>:latest-release
```

Concretely, for this fork: `ghcr.io/${{ github.repository_owner }}/${{ github.event.repository.name }}:latest-release`
(GitHub Actions resolves those automatically; substitute your actual GitHub username and
repo name when configuring Render manually). Pin a specific release instead via the
`vX.Y.Z` tag if you don't want auto-updates.

## 5. Manual GitHub settings required

- **Repo Settings → Actions → General → Workflow permissions → "Read and write permissions"**
  must be enabled, or `sync-latest-release.yml` cannot push `deploy` and `build-ghcr.yml`
  cannot push to GHCR (both currently rely on `GITHUB_TOKEN`).
- If your fork's GHCR package is private, either make it public or grant Render (or whatever
  pulls the image) a read token — new GHCR packages default to private.
