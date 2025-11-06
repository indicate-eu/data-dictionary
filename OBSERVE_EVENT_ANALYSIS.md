# Observe Event Analysis for mod_concept_mapping.R

## Summary Table

| Reactive Value | Count | Line Numbers | Purpose |
|---|---|---|---|
| `selected_alignment_id()` | 4 | 1933, 2502, 2773, 3346 | Render all mappings table (main); Render mapped concepts table (mapped view); Render source concepts table (general view); Render mapping evaluations table (evaluations) |
| `mappings_refresh_trigger()` | 3 | 2213, 2597, 3575 | Refresh all mappings table; Refresh mapped concepts table (mapped view); Refresh mapping evaluations table (evaluations) |
| `selected_general_concept_id()` | 3 | 2555, 2959, 524 | Render mapped concepts table (mapped view); Render concept mappings table (general view); Hide/show add mapping button |
| `summary_trigger()` | 2 | 1642, 1840 | Render alignment summary content (UI); Render use cases compatibility table |
| `data()` | 1 | 2916 | Render general concepts table (general view) |
| **Combined: `c(selected_alignment_id(), data(), mappings_refresh_trigger())`** | 1 | 406 | Cascade trigger: Updates `summary_trigger()` when alignment or data changes |
| **Combined: `c(mapping_view(), selected_general_concept_id(), input$source_concepts_table_rows_selected, input$concept_mappings_table_rows_selected)`** | 1 | 3124 | Control visibility of "Add Mapping from General" button |

---

## Detailed Observer Analysis

### 1. `selected_alignment_id()` - 4 occurrences

**Line 1933**: `all_mappings_table_main`
- Renders the main mappings table when an alignment is selected
- Loads CSV file, enrich with general concept and target concept data
- Shows "No alignment selected", "CSV file not found", or "No mappings created" messages

**Line 2502**: `source_concepts_table_mapped` 
- Renders source concepts table for the "Mapped" view
- Conditional visibility: only when `mapping_view() == "mapped"`
- Loads and displays source concepts from CSV

**Line 2773**: `source_concepts_table`
- Renders source concepts table for the "General" view
- Conditional visibility: only when `mapping_view() == "general"` AND `input$mapping_tabs == "edit_mappings"`
- Displays source concepts with status indicators

**Line 3346**: `mapping_evaluations_table`
- Renders mapping evaluations table for current user
- Queries SQLite database for evaluation status and comments
- Only visible to evaluators with database access

**Analysis**: These observers have DUPLICATE LOGIC. Each time `selected_alignment_id()` changes, all 4 observers fire independently, reading the same CSV file multiple times and performing similar data transformations.

---

### 2. `mappings_refresh_trigger()` - 3 occurrences

**Line 2213**: `all_mappings_table_main`
- Refreshes the main mappings table with updated data
- Identical logic to line 1933, but triggered by explicit refresh trigger
- Performs same CSV reading and data enrichment

**Line 2597**: `source_concepts_table_mapped`
- Refreshes source concepts table in mapped view
- Triggered when user saves/updates mappings
- Conditional on `mapping_view() == "mapped"`

**Line 3575**: `mapping_evaluations_table`
- Refreshes evaluations table with latest approval status
- Queries database for updated evaluation records
- Only for current evaluator user

**Analysis**: DUPLICATE LOGIC with `selected_alignment_id()` observers. The same CSV file is being read twice (lines 2213 and 2597) with similar filtering logic.

---

### 3. `selected_general_concept_id()` - 3 occurrences

**Line 524**: Button visibility control
- Shows/hides "Add Mapping from General" button
- Simple conditional: `if (!is.null(selected_general_concept_id()))` → hide button

**Line 2555**: `mapped_concepts_table`
- Renders mapped concepts for selected general concept in mapped view
- Joins with vocabulary data to get OMOP concept details
- Conditional: only when `mapping_view() == "mapped"`

**Line 2959**: `concept_mappings_table`
- Renders concept mappings for selected general concept in general view
- Joins with vocabulary data for enrichment
- Conditional: only when `input$mapping_tabs == "edit_mappings"`

**Analysis**: Line 524 is OVERLY SIMPLE - it's a button visibility toggle that could be handled with CSS show/hide instead of reactive observer. Lines 2555 and 2959 have similar logic for different views.

---

### 4. `summary_trigger()` - 2 occurrences

**Line 1642**: `summary_content`
- Renders alignment summary UI (name, description, file info, etc.)
- Creates HTML panels with alignment metadata
- Returns "No alignment selected" if no alignment

**Line 1840**: `use_cases_compatibility_table`
- Renders table showing which use cases are covered by mapped concepts
- Joins alignment mappings with use case assignments
- Shows compatibility matrix between alignment and use cases

**Analysis**: Two related but SEPARATE UI OUTPUTS triggered by same reactive value. Should likely be combined or use separate targeted triggers.

---

### 5. `data()` - 1 occurrence

**Line 2916**: `general_concepts_table`
- Renders general concepts table in general view
- Displays all available general concepts with category/subcategory
- Conditional: only when `mapping_view() == "general"` AND `input$mapping_tabs == "edit_mappings"`

**Analysis**: Only used once, low refactoring priority.

---

### 6. **Combined Observer 1** - `c(selected_alignment_id(), data(), mappings_refresh_trigger())`

**Line 406**: Cascade trigger
- Updates `summary_trigger()` when ANY of the three inputs change
- Acts as a gate: `if (null check) return()` else increment summary_trigger
- PURPOSE: Central coordination point for summary panel updates

**Analysis**: This is GOOD cascade pattern - centralizes the decision to refresh summary. However, it's watching 3 reactive values.

---

### 7. **Combined Observer 2** - `c(mapping_view(), selected_general_concept_id(), input$source_concepts_table_rows_selected, input$concept_mappings_table_rows_selected)`

**Line 3124**: Button visibility control
- Shows "Add Mapping from General" button only when:
  - User is in "general" view
  - A general concept is selected
  - Both a source concept AND a mapping are selected
- Conditions checked in order: view mode → concept selection → row selections

**Analysis**: This is a GOOD combined observer - it's legitimate to have multiple conditions for a single UI action.

---

## Recommendations for Cascade Pattern Refactoring

### HIGH PRIORITY - Significant Duplication

1. **Consolidate `selected_alignment_id()` observers (lines 1933, 2502, 2773, 3346)**
   
   **Current Problem**: 
   - All 4 observers read the same CSV file separately
   - Similar data transformation and filtering logic
   - Multiple database queries for the same data
   
   **Recommended Pattern**:
   ```r
   # Primary observer: Calculate alignment data once
   observe_event(selected_alignment_id(), {
     alignment_data_trigger(alignment_data_trigger() + 1)
   }, ignoreInit = TRUE)
   
   # Cascade: Coordinate specific table renders
   observe_event(alignment_data_trigger(), {
     all_mappings_table_trigger(all_mappings_table_trigger() + 1)
     source_concepts_table_mapped_trigger(source_concepts_table_mapped_trigger() + 1)
     source_concepts_table_trigger(source_concepts_table_trigger() + 1)
     mapping_evaluations_table_trigger(mapping_evaluations_table_trigger() + 1)
   }, ignoreInit = TRUE)
   
   # Individual observers respond to targeted triggers
   observe_event(all_mappings_table_trigger(), {
     # Render table
   }, ignoreInit = FALSE)
   ```
   
   **Benefits**:
   - CSV file read once, cached
   - Data transformations happen once, reused
   - Faster UI updates
   - Clearer separation of concerns

---

2. **Consolidate `mappings_refresh_trigger()` observers (lines 2213, 2597, 3575)**
   
   **Current Problem**:
   - Same refresh trigger fires 3 separate rendering pipelines
   - Lines 2213 and 2597 read the same CSV file
   
   **Recommended Pattern**:
   ```r
   # Primary observer: Coordinate all refresh operations
   observe_event(mappings_refresh_trigger(), {
     if (mappings_refresh_trigger() == 0) return()
     if (is.null(selected_alignment_id())) return()
     
     all_mappings_refresh_subtrigger(all_mappings_refresh_subtrigger() + 1)
     mapped_concepts_refresh_subtrigger(mapped_concepts_refresh_subtrigger() + 1)
     evaluations_refresh_subtrigger(evaluations_refresh_subtrigger() + 1)
   }, ignoreInit = TRUE)
   
   # Render observers respond to subtriggers
   observe_event(all_mappings_refresh_subtrigger(), { ... }, ignoreInit = FALSE)
   observe_event(mapped_concepts_refresh_subtrigger(), { ... }, ignoreInit = FALSE)
   observe_event(evaluations_refresh_subtrigger(), { ... }, ignoreInit = FALSE)
   ```
   
   **Benefits**:
   - Single point of control for refresh coordination
   - Each table refreshes independently
   - Easier to disable/enable specific refreshes

---

### MEDIUM PRIORITY - Minor Issues

3. **Simplify `selected_general_concept_id()` usage (lines 524, 2555, 2959)**
   
   **Current Problem**: 
   - Line 524 is a simple visibility toggle that could use CSS
   - Lines 2555 and 2959 have similar table rendering logic for different views
   
   **Recommended Improvement for line 524**:
   - Move button visibility to `observe_event(c(mapping_view(), selected_general_concept_id(), input$source_concepts_table_rows_selected, input$concept_mappings_table_rows_selected))`
   - Remove standalone observer at line 524
   - Consolidate into single UI control handler
   
   **For lines 2555 & 2959**:
   - Keep separate (they render different tables in different views)
   - Consider creating helper function to reduce code duplication

---

4. **Review `summary_trigger()` split responsibilities (lines 1642, 1840)**
   
   **Current Problem**:
   - One trigger fires two unrelated output updates
   - One output is UI content, one is data table
   - Could create different triggers for clarity
   
   **Recommended Improvement**:
   ```r
   # Keep summary_trigger for summary content
   observe_event(summary_trigger(), {
     # Just render summary_content
   }, ignoreInit = FALSE)
   
   # Create separate trigger for use cases table
   observe_event(c(selected_alignment_id(), summary_refresh_trigger()), {
     # Render use_cases_compatibility_table
   }, ignoreInit = TRUE)
   ```
   
   **Benefits**:
   - Clearer separation: content vs data
   - Can refresh use cases without re-rendering summary
   - Easier to debug which trigger updates which output

---

### LOW PRIORITY - Good Patterns

5. **Lines 406 & 3124 - KEEP AS IS**
   
   - Line 406: Excellent cascade pattern, central coordination
   - Line 3124: Legitimate multi-condition button visibility control
   - Both are well-structured and perform their intended purpose

---

## Summary of Issues

| Issue | Count | Total Observers | Severity |
|-------|-------|-----------------|----------|
| Duplicate CSV reading | 2 (2213, 2597) | 5 duplicate readers | HIGH |
| Duplicate data transformation | 3 (1933, 2502, 2773) | 3 similar transforms | HIGH |
| Multiple DB queries for same data | 2 (2213/2597, 3575) | 2 duplicate queries | HIGH |
| Unnecessary simple visibility toggle | 1 (524) | Could consolidate | MEDIUM |
| Split responsibility on trigger | 2 (1642, 1840) | One trigger, two purposes | MEDIUM |
| **TOTAL** | **39 observe_event calls** | **Multiple inefficiencies** | **REFACTOR** |

---

## Implementation Priority

1. **First**: Consolidate `selected_alignment_id()` → saves CSV reads and transforms
2. **Second**: Consolidate `mappings_refresh_trigger()` → eliminates duplicate refreshes  
3. **Third**: Simplify `selected_general_concept_id()` line 524 → minor cleanup
4. **Fourth**: Review `summary_trigger()` split → optional, clarifies intent

