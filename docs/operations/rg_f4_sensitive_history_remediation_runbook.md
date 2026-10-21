# RG-F4 sensitive GPS history remediation — owner approval gate

**Status:** DRY RUN ONLY; no remote history rewrite has been performed. The mapping below records the disposable fresh GitHub clone at RG-F4 head `42dbbf491225d2997d476f6931e8571cf5b33e44`. The owner subsequently authorized a normal push of the QA changes. That new commit makes this mapping historical evidence; a fresh dry run and owner approval are required before any future history rewrite.

**Sensitive path:** `exports/historical/aetron_raw_gps_combined.csv` (original Git blob `5c317de601e1ecb709d4762934d8ed3065f7d2a6`). **Safe baseline:** `3644e8a866a4e86a4f7e9cf1dd1c4cca7f489284`, the direct parent of the introducing commit. Follow [GitHub's sensitive-data procedure](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository), using `git-filter-repo` 2.47 or newer.

## Fresh GitHub clone dry run and exact ref mapping

A disposable clone from GitHub fetched all `refs/pull/*` before filtering. The filter's `--force` flag was needed because fetching PR refs made the clone fail its untouched-clone check; it applied **only to this disposable local clone** and was not a force-push. The command was:

```bash
git filter-repo --force --sensitive-data-removal \
  --refs 3644e8a866a4e86a4f7e9cf1dd1c4cca7f489284..refs/remotes/origin/feat/rg-f4-dataset-export \
  3644e8a866a4e86a4f7e9cf1dd1c4cca7f489284..refs/pull/11/head \
  3644e8a866a4e86a4f7e9cf1dd1c4cca7f489284..refs/pull/11/merge \
  --invert-paths --path exports/historical/aetron_raw_gps_combined.csv
```

The bounded range matters. An unrestricted local-snapshot trial changed every branch head, including `main` and RG-F3, because the filter also removed old commit signatures. That trial was discarded. The fresh GitHub clone reported first changed commit `bdf5cea4177ff4d638bcf29c777fa53b93cfc240` and exactly three changed local refs: `refs/remotes/origin/feat/rg-f4-dataset-export`, `refs/pull/11/head`, and `refs/pull/11/merge`. **Affected PR head count: 1 (PR #11).**

| Ref or commit | Old SHA | New SHA in bounded local trial |
|---|---|---|
| RG-F4 introducing commit | `bdf5cea4177ff4d638bcf29c777fa53b93cfc240` | `91eda5987ad0ecfdd2f7fe3a8c7e8297114764c1` |
| RG-F4 next commit | `d849ca953f6f2233ca8628ff8551b0f1d0f7c125` | `6e7dd6c23a262547296a8bbf1f8fd1692053e911` |
| RG-F4 untracking commit | `4475202c49bdec646aabc5f1c501f772af3fbf06` | `9149b7c1288b8816d002b10968457f61f58d7569` |
| `refs/heads/feat/rg-f4-dataset-export` at verified HEAD (`refs/remotes/origin/...` in clone) | `42dbbf491225d2997d476f6931e8571cf5b33e44` | `820c49eefcd5d9cda1c30314583984baafe5e912` |
| `refs/pull/11/head` | `42dbbf491225d2997d476f6931e8571cf5b33e44` | `820c49eefcd5d9cda1c30314583984baafe5e912` (local simulation only) |
| `refs/pull/11/merge` | `8751d1b33b54d8154eedb9d338b507f3fa2a1494` | `752d76e6828c696e6327bca58ce162e2abf0d979` (local simulation only) |
| `refs/heads/main` | `52b774a877fb0898836e82a51ec6a774a5af9246` | unchanged |
| `refs/heads/feat/rg-f3-real-device-e2e` | `4e741a32d3718cf8e0a9a60b41d4b6679130dab4` | unchanged |
| `refs/heads/feat/rg-f5-mac-device-collector` | `3644e8a866a4e86a4f7e9cf1dd1c4cca7f489284` | unchanged |
| `refs/heads/EKF+DBSCAN` | `9b60f6da4e10f63bc7ac984c1adc2eb119aa3710` | unchanged |
| `refs/heads/archive/ekf-dbscan-research` | `9b60f6da4e10f63bc7ac984c1adc2eb119aa3710` | unchanged |
| `refs/heads/benchmark` | `cad644c731c6e11e9269235a4e75bc4bbe598226` | unchanged |
| `refs/heads/feat/rg-f2-native-boundary` | `d8cf5d1b61f1849aba4208c5761b22f5b9b0e8ca` | unchanged |
| `refs/heads/fix/rg-f1-pending-discovery` | `be2dfa0b14edf49e2867e7cc34b346cde8ce3348` | unchanged |
| `refs/heads/foundation/raw-gps` | `9dcc0a8a7304bc65dd83db95ab536be79c927b60` | unchanged |
| `refs/heads/plan/raw-gps-closeout-algorithm-study` | `6c3e42559d8b753268e0e33c2596fcf33482f8bc` | unchanged |

All other GitHub branch heads and PR refs were unchanged. GitHub has no tags in this snapshot. The `changed-refs` list identifies only PR #11 as affected; its refs are read-only on GitHub and were changed only in the disposable clone.

`git rev-list --all --objects` and `git log --all --full-history -- <sensitive path>` in the bounded clone did not reach the sensitive path or original blob. This verifies only reachability from that clone's rewritten refs. The original blob object still existed in the disposable partial-rewrite clone's object store before the clone was destroyed; it was unreachable from all refs. This does **not** purge the original GitHub object, cached views, GitHub PR refs, forks, or collaborators' clones.

**Residual metadata:** The unchanged safe-baseline commit already contains public research documents with truncated and full workout IDs plus one exact sample timestamp. The current report files now use session labels and omit that timestamp, but their older versions remain reachable through RG-F5 and other unchanged refs. Erasing those historical identifiers would require rewriting additional clean branch heads, contrary to this gate's exact-SHA preservation requirement. The owner must decide that separate privacy scope before any claim of complete historical de-identification; CSV blob cleanup alone does not accomplish it.

## Checks to repeat if any remote ref changes before approval

1. Freeze branch updates and record `git ls-remote --heads --tags origin`; verify every branch and tag against the review inventory. Clone GitHub into a disposable directory. Fetch PR refs explicitly, including `refs/pull/11/head` and `refs/pull/11/merge`; inspect all refs containing the introducing commit. Check the sensitive file's historical paths or renames and include each path in the filter command.
2. Run `git-filter-repo --sensitive-data-removal` with a bounded `--refs` range from the safe baseline for **every** affected branch and PR ref. Include the sensitive path using `--invert-paths --path`. `--refs` implies a partial rewrite and disables `--sensitive-data-removal`'s automatic fetch, so fetch and inventory all remote refs first. After explicitly fetching PR refs, `git-filter-repo --force` may be required **inside this disposable clone only**. Keep the tool's `commit-map`, `changed-refs`, first-changed-commit output, and LFS note.
3. Compare every old/new branch head and tag. Fail the gate if `main`, RG-F3, RG-F5, or any unrelated ref changes. Inspect `refs/pull/*/head` and `refs/pull/*/merge`; count affected PR heads from `changed-refs`. Verify `git rev-list --all --objects` has no original blob or sensitive path and `git log --all --full-history -- exports/historical/aetron_raw_gps_combined.csv` is empty for rewritten refs. Check for alternate filenames and any other identifying GPS content.
4. Present the **fresh-clone** old-to-new mapping and affected PR list to the owner. Stop. No push, merge, deployment, or production change is authorized by this document. Never use an indiscriminate `git push --force --mirror`; it could update clean refs or attempt to push GitHub's read-only PR refs.

## After separate owner approval and remote cleanup

Recheck the remote RG-F4 old SHA immediately before any approved update. If only RG-F4 needs an update, use an explicit refspec and an exact lease for that ref; do not update `main`, RG-F3, RG-F5, or tags. GitHub PR refs are read-only and require GitHub Support handling. Coordinate collaborators to discard tainted clones or rebase and clean them; merging old history can reintroduce the blob. Inspect forks and arrange cleanup with their owners.

After the approved push has removed all writable GitHub refs to the sensitive commit, open a [GitHub Support request](https://support.github.com/) for `DB-Ducbao113/FitnessExerciseApplication`. Supply the number and identifiers of affected PRs from the **fresh GitHub clone**, the `git-filter-repo` first changed commit(s), the path and original blob SHA, and the orphaned-LFS file if the tool reports one. Ask Support to dereference or delete affected PR refs, run server garbage collection, and remove cached views. GitHub states Support can do this only after other references are cleaned and forks do not retain the data. Verify cleanup after Support responds; a local rewrite or branch push alone cannot prove GitHub-hosted erasure.
