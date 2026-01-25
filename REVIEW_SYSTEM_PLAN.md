# Review System Implementation Plan

## Overview

This document outlines the plan for implementing a comprehensive review system for OHDSI concept sets in the INDICATE Data Dictionary application. The system will support collaborative review workflows with version control and status tracking.

## Database Schema

### 1. Modified Tables

#### `concept_sets` table
Add new column:
- `review_status` TEXT DEFAULT 'draft'
  - Possible values: 'draft', 'pending_review', 'approved', 'needs_revision', 'deprecated'

#### `users` table
Changes:
- Rename `role` → `profession` (TEXT field, free text input)
- Add `orcid` TEXT (optional ORCiD identifier with validation)

### 2. New Tables

#### `concept_set_reviews`
```sql
CREATE TABLE concept_set_reviews (
  review_id INTEGER PRIMARY KEY AUTOINCREMENT,
  concept_set_id INTEGER NOT NULL,
  version TEXT NOT NULL,
  reviewer_user_id INTEGER NOT NULL,
  status TEXT NOT NULL, -- 'pending_review', 'approved', 'needs_revision'
  comments TEXT,
  review_date TEXT NOT NULL,
  FOREIGN KEY (concept_set_id) REFERENCES concept_sets(id),
  FOREIGN KEY (reviewer_user_id) REFERENCES users(user_id)
)
```

Purpose: Track individual reviews of concept sets. Multiple users can review the same concept set version.

#### `concept_set_changelog`
```sql
CREATE TABLE concept_set_changelog (
  change_id INTEGER PRIMARY KEY AUTOINCREMENT,
  concept_set_id INTEGER NOT NULL,
  version_from TEXT,
  version_to TEXT NOT NULL,
  changed_by_user_id INTEGER NOT NULL,
  change_date TEXT NOT NULL,
  change_type TEXT NOT NULL, -- 'created', 'updated', 'status_changed', 'reviewed'
  change_summary TEXT,
  changes_json TEXT, -- JSON blob with detailed changes
  FOREIGN KEY (concept_set_id) REFERENCES concept_sets(id),
  FOREIGN KEY (changed_by_user_id) REFERENCES users(user_id)
)
```

Purpose: Maintain a complete audit trail of all changes to concept sets, including concept additions/removals, metadata changes, status changes, and review actions.

## Review Workflow States

### Status Progression

1. **draft** (initial state)
   - Concept set is being created/edited
   - Not ready for review
   - Can be freely modified by editors

2. **pending_review**
   - Concept set submitted for review
   - Locked from editing (or edits create new version)
   - Reviewers can add comments and change status

3. **needs_revision**
   - Reviewers have requested changes
   - Returns to draft-like state for modifications
   - Once revised, can be resubmitted (→ pending_review)

4. **approved**
   - Review complete, concept set validated
   - Ready for use in production/studies
   - Can still be edited (creates new version as draft)

5. **deprecated**
   - Concept set no longer recommended for use
   - Retained for historical reference
   - Cannot be edited (only status can change)

## UI Components to Implement

### 1. Concept Set Detail Page Updates

#### Status Badge
Display current review status with color coding:
- Draft: gray
- Pending Review: yellow/orange
- Approved: green
- Needs Revision: red
- Deprecated: dark gray

#### Version Badge
Show current version number (e.g., "v1.2.3")

#### Review Metadata
Display in detail section:
- Current status
- Last review date
- Reviewer name(s)
- Review comments

### 2. Concept Sets DataTable Updates

Add columns:
- **Status**: Colored background based on review_status
- **Version**: Current version number
- **Author**: created_by (from user table with name)
- **Last Update**: modified_date (formatted)
- **Tags**: Display as badge chips (already implemented, ensure styling)

Add filter icon (funnel icon) with dropdown filters for:
- Category (multi-select)
- Subcategory (multi-select)
- Status (multi-select)
- Tags (multi-select)

### 3. New Review Tab

Location: In concept set detail view, alongside Edit/View/Comments tabs

Components:

#### Review List Section
- DataTable showing all reviews for this concept set
- Columns: Reviewer, Date, Status, Version, Comments
- Sort by date (newest first)

#### Add Review Form
Available to users with review permissions:
- Status dropdown (pending_review, approved, needs_revision)
- Comments textarea
- Submit button
- Auto-records reviewer_user_id and timestamp

#### Version Management
- Button to create new version (increments version number)
- Shows version history with changes
- Links to changelog entries

### 4. Status Change Modal

Triggered when changing concept set status:
- Dropdown for new status
- Required comments field (reason for status change)
- Confirmation button
- Records change in changelog

### 5. Version Modal

Create new version dialog:
- Version number input (auto-suggest increment)
- Change summary textarea
- Option to copy all concepts from previous version
- Create button

## Functions to Implement

### Database Functions (fct_database.R)

```r
# Review operations
add_concept_set_review(concept_set_id, version, reviewer_user_id, status, comments)
get_concept_set_reviews(concept_set_id)
get_latest_review(concept_set_id)
update_concept_set_status(concept_set_id, new_status, user_id, comments)

# Changelog operations
add_changelog_entry(concept_set_id, version_from, version_to, user_id, type, summary, changes_json)
get_concept_set_changelog(concept_set_id)
get_changelog_between_versions(concept_set_id, version_from, version_to)

# Version management
create_new_version(concept_set_id, new_version, user_id, summary, copy_concepts = TRUE)
get_version_history(concept_set_id)
compare_versions(concept_set_id, version_1, version_2)
```

### Helper Functions (utils_server.R or new fct_reviews.R)

```r
# Version comparison
diff_concept_sets(concepts_v1, concepts_v2)
# Returns: list(added = [...], removed = [...], modified = [...])

# Status validation
can_change_status(from_status, to_status, user_role)
# Returns: TRUE/FALSE based on workflow rules

# Notification helpers
notify_reviewers(concept_set_id, message)
notify_author(concept_set_id, review_status, comments)
```

## Implementation Phases

### Phase 1: Database & Backend (COMPLETED)
- ✅ Update schema (add review_status, profession, orcid)
- ✅ Create new tables (reviews, changelog)
- ✅ Update user CRUD functions
- ✅ Add migration logic for existing databases

### Phase 2: Basic UI Updates (PENDING)
- [ ] Add status and version badges to detail page
- [ ] Add status/version/author/date columns to DataTable
- [ ] Style status column with colored backgrounds
- [ ] Display tags as styled badges in DataTable
- [ ] Add filters icon with dropdown filters

### Phase 3: Review Tab (PENDING)
- [ ] Create Review tab UI component
- [ ] Implement review list DataTable
- [ ] Create add review form
- [ ] Wire up backend functions for review CRUD
- [ ] Add permission checks (who can review)

### Phase 4: Version Management (PENDING)
- [ ] Create version modal dialog
- [ ] Implement version creation logic
- [ ] Add version comparison view
- [ ] Display changelog in UI
- [ ] Link reviews to specific versions

### Phase 5: Advanced Features (FUTURE)
- [ ] Email notifications for review requests
- [ ] Automatic Git export on approval
- [ ] Conflict resolution for concurrent edits
- [ ] Review assignment workflow
- [ ] Bulk status changes
- [ ] Review statistics dashboard

## Notes and Considerations

### Version Numbering
- Use semantic versioning (MAJOR.MINOR.PATCH)
- Auto-increment PATCH for minor edits
- Increment MINOR for concept additions/removals
- Increment MAJOR for breaking changes (manual)

### Permissions
- Who can submit for review? (Editors only?)
- Who can approve? (Reviewers, Admins?)
- Can authors review their own concept sets? (No)

### Git Integration (Future)
- When status changes to 'approved', trigger Git export
- Export concept set as JSON to Git repository
- Include version number in commit message
- Store Git commit hash in changelog

### JSON Export Updates
- Already implemented: OHDSI-compliant JSON export
- Includes metadata (category, subcategory, mappingGuidance)
- Need to add: review_status, current version, last_review_date

### Changelog JSON Structure
Example of changes_json field:
```json
{
  "concepts_added": [12345, 67890],
  "concepts_removed": [11111],
  "metadata_changes": {
    "description": {
      "from": "Old description",
      "to": "New description"
    },
    "category": {
      "from": "Conditions",
      "to": "Medications"
    }
  },
  "flags_changed": {
    "12345": {
      "isExcluded": {"from": false, "to": true}
    }
  }
}
```

## Related Documentation

- OHDSI Concept Set Specification: Used for JSON export format
- Shiny Modules Pattern: All UI components follow the mod_*_ui/mod_*_server pattern
- Database Guidelines: See CLAUDE.md for RSQLite NULL handling rules

## Contact

For questions about this implementation plan:
- Author: Boris Delange (boris.delange@univ-rennes.fr)
- Project: INDICATE Data Dictionary
