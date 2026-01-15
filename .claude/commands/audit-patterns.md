# Shiny Patterns Audit

Audit the codebase for compliance with the Shiny patterns defined in CLAUDE.md.

## Arguments

$ARGUMENTS

If no arguments provided, audit all `mod_*.R` files.
If a file path is provided, focus the analysis on that specific file.

## Patterns to Check

Based on the CLAUDE.md guidelines, verify compliance with these rules:

### 1. Observer Usage

| Rule | Correct | Incorrect |
|------|---------|-----------|
| Function name | `observe_event()` | `observeEvent()`, `observe()` |
| No try-catch | Direct code | `tryCatch()` inside observer |
| No shiny:: prefix | `observe_event()` | `shiny::observeEvent()` |
| No nesting | Separate observers | Observer inside observer |

### 2. Output Rendering

| Rule | Correct | Incorrect |
|------|---------|-----------|
| Wrap in observer | `observe_event(...) { output$x <- ... }` | `output$x <- renderDT(...)` direct |

### 3. Validation

| Rule | Correct | Incorrect |
|------|---------|-----------|
| Pattern | `if (is.null(x)) return()` | `req(x)` |

### 4. UI Location

| Rule | Correct | Incorrect |
|------|---------|-----------|
| Static UI | In `mod_*_ui()` function | In `renderUI()` |
| Dynamic visibility | `shinyjs::show()/hide()` | Re-render entire UI |

### 5. Cascade Reactivity

| Rule | Correct | Incorrect |
|------|---------|-----------|
| Multiple triggers | Cascade pattern | `observe_event(list(a(), b(), c()))` |
| State propagation | trigger -> cascade -> composite | Direct multi-observer |

## Analysis Steps

### Phase 1: Pattern detection

For each `mod_*.R` file, scan for:

1. **Observer patterns**:
   ```r
   # INCORRECT patterns to flag:
   observeEvent(          # Wrong function name
   shiny::observe         # Package prefix
   observe({              # Simple observe
   observe_event(..., {
     observe_event(       # Nested observer
   observe_event(..., {
     tryCatch(            # Try-catch inside
   ```

2. **Output patterns**:
   ```r
   # INCORRECT - direct output assignment:
   output$table <- DT::renderDT(...)

   # CORRECT - wrapped in observer:
   observe_event(trigger(), {
     output$table <- DT::renderDT(...)
   })
   ```

3. **Validation patterns**:
   ```r
   # INCORRECT:
   req(input$value)

   # CORRECT:
   if (is.null(input$value)) return()
   ```

4. **UI patterns**:
   ```r
   # Flag uiOutput/renderUI for review:
   uiOutput(ns("something"))
   output$something <- renderUI(...)
   ```

5. **Multi-trigger patterns**:
   ```r
   # INCORRECT - multiple triggers in list:
   observe_event(list(a(), b(), c()), ...)
   observe_event(c(a(), b()), ...)
   ```

### Phase 2: Severity classification

- **Error**: Clear violation that must be fixed
- **Warning**: Potential issue, needs review
- **Info**: Suggestion for improvement

## Output Format

```markdown
## Shiny Patterns Audit Report

### Summary

| Category | Errors | Warnings | Info |
|----------|--------|----------|------|
| Observer usage | 3 | 2 | 0 |
| Output rendering | 5 | 0 | 1 |
| Validation | 8 | 0 | 0 |
| UI location | 0 | 4 | 2 |
| Cascade reactivity | 2 | 1 | 0 |
| **Total** | **18** | **7** | **3** |

### Detailed Findings

#### 1. Observer Usage

##### Errors

| File:Line | Issue | Current | Should Be |
|-----------|-------|---------|-----------|
| mod_a.R:123 | Wrong function | `observeEvent(...)` | `observe_event(...)` |
| mod_b.R:456 | Nested observer | `observe_event({ observe_event(...) })` | Separate observers |

##### Warnings

| File:Line | Issue | Recommendation |
|-----------|-------|----------------|
| mod_c.R:789 | try-catch inside | Remove, errors are auto-logged |

#### 2. Output Rendering

##### Errors

| File:Line | Issue | Current |
|-----------|-------|---------|
| mod_a.R:200 | Direct output | `output$table <- DT::renderDT(data())` |

**Fix**: Wrap in observer with appropriate trigger

#### 3. Validation

##### Errors

| File:Line | Current | Should Be |
|-----------|---------|-----------|
| mod_a.R:150 | `req(input$x)` | `if (is.null(input$x)) return()` |

#### 4. UI Location

##### Warnings (Review Needed)

| File:Line | Element | Recommendation |
|-----------|---------|----------------|
| mod_a.R:50 | `uiOutput(ns("buttons"))` | Move to UI if static |

#### 5. Cascade Reactivity

##### Errors

| File:Line | Issue | Current |
|-----------|-------|---------|
| mod_a.R:300 | Multi-trigger | `observe_event(list(a(), b()), ...)` |

**Fix**: Use cascade pattern with intermediate triggers

### Recommendations by Priority

#### High Priority (Errors)
1. Fix observer function names (3 occurrences)
2. Wrap direct outputs in observers (5 occurrences)
3. Replace `req()` with `if/return` (8 occurrences)

#### Medium Priority (Warnings)
1. Review renderUI usage for static content (4 occurrences)
2. Remove unnecessary try-catch blocks (2 occurrences)

#### Low Priority (Info)
1. Consider cascade pattern for multi-trigger observers
```

## Instructions

- **Be strict** on error-level violations
- **Provide context** for each finding
- **Suggest fixes** with code examples
- **Group by file** for easier batch fixing
- **Reference CLAUDE.md** section for each rule
- Run this audit **before committing** major changes

## Quick Fix Commands

After running the audit, you can ask for automated fixes:

- `/audit-patterns fix observers` - Fix observer function names
- `/audit-patterns fix validation` - Replace req() with if/return
- `/audit-patterns fix outputs` - Wrap outputs in observers (manual review needed)
