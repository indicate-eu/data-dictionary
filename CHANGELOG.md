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

- **Past versions are no longer embedded in `data.json`.** Only small pinned
  definitions are (up to 500 expression items); resolved lists and large
  definitions are fetched instead. Previously a pinned snapshot had no size limit
  at all, so pinning one microbiology set to an older version grew `data.json` from
  3.8 MB to 7.4 MB. Pages that read a pinned version — project CSV export, the
  update-concept-set diff, mapping coverage — now preload it first, following the
  pattern `ensureResolvedLoaded` already used for deferred resolved files.

### Fixed

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
