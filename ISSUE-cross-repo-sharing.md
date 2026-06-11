# Import concept sets from another dictionary repo, with traceable provenance (multi-org sharing)

## Context

A concept set can be copied from one Git repository to another (e.g. between two consortium organizations that each maintain their own fork of this app). Today this is done by hand — copy a JSON, paste it into another repo — and nothing records where it came from. `metadata.uniqueId` already gives each set a stable lineage identity ("is this the same concept set?"), carried over on copy, but two things are missing:

1. **Provenance is not traceable.** Once a JSON is copied into another repo there is no record of the source repo, version, or organization it came from.
2. **Creator vs. current owner are conflated.** There is a single `metadata.organization` field, frozen at creation; when org B adopts a set from org A, B cannot mark itself as the current maintainer while preserving A's authorship.

We want a proper **import feature** in the SPA, plus the metadata fields that make provenance survive even a manual copy-paste.

## Current state

| Field | Behavior |
|---|---|
| `id` (1, 10, …) | Counter **local** to each repo (`id_counters.json`, `DATA.nextConceptSetId`). **Collides** across repos: two orgs assign `50` to different sets. Must be re-assigned on import. |
| `metadata.uniqueId` | UUID generated **once at creation**, never changed. The only stable identifier. Carried over unchanged on copy. ✅ |
| `metadata.organization` | Copied from profile/`config.json` **at creation**, never updated on edit. Single field → can't distinguish creator from current owner. |
| `createdBy` / `createdByDetails` | Set at creation, never rewritten. Survive copying. ✅ |
| `metadata.origin` | Field exists but is **always `null`** — never written anywhere in the code. |
| `version` | Manual SemVer. The `(id, version) → commit SHA` mapping is in `concept_sets_versions.json` (exposed as `DATA.conceptSetVersions`). |

A foreign dictionary repo exposes its full catalog as `docs/data.json` (keys: `conceptSets[]`, `conceptSetVersions`, `nextConceptSetId`, …), so an importer can fetch and parse it directly.

## Proposal

### Metadata changes

**1. Split `metadata.organization` into creator vs. current owner.**

```jsonc
"metadata": {
  "organization": {
    "created": { "name": "INDICATE Consortium", "url": "…" }, // creator org — immutable
    "current": { "name": "CHU Rennes", "url": "…" }           // org of the latest version — set to mine on import/edit
  }
}
```

When org B imports A's set, B sets `current` to its own org (B maintains the content now) while `created` stays "INDICATE" to preserve authorship.

**2. Add `metadata.sourceRepo` — written/refreshed on every edit.**

The URL of the repo that currently maintains this object. Because it lives *inside* the JSON and is kept current on every save, provenance survives even an uncoordinated manual copy-paste: whoever ends up with the JSON still has `uniqueId` + `organization.current` + `version` + `sourceRepo` to reconstruct where it came from, whether or not they fill in `origin`.

```jsonc
"metadata": {
  "sourceRepo": "https://github.com/indicate-eu/data-dictionary" // full URL — GitHub, GitLab, or any host
}
```

**3. Enable `metadata.origin` — written once on import, then frozen.**

The provenance of *this* copy: where it was imported from. Filled in by the **importer** (not the source), exactly once, at import time. Never touched on subsequent edits (so an A→B→C chain doesn't telescope — `origin` always means "the copy I came from").

```jsonc
"metadata": {
  "origin": {
    "uniqueId": "47ecf8f2-…",   // = same uniqueId (fork): proves it's the same lineage
    "repo": "https://github.com/indicate-eu/data-dictionary", // full URL — GitHub, GitLab, or any host
    "version": "1.1.2",          // the source version this copy started from
    "commit": "b5e2686…",        // source SHA for (uniqueId, version), from the source's conceptSetVersions — freezes the exact source
    "organization": { "name": "INDICATE Consortium", "url": "https://indicate-eu.org" },
    "importedDate": "2026-06-04"
  }
}
```

We deliberately do **not** add a content hash / `versionId`: source repos are assumed reachable, so the frozen `repo` + `version` + `commit` is enough to fetch the exact source JSON back when needed.

### Write rules

| Action | `id` | `uniqueId` | `organization.current` | `sourceRepo` | `origin` |
|---|---|---|---|---|---|
| Creation | new local | new | = my org | = my repo | `null` |
| Edit / version bump (same repo) | unchanged | unchanged | mine | refreshed = my repo | **unchanged** |
| **Import from another repo** | **new local** (re-assigned) | **kept** (= source) | **= my org** | **= my repo** | **written once, frozen** |

## Import feature (SPA)

A new "Import concept sets" entry (settings or concept-sets toolbar) with two modes:

**Mode A — from a repo URL.** User pastes the URL of another dictionary repo. The app fetches that repo's `docs/data.json`, lists its `conceptSets[]` in a datatable (name, category, version, organization, status), user multi-selects which to copy. For each selected set the app reads `conceptSetVersions` to resolve the source commit SHA.

**Mode B — from a single concept-set JSON URL** (or pasted JSON). Imports one set directly.

On import, for each set, the app:
1. **Re-assigns `id`** via `App.nextConceptSetId()` (avoids cross-repo collision) — `app.js:1643`.
2. **Keeps `uniqueId`** (fork: same lineage).
3. **Writes `origin`** from the source's fields (`uniqueId`, `repo`, `version`, commit from `conceptSetVersions`, `organization`, today's date) — frozen thereafter.
4. **Sets `organization.current`** to the importer's org; leaves `organization.created` as-is.
5. **Sets `sourceRepo`** to the importer's own repo.
6. Stores it as a local concept set (`App.addConceptSet`, `app.js:1657`) so the user can review/edit before proposing it back to their repo.

### Conflict handling (`uniqueId` already present locally)

**Invariant: a `uniqueId` is unique within a repo.** We never keep two files with the same `uniqueId` in our own repo — that would break lineage matching. So before importing each set, the app checks whether its `uniqueId` already exists locally and branches:

| Situation | Behavior |
|---|---|
| `uniqueId` **not** present locally | Clean import: new local `id`, write `origin`, etc. |
| `uniqueId` present, **same `version`** (already up to date) | Skip — it's a duplicate. Tell the user "already imported". |
| `uniqueId` present, **different `version`** (source diverged / newer) | **Conflict.** Offer the user a choice: **overwrite** the local copy (replace expression + metadata, set `origin` to the new source, keep the existing local `id`) or **cancel** this set's import. Never create a second file with the same `uniqueId`. |

In Mode A (repo URL), the datatable should flag which selected sets are new / up-to-date / in conflict *before* importing, so the user reviews the batch in one pass rather than dismissing per-set dialogs.

## Migration of existing concept sets

- `metadata.organization` (`{name, url}`) → copied into both `organization.created` and `organization.current`.
- `metadata.sourceRepo` → set to this repo's URL (from `config.json`) for every existing set.
- `metadata.origin` → stays `null` for all existing content (no past imports tracked).
- The SPA already normalizes legacy shapes at read time (`app.js`) → add normalization from the old flat `organization` to `{created, current}`, and default `sourceRepo` when absent.

## Decisions made

- Fork model: **same `uniqueId`** (shared worldwide lineage, divergence tracked), not a fresh lineage on copy.
- No `versionId` / content hash: rely on reachable source repos (`origin.repo` + `version` + `commit`).
- `origin` is written **once at import** by the importer and frozen; `sourceRepo` is refreshed on every edit.
- A `uniqueId` is **unique within a repo**: importing a `uniqueId` that already exists either skips (same version) or overwrites the existing local copy (different version) — never creates a duplicate.

## Open questions

1. **Organization identifier**: keep `{name, url}` (trivial migration), or add a stable `orgId`/slug (`indicate`, `chu-rennes`) to match orgs reliably across repos even if the display name changes (requires a slug registry)? *Proposed: keep `{name, url}` for now.*
2. **CORS / fetch**: fetching a foreign repo's `docs/data.json` cross-origin — rely on GitHub/GitLab Pages serving permissive CORS, or also support a "paste JSON" fallback for hosts that don't? *Proposed: support both URL and paste.*
3. **Versions of imported sets**: do we also import the source's full `versions[]` history, or just the current snapshot? *Proposed: current snapshot only; `origin.commit` lets us fetch history if needed.*

## Affected files (indicative)

- `docs/concept-sets.js` — generation at creation (`crypto.randomUUID()`, ~L5521), edit (`updateConceptSet`); new import flow + datatable.
- `docs/app.js` — `nextConceptSetId` (L1643), `addConceptSet` (L1657), `getOrganization` (L1356), legacy read-time normalization (~L169).
- `docs/settings.js` — entry point for the import UI.
- `concept_set.example.json` + `CLAUDE.md` — schema documentation (new `sourceRepo`, `origin` shape, `organization.created/current`).
- One-shot migration script for `concept_sets/*.json`.
