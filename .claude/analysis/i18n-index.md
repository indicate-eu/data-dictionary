# Internationalization (i18n) Index

This file tracks translation keys, hard-coded strings, and i18n completeness.

**Last updated**: Not yet analyzed
**Run `/audit-i18n` to update this index**

---

## 1. Translation Status

### Overview

| Language | File | Total Keys | Translated | Coverage |
|----------|------|------------|------------|----------|
| English | translation_en.csv | *TBD* | *TBD* | *TBD* |
| French | translation_fr.csv | *TBD* | *TBD* | *TBD* |

### Missing Translations

#### French

| Key | English Value | Priority |
|-----|---------------|----------|
| *Run /audit-i18n to populate* | | |

#### English

| Key | French Value | Priority |
|-----|--------------|----------|
| *Run /audit-i18n to populate* | | |

---

## 2. Translation Keys by Category

### Navigation & Headers

| Key | EN | FR | Used In |
|-----|----|----|---------|
| *Run /audit-i18n to populate* | | | |

### Buttons & Actions

| Key | EN | FR | Used In |
|-----|----|----|---------|
| *Run /audit-i18n to populate* | | | |

### Form Labels

| Key | EN | FR | Used In |
|-----|----|----|---------|
| *Run /audit-i18n to populate* | | | |

### Messages & Notifications

| Key | EN | FR | Used In |
|-----|----|----|---------|
| *Run /audit-i18n to populate* | | | |

### Table Headers

| Key | EN | FR | Used In |
|-----|----|----|---------|
| *Run /audit-i18n to populate* | | | |

### Modal Content

| Key | EN | FR | Used In |
|-----|----|----|---------|
| *Run /audit-i18n to populate* | | | |

---

## 3. Hard-coded Strings

### High Priority (User-facing)

| File:Line | String | Suggested Key | Context |
|-----------|--------|---------------|---------|
| *Run /audit-i18n to populate* | | | |

### Medium Priority (UI elements)

| File:Line | String | Suggested Key | Context |
|-----------|--------|---------------|---------|
| *Run /audit-i18n to populate* | | | |

### Low Priority (Technical)

| File:Line | String | Notes |
|-----------|--------|-------|
| *Run /audit-i18n to populate* | | |

---

## 4. Unused Translation Keys

| Key | EN Value | FR Value | Last Reference |
|-----|----------|----------|----------------|
| *Run /audit-i18n or /dead-code i18n to identify* | | | |

---

## 5. Inconsistencies

### Placeholder Mismatches

| Key | EN (placeholders) | FR (placeholders) |
|-----|-------------------|-------------------|
| *Run /audit-i18n to identify* | | |

### Naming Convention Issues

| Current Key | Suggested Key | Reason |
|-------------|---------------|--------|
| *Run /audit-i18n to identify* | | |

---

## 6. Progress Log

| Date | Action | Keys Added | Strings Translated |
|------|--------|------------|-------------------|
| *None yet* | | | |

---

## Key Naming Conventions

### Prefixes by Type

| Prefix | Usage | Example |
|--------|-------|---------|
| `btn_` | Button labels | `btn_save`, `btn_cancel` |
| `lbl_` | Form labels | `lbl_username`, `lbl_password` |
| `msg_` | Messages/notifications | `msg_success`, `msg_error` |
| `tbl_` | Table headers | `tbl_name`, `tbl_status` |
| `modal_` | Modal content | `modal_confirm_title` |
| `nav_` | Navigation | `nav_home`, `nav_settings` |
| `placeholder_` | Input placeholders | `placeholder_search` |
| `tooltip_` | Tooltips | `tooltip_help` |
| `error_` | Error messages | `error_required`, `error_invalid` |

### Module Prefixes

| Prefix | Module |
|--------|--------|
| `dict_` | Dictionary Explorer |
| `mapping_` | Concept Mapping |
| `project_` | Projects |
| `settings_` | General Settings |
| `user_` | Users |
| `dev_` | Dev Tools |

---

## Notes

- This index is maintained by running `/audit-i18n` command
- All user-facing strings should use `i18n$t("key")`
- Technical strings (IDs, classes, paths) should NOT be translated
- Placeholders use `{0}`, `{1}` format - must match across languages
