# Shiny Module Reactivity Analysis

Analyze the reactivity of the specified Shiny module and generate structured documentation.

## File to analyze

$ARGUMENTS

If no argument provided, list available modules and ask which one to analyze.

## Output Location

**IMPORTANT**: Documentation is stored in `.claude/analysis/reactivity/`, NOT in the R file itself.

- Output file: `.claude/analysis/reactivity/mod_[name].md`
- The R file should only contain the `MODULE STRUCTURE OVERVIEW` comment (UI/Server structure)
- Reactivity documentation is maintained separately for easier updates

## Analysis Steps

1. **Read the module file** in `R/mod_*.R`
2. **Check existing documentation** in `.claude/analysis/reactivity/mod_*.md`
3. **Search for reactiveVal and reactive** definitions
4. **Search for all observe_event()** and identify their triggers
5. **Identify triggers** (reactiveVal used to trigger cascades, typically named `*_trigger`)
6. **Trace reactivity chains**: State → Primary trigger → Cascade → Composite trigger → Output
7. **Identify potential issues**:
   - Multiple observers on the same state
   - Non-cascade patterns (using `list()` in observe_event)
   - Nested observers
   - `req()` instead of `if/return`
   - Direct output assignments without observer wrapper
   - Unused or duplicated triggers

## Documentation Structure

Generate a markdown file in `.claude/analysis/reactivity/mod_[name].md`:

```markdown
# Reactivity: mod_[name].R

**Last analyzed**: [YYYY-MM-DD]
**Module file**: `R/mod_[name].R`
**Lines**: [total lines]
**Complexity**: [Low/Medium/High/Very High]
**Follows cascade pattern**: [Yes/Partially/No]

---

## Summary

[Brief description of the module's purpose and reactive architecture]

---

## Primary State Reactives

| Variable | Type | Purpose | Initial Value | Line |
|----------|------|---------|---------------|------|
| selected_row | reactiveVal | Currently selected table row | NULL | L:123 |
| edit_mode | reactiveVal | Whether edit mode is active | FALSE | L:125 |

---

## Triggers

### Primary Triggers (fire when state changes)

| Trigger | Fires When | Line |
|---------|------------|------|
| selection_trigger | selected_row() changes | L:150 |
| edit_mode_trigger | edit_mode() changes | L:152 |

### Composite Triggers (aggregate multiple primary triggers)

| Trigger | Aggregates | Updates | Line |
|---------|------------|---------|------|
| table_trigger | selection_trigger, filter_trigger | output$main_table | L:200 |
| details_trigger | selection_trigger | output$details_panel | L:202 |

---

## Cascade Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ STATE CHANGES                                                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  selected_row() ─────► selection_trigger ─────► cascade_observer            │
│                                                  ├──► table_trigger          │
│                                                  └──► details_trigger        │
│                                                                              │
│  edit_mode() ────────► edit_mode_trigger ─────► cascade_observer            │
│                                                  ├──► table_trigger          │
│                                                  └──► buttons_trigger        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ COMPOSITE TRIGGERS → OUTPUTS                                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  table_trigger ──────────────────────────► output$main_table (renderDT)     │
│  details_trigger ────────────────────────► output$details_panel (renderUI)  │
│  buttons_trigger ────────────────────────► shinyjs::show/hide               │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Observers Detail

### Primary State Observers (State → Trigger)

| Line | Listens To | Fires Trigger |
|------|------------|---------------|
| L:150 | selected_row() | selection_trigger |
| L:155 | edit_mode() | edit_mode_trigger |

### Cascade Observers (Trigger → Composite Triggers)

| Line | Listens To | Fires |
|------|------------|-------|
| L:200 | selection_trigger | table_trigger, details_trigger |
| L:210 | edit_mode_trigger | table_trigger, buttons_trigger |

### UI Observers (Composite Trigger → Output)

| Line | Listens To | Renders |
|------|------------|---------|
| L:300 | table_trigger | output$main_table |
| L:350 | details_trigger | output$details_panel |

### Direct Observers (User Interactions)

| Line | Input | Action |
|------|-------|--------|
| L:400 | input$add_btn | Opens modal, resets form |
| L:420 | input$save_btn | Saves data, updates state |
| L:440 | input$delete_btn | Shows confirmation, deletes on confirm |

---

## Outputs

| Output | Type | Triggered By | Line |
|--------|------|--------------|------|
| output$main_table | renderDT | table_trigger | L:300 |
| output$details_panel | renderUI | details_trigger | L:350 |
| output$breadcrumb | renderUI | breadcrumb_trigger | L:380 |

---

## Pattern Compliance

### ✅ Correct Patterns Found

- [ ] Uses `observe_event()` (not `observeEvent`)
- [ ] No nested observers
- [ ] No `req()` (uses `if/return` instead)
- [ ] Outputs wrapped in observers
- [ ] Uses cascade pattern for multi-trigger scenarios

### ⚠️ Issues Found

| Line | Issue | Severity | Description |
|------|-------|----------|-------------|
| L:XXX | [Issue type] | [High/Medium/Low] | [Description] |

---

## Recommendations

1. [Specific recommendation if issues found]
2. [Another recommendation]

---

## Cross-References

- **Module structure**: See `R/mod_[name].R` (MODULE STRUCTURE OVERVIEW comment)
- **CSS classes used**: See `.claude/analysis/css-index.md`
- **Functions called**: See `.claude/analysis/codebase-index.md`
```

## Instructions

1. **Always create/update the file** in `.claude/analysis/reactivity/`
2. **Use exact line numbers** for easy navigation (format: `L:123`)
3. **Be thorough** - list ALL reactiveVal, ALL triggers, ALL observers
4. **Check pattern compliance** against CLAUDE.md rules
5. **Provide actionable recommendations** for any issues found
6. **Update the date** when re-analyzing

## After Analysis

1. Update `.claude/analysis/codebase-index.md` with module statistics
2. Report summary to user with key findings
3. If issues found, suggest running `/audit-patterns` for full compliance check
