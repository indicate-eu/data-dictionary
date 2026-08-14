# Changelog

Notable changes to the INDICATE Data Dictionary application and its content.

Concept sets carry their own semantic version and per-version history in
`metadata.versions`; this file records changes to the app, the build pipeline and
the shared data files (units, projects), plus content changes broad enough to
affect data providers.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.2.6] — 2026-08-14

### Added

- **SQL export: permalink header.** The generated query now carries a link back to
  the concept set it came from, pinned to the version it was generated with
  (`#/concept-sets?id=320&version=1.2.0`). A query pasted into an ETL repository
  stays traceable to its definition, even after the set is bumped. The site root
  is derived from `config.github.repo`, so forks get their own URL.
- **SQL export: "Drop rows in other units" checkbox.** Next to the reference-unit
  dropdown. When ticked, the unit filter is emitted as live SQL rather than a
  commented-out suggestion, so the query returns only rows in a unit that could be
  harmonised. The choice is kept in `localStorage` across sessions.
- **Version history: clickable versions.** The version modal is now titled
  "Versions" and opens on the history, with the creation form behind a button.
  Each past version is a clickable row leading to that version
  (`#/concept-sets?id=320&version=1.1.0`); the current one shows as a green badge.
- **Any published version is now browsable.** Past versions are fetched on demand
  from the repository at the commit recorded in `concept_sets_versions.json`, whose
  index now ships in `data.json` (+34 KB). Both the definition and the resolved
  concept list are retrieved, so an old version shows the concepts it actually had.
  Results are cached, so the existing synchronous getters serve them afterwards.
  This needs network access.
- **Viewing a past version no longer traps you there.** The version modal opens
  from a snapshot as well, and lists the *latest* set's history — so newer versions
  are reachable, not just older ones. Creating a version stays restricted to the
  latest. The green badge marks the version on screen.

### Changed

- **`config.json`'s `github` block is now `repository`.** The name dated from when
  the project only targeted GitHub, and read as a contradiction on a GitLab fork
  where every key was still `github.*`. `github` is still accepted, so existing
  forks keep working untouched.
- **Past versions are no longer embedded in `data.json`.** Only small pinned
  definitions are (up to 500 expression items); resolved lists and large
  definitions are fetched instead. Previously a pinned snapshot had no size limit
  at all, so pinning one microbiology set to an older version grew `data.json` from
  3.8 MB to 7.4 MB. Pages that read a pinned version — project CSV export, the
  update-concept-set diff, mapping coverage — now preload it first, following the
  pattern `ensureResolvedLoaded` already used for deferred resolved files.

### Fixed

- **GitLab forks published a broken site.** `.gitlab-ci.yml` only copied `docs/`
  into `public/`, on the stated assumption that `docs/data.json` and
  `docs/data_inline.js` were committed — but `.gitignore` excludes them, so every
  GitLab fork deployed without its data files and the app died on `DATA is not
  defined`. The job now runs `build.py` like the GitHub workflow does, on an image
  carrying Python and git, and fetches the full history (`GIT_DEPTH: 0`): a shallow
  clone cannot read the past commits that pinned versions point at, which would
  drop those concept sets from the published site with only a warning. Reported by
  a fork on Framagit.
- **`build.py` and `snapshot.py` failed opaquely without git or without a commit.**
  A missing `git` binary raises `FileNotFoundError`, which neither script caught,
  so CI images without git ended on a bare traceback. It now exits with a message
  naming the fix. When `git show` fails for a pinned version, the warning points
  at the shallow clone as the likely cause.
- **`reset.py` on a fresh fork no longer fails on the build step.** `FORKING.md`
  wipes the content (§1.5) before the first commit (§1.7), but `reset.py` ended by
  running `build.py`, which needs a `HEAD` to record version snapshots against — so
  following the guide in order hit "ambiguous argument 'HEAD'". A note explained the
  workaround, but it silently reordered the two sections and was easy to miss.
  `reset.py` now detects that the repository has no commit, skips the build, and
  prints the two commands to run next; the guide's order works as written.
- **"Propose on GitHub" pointed at github.com from non-GitHub forks.** Every edit
  and blob URL was built by interpolating `config.github.repo` into a hardcoded
  `https://github.com/`, so the main contribution path was broken for the GitLab
  forks `FORKING.md` invites. URLs now derive their origin from a new
  `config.github.url` (the fork's own repo — not `upstream`, which points at the
  project it was forked from), and use each forge's route shape: GitLab
  namespaces these under `/-/`, GitHub does not. Buttons, tooltips, toasts and the
  documentation say "GitLab" on a GitLab fork, and the GitHub mark is swapped for
  the GitLab one. `config.github.forge` overrides the detection for a self-hosted
  instance whose domain gives nothing away.
- **`FORKING.md` documented the opposite of what the repo ships.** §4.3 presented
  committed data files as the default and building in CI as the opt-in, when the
  shipped `.gitignore` is the reverse; §4.1 told readers to serve `/docs` from a
  branch, which skips the build. §4.2 also asserted a gitlab.com Pages URL shape
  that self-hosted instances do not follow. §1.5 described a `--keep-units` flag
  that does not exist and claimed `reset.py` wipes `recommended_units.json` (it
  keeps it) while omitting that it empties `mapping_recommendations.json` and
  resets `concept_sets_versions.json`; §1.7 staged two gitignored files, which
  `git add` refuses; §3's list of synced paths omitted `snapshot.py`.

- **SQL export: missing unit filter on single-unit concept sets.** The optional
  `AND unit_concept_id IN (…)` filter was only emitted when unit conversions were
  registered. A set with a recommended unit but no conversion — Heart rate, for
  instance — never got it, which is exactly where it matters most: a source
  sending an unexpected unit flowed through the `CASE`'s `ELSE` unconverted,
  unfiltered and unflagged, landing in `value_as_number` as if harmonised. The
  filter is now emitted whenever a reference unit exists, worded for the
  no-conversion case ("the expected unit" rather than "the convertible units").
  Sets with no recommended unit at all (clinical scores, microbiology) still get
  no filter.
