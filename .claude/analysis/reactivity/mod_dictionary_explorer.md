# Reactivity: mod_dictionary_explorer.R

**Last analyzed**: 2026-01-15
**Module file**: `R/mod_dictionary_explorer.R`
**Lines**: ~5000+
**Complexity**: Very High
**Follows cascade pattern**: Yes

---

## Summary

This module provides the Dictionary Explorer interface with two main views:
- **General Concepts Page**: Browse and manage general concepts
- **Associated Concepts Page**: View and edit associated concepts (OMOP mappings)

The module uses a **CASCADE PATTERN** for reactivity management:
1. PRIMARY STATE REACTIVES: The actual state values
2. PRIMARY TRIGGERS: Fire when state changes
3. CASCADE OBSERVERS: Listen to primary triggers and fire COMPOSITE TRIGGERS
4. COMPOSITE TRIGGERS: Aggregated triggers that UI observers listen to
5. UI OBSERVERS: Render outputs when their composite trigger fires

Flow: State Change → Primary Trigger → Cascade → Composite Trigger → UI Update

---

## Primary State Reactives

| Variable | Type | Purpose | Initial Value | Line |
|----------|------|---------|---------------|------|
| current_view | reactiveVal | "list", "detail", "detail_history", "list_history" | "list" | TBD |
| selected_concept_id | reactiveVal | Currently selected general concept ID | NULL | TBD |
| selected_mapped_concept_id | reactiveVal | Currently selected mapping in concept_mappings tables | NULL | TBD |
| selected_categories | reactiveVal | Category filter badges selection | c() | TBD |
| general_concept_detail_edit_mode | reactiveVal | Edit mode for detail page | FALSE | TBD |
| general_concepts_edit_mode | reactiveVal | Edit mode for list page | FALSE | TBD |
| comments_tab | reactiveVal | "comments" or "statistical_summary" | "comments" | TBD |
| relationships_tab | reactiveVal | "related", "hierarchy", or "synonyms" | "related" | TBD |
| local_data | reactiveVal | Local copy of CSV data | NULL | TBD |
| deleted_concepts | reactiveVal | Temporary deleted mappings before save | c() | TBD |
| added_concepts | reactiveVal | Temporary added mappings before save | list() | TBD |

---

## Triggers

### Primary Triggers (fire when state changes)

| Trigger | Fires When | Line |
|---------|------------|------|
| view_trigger | current_view() changes | TBD |
| concept_trigger | selected_concept_id() changes | TBD |
| general_concept_detail_edit_mode_trigger | general_concept_detail_edit_mode() changes | TBD |
| general_concepts_edit_mode_trigger | general_concepts_edit_mode() changes | TBD |
| local_data_trigger | local_data() changes | TBD |
| selected_categories_trigger | selected_categories() changes | TBD |
| comments_tab_trigger | comments_tab() changes | TBD |
| mapped_concept_trigger | selected_mapped_concept_id() changes | TBD |
| deleted_concepts_trigger | deleted_concepts() changes | TBD |

### Composite Triggers (aggregate multiple primary triggers)

| Trigger | Aggregates | Updates | Line |
|---------|------------|---------|------|
| breadcrumb_trigger | view_trigger, edit_mode_triggers | output$breadcrumb | TBD |
| history_ui_trigger | view_trigger, concept_trigger | output$*_history_ui | TBD |
| general_concepts_table_trigger | edit_mode, local_data, categories | output$general_concepts_table | TBD |
| concept_mappings_table_trigger | concept, edit_mode, deleted_concepts | output$concept_mappings_table | TBD |
| comments_display_trigger | concept, edit_mode, local_data, comments_tab | output$comments_display | TBD |
| selected_mapping_details_trigger | concept, mapped_concept | output$selected_mapping_details | TBD |
| mapped_concepts_header_trigger | edit_mode | output$mapped_concepts_header_buttons | TBD |
| relationship_tab_outputs_trigger | mapped_concept | output$concept_relationships_display | TBD |
| history_tables_trigger | view, concept | output$*_history_table | TBD |

---

## Cascade Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│ STATE CHANGES → PRIMARY TRIGGERS → CASCADE OBSERVERS → COMPOSITE TRIGGERS                       │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                 │
│  current_view() ──────────► view_trigger ──────────► observe_event(view_trigger)               │
│                                                       ├──► breadcrumb_trigger                  │
│                                                       └──► history_ui_trigger                  │
│                                                                                                 │
│  selected_concept_id() ───► concept_trigger ───────► observe_event(concept_trigger)            │
│                                                       ├──► history_ui_trigger                  │
│                                                       ├──► comments_display_trigger            │
│                                                       ├──► concept_mappings_table_trigger      │
│                                                       └──► selected_mapping_details_trigger    │
│                                                                                                 │
│  general_concept_detail     general_concept_detail   observe_event(...)                        │
│  _edit_mode() ────────────► _edit_mode_trigger ────► ├──► breadcrumb_trigger                   │
│                                                       ├──► comments_display_trigger            │
│                                                       ├──► concept_mappings_table_trigger      │
│                                                       └──► mapped_concepts_header_trigger      │
│                                                                                                 │
│  general_concepts           general_concepts         observe_event(...)                        │
│  _edit_mode() ────────────► _edit_mode_trigger ────► ├──► breadcrumb_trigger                   │
│                                                       └──► general_concepts_table_trigger      │
│                                                                                                 │
│  local_data() ────────────► local_data_trigger ────► observe_event(local_data_trigger)         │
│                                                       ├──► comments_display_trigger            │
│                                                       └──► general_concepts_table_trigger      │
│                                                            (only if view == "list")            │
│                                                                                                 │
│  selected_categories() ───► selected_categories     observe_event(...)                         │
│                             _trigger ──────────────► └──► general_concepts_table_trigger       │
│                                                                                                 │
│  comments_tab() ──────────► comments_tab_trigger ──► observe_event(comments_tab_trigger)       │
│                                                       └──► comments_display_trigger            │
│                                                                                                 │
│  selected_mapped            mapped_concept           observe_event(mapped_concept_trigger)     │
│  _concept_id() ───────────► _trigger ──────────────► ├──► selected_mapping_details_trigger     │
│                                                       └──► relationship_tab_outputs_trigger    │
│                                                                                                 │
│  deleted_concepts() ──────► deleted_concepts        observe_event(...)                         │
│                             _trigger ──────────────► └──► concept_mappings_table_trigger       │
│                                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Composite Triggers → UI Observers

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│ COMPOSITE TRIGGERS → UI OBSERVERS                                                               │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                 │
│  breadcrumb_trigger ─────────────────► output$breadcrumb (renderUI)                            │
│                                                                                                 │
│  history_ui_trigger ─────────────────► output$general_concepts_history_ui (renderUI)           │
│                                        output$general_concept_detail_history_ui (renderUI)     │
│                                                                                                 │
│  general_concepts_table_trigger ─────► output$general_concepts_table (DT::renderDT)            │
│                                        + restores category filters after render                │
│                                                                                                 │
│  concept_mappings_table_trigger ─────► output$concept_mappings_table_view/edit (DT::renderDT)  │
│                                                                                                 │
│  comments_display_trigger ───────────► output$comments_display (renderUI)                      │
│                                                                                                 │
│  selected_mapping_details_trigger ───► output$selected_mapping_details (renderUI)              │
│                                                                                                 │
│  mapped_concepts_header_trigger ─────► output$mapped_concepts_header_buttons (renderUI)        │
│                                                                                                 │
│  relationship_tab_outputs_trigger ───► output$concept_relationships_display (renderUI)         │
│                                                                                                 │
│  history_tables_trigger ─────────────► output$general_concepts_history_table (DT::renderDT)    │
│                                        output$general_concept_detail_history_table (DT::renderDT)│
│                                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Direct Observers (User Interactions)

| Input | Action |
|-------|--------|
| input$view_concept_details | Sets selected_concept_id(), current_view("detail") |
| input$back_to_list | Sets current_view("list"), resets edit mode |
| input$category_filter | Toggles category in selected_categories() |
| input$general_concepts_edit_page | Sets general_concepts_edit_mode(TRUE) |
| input$general_concepts_cancel_edit | Restores original data, edit_mode(FALSE) |
| input$general_concepts_save_updates | Saves changes to CSV, edit_mode(FALSE) |
| input$general_concept_detail_edit_page | Sets general_concept_detail_edit_mode(TRUE) |
| input$general_concept_detail_cancel_edit | Resets temp changes, edit_mode(FALSE) |
| input$general_concept_detail_save_updates | Saves changes to CSV, edit_mode(FALSE) |
| input$switch_relationships_tab | Sets relationships_tab() |
| input$switch_comments_tab | Sets comments_tab() |
| input$delete_concept | Updates deleted_concepts() |
| input$mapped_concepts_add_selected | Updates added_concepts() |
| input$general_concepts_show_history | Sets current_view("list_history") |
| input$general_concept_detail_show_history | Sets current_view("detail_history") |
| input$back_to_list_from_history | Sets current_view("list") |
| input$back_to_detail | Sets current_view("detail") |

---

## Special Observers

| Reactive | Action |
|----------|--------|
| data() | Initializes local_data() on first load |
| current_user() | Updates button visibility (admin vs anonymous) |
| vocab_loading_status() | Shows/hides loading, error, or table |
| relationships_tab() | Updates tab styling (CSS classes) |
| current_view() | Manages container visibility, triggers view_trigger |

---

## Pattern Compliance

### ✅ Correct Patterns Found

- [x] Uses CASCADE PATTERN for reactivity management
- [x] Clear separation between state, triggers, and UI
- [x] Uses `observe_event()` function name

### ⚠️ Potential Issues / Areas for Review

| Issue | Severity | Description |
|-------|----------|-------------|
| history_tables_trigger | Medium | Uses `list()` syntax instead of cascade pattern: `observe_event(list(current_view(), history_tables_trigger))`. Could be refactored. |
| add_modal_* triggers | Low | `add_modal_selected_concept`, `add_modal_concept_details_trigger`, `add_modal_omop_table_trigger` are used for modal-specific updates but not fully integrated into the cascade pattern. |
| relationships_tab() observer | Low | Has a direct observer that updates CSS classes. Could potentially be merged with `relationship_tab_outputs_trigger` cascade. |
| update_button_visibility() | Low | Some observers call `update_button_visibility()` directly instead of through cascade. |

---

## Recommendations

1. **Refactor history_tables_trigger** to use full cascade pattern instead of `list()` syntax
2. **Integrate modal triggers** into the main cascade pattern
3. Consider **merging relationships_tab CSS updates** with the cascade pattern
4. **Document line numbers** when running full analysis with `/analyze-reactivity mod_dictionary_explorer`

---

## Cross-References

- **Module structure**: See `R/mod_dictionary_explorer.R` (MODULE STRUCTURE OVERVIEW comment, lines 1-51)
- **CSS classes used**: See `.claude/analysis/css-index.md`
- **Functions called**: See `.claude/analysis/codebase-index.md`
