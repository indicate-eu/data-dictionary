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
- **Version history: clickable versions.** In the "Create New Version" modal, each
  past version in the history table links to that exact snapshot
  (`#/concept-sets?id=320&version=1.1.0`). Only versions that resolve to a stored
  snapshot are linked, so a link never lands on the "version not available"
  banner.

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
