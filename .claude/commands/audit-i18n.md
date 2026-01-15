# Internationalization (i18n) Audit

Audit the codebase for translation completeness and consistency.

## Arguments

$ARGUMENTS

If no arguments provided, audit all R files and translation CSV files.
If a file path is provided, focus the analysis on that specific file.

## Analysis Steps

### Phase 1: Extract all translatable strings

1. **Scan all R files** for:
   - `i18n$t("key")` calls - extract the key
   - Hard-coded strings in UI elements:
     - `tags$h1("Text")`, `tags$p("Text")`, etc.
     - `actionButton(..., "Label")`
     - `textInput(..., label = "Label")`
     - `showNotification("Message")`
     - Modal titles and messages
   - String literals that should be translated

2. **Categorize strings**:
   - Already using i18n (good)
   - Hard-coded UI text (needs translation)
   - Technical strings (should NOT be translated: IDs, CSS classes, etc.)

### Phase 2: Audit translation files

1. **Read translation files**:
   - `inst/translations/translation_en.csv`
   - `inst/translations/translation_fr.csv`

2. **Check for**:
   - Keys in EN but missing in FR
   - Keys in FR but missing in EN
   - Empty translations
   - Duplicate keys
   - Unused keys (defined but never called)

### Phase 3: Consistency check

1. **Naming conventions**:
   - Keys should use snake_case
   - Keys should be descriptive
   - Related keys should share prefixes (e.g., `btn_save`, `btn_cancel`)

2. **Content consistency**:
   - Placeholder consistency (`{0}`, `{1}` in both languages)
   - Punctuation consistency
   - Capitalization patterns

## Output Format

```markdown
## i18n Audit Report

### 1. Translation Coverage

| Language | Total Keys | Translated | Missing | Coverage |
|----------|------------|------------|---------|----------|
| English | 150 | 150 | 0 | 100% |
| French | 150 | 142 | 8 | 94.7% |

### 2. Hard-coded Strings (Need Translation)

| File:Line | String | Suggested Key | Context |
|-----------|--------|---------------|---------|
| mod_a.R:123 | "Save changes" | `btn_save_changes` | Button label |
| mod_b.R:456 | "Error occurred" | `error_generic` | Notification |

### 3. Missing Translations

#### French (translation_fr.csv)
| Key | English Value |
|-----|---------------|
| `new_feature_title` | "New Feature" |

### 4. Unused Keys (Dead Translations)

| Key | Defined In | Never Used |
|-----|------------|------------|
| `old_button_label` | EN, FR | All files checked |

### 5. Inconsistencies

| Issue | Key | EN | FR |
|-------|-----|----|----|
| Missing placeholder | `welcome_user` | "Welcome {0}" | "Bienvenue" |
| Different punctuation | `confirm_delete` | "Delete?" | "Supprimer" |

### 6. Naming Issues

| Current Key | Suggested Key | Reason |
|-------------|---------------|--------|
| `saveBtn` | `btn_save` | Use snake_case |
| `x` | `btn_close` | Not descriptive |

### 7. Recommendations

1. **High priority**: Add missing French translations (8 keys)
2. **Medium priority**: Replace hard-coded strings (15 occurrences)
3. **Low priority**: Rename inconsistent keys (3 keys)
```

## String Detection Patterns

### Strings that SHOULD be translated:
- UI labels and titles
- Button text
- Error and success messages
- Table headers shown to users
- Tooltip text
- Modal content
- Help text

### Strings that should NOT be translated:
- HTML IDs and classes
- JavaScript function names
- Database column names
- File paths
- CSS properties
- Technical identifiers
- Log messages (internal)

## Instructions

- **Be thorough** - check all UI-facing strings
- **Suggest appropriate keys** following naming conventions
- **Group related translations** for batch fixes
- **Consider context** - same English word may need different translations
- **Flag placeholders** that need to match across languages
- **Update `.claude/analysis/i18n-index.md`** with findings

## i18n Index Location

The persistent index is maintained at: `.claude/analysis/i18n-index.md`

After analysis, update this file with:
- Complete list of translation keys and their usage
- Hard-coded strings inventory
- Translation status by language
- Date of last analysis
