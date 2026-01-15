# Dead Code Analysis

Find unused functions, variables, CSS classes, and translation keys in the codebase.

## Arguments

$ARGUMENTS

Options:
- No arguments: Full analysis of all code
- `r` or `R`: Only R code analysis
- `css`: Only CSS analysis
- `i18n`: Only translation keys analysis
- File path: Analyze specific file

## Analysis Steps

### Phase 1: R Code Analysis

#### 1.1 Unused Functions

1. **Scan all `fct_*.R` files** for function definitions:
   ```r
   function_name <- function(...) { }
   ```

2. **Search entire codebase** for each function call:
   - Direct calls: `function_name(...)`
   - Passed as argument: `lapply(x, function_name)`
   - Exported in NAMESPACE

3. **Flag functions** with zero references outside their definition file

#### 1.2 Unused Variables

1. **Within each function**, track:
   - Variable assignments
   - Variable usage
   - Flag assigned-but-never-used variables

2. **Module-level reactives**:
   - `reactiveVal()` definitions
   - Usage in observers and outputs
   - Flag unused reactives

#### 1.3 Unused Parameters

1. **Function parameters** that are never used in the function body
2. **Module parameters** passed but never referenced

### Phase 2: CSS Analysis

1. **Extract all CSS class definitions** from `inst/www/style.css`:
   ```css
   .class-name { ... }
   ```

2. **Search R files** for class usage:
   - `class = "class-name"`
   - `addClass("class-name")`
   - `removeClass("class-name")`
   - `toggleClass("class-name")`

3. **Search JS files** for class usage:
   - `.addClass("class-name")`
   - `.hasClass("class-name")`
   - `classList.add("class-name")`

4. **Flag classes** with zero references

### Phase 3: Translation Keys Analysis

1. **Extract all keys** from translation CSV files

2. **Search R files** for key usage:
   - `i18n$t("key")`
   - `i18n$translate("key")`

3. **Flag keys** with zero references

### Phase 4: JavaScript Analysis

1. **Extract function definitions** from JS files

2. **Search for usage**:
   - In other JS files
   - In R files (Shiny.setInputValue, onclick handlers)

3. **Flag unused functions**

## Output Format

```markdown
## Dead Code Analysis Report

### Summary

| Category | Items Checked | Unused | Percentage |
|----------|---------------|--------|------------|
| R Functions | 85 | 3 | 3.5% |
| R Variables | 240 | 12 | 5.0% |
| CSS Classes | 120 | 8 | 6.7% |
| Translation Keys | 150 | 5 | 3.3% |
| JS Functions | 25 | 2 | 8.0% |
| **Total** | **620** | **30** | **4.8%** |

### 1. Unused R Functions

| Function | File | Lines | Last Modified |
|----------|------|-------|---------------|
| `old_helper()` | fct_helpers.R | 45-60 | 2024-01-15 |
| `deprecated_calc()` | fct_stats.R | 120-145 | 2023-11-20 |

**Recommendation**: Review and remove if truly unused.

#### Safe to Remove
These functions have no references anywhere:
- `old_helper()` in fct_helpers.R

#### Needs Review
These might be called dynamically:
- `deprecated_calc()` - check if called via `do.call()`

### 2. Unused Variables

| Variable | File:Line | Type | Context |
|----------|-----------|------|---------|
| `temp_data` | mod_a.R:123 | Local | Assigned but never used |
| `unused_trigger` | mod_b.R:45 | reactiveVal | Defined but never fired |

### 3. Unused CSS Classes

| Class | File | Lines | Similar Active Class |
|-------|------|-------|---------------------|
| `.old-button` | style.css | 234-240 | `.btn-primary-custom` |
| `.legacy-panel` | style.css | 300-310 | `.card-container` |

**Recommendation**: Remove after confirming no dynamic usage.

### 4. Unused Translation Keys

| Key | EN Value | FR Value |
|-----|----------|----------|
| `old_feature_title` | "Old Feature" | "Ancienne fonctionnalite" |
| `deprecated_msg` | "This is deprecated" | "Ceci est obsolete" |

### 5. Unused JavaScript Functions

| Function | File | Lines |
|----------|------|-------|
| `oldHandler()` | legacy.js | 50-75 |

### 6. Potential False Positives

These items might appear unused but could be:
- Called dynamically via strings
- Used in external code
- Reserved for future use

| Item | Type | Reason for Caution |
|------|------|--------------------|
| `get_*` functions | R | Might be called via `do.call()` |
| `.js-*` classes | CSS | Might be added by JavaScript |

### Cleanup Commands

To remove dead code safely:

1. **Create backup branch**: `git checkout -b cleanup/dead-code`
2. **Remove items one category at a time**
3. **Run tests after each removal**
4. **Commit with clear messages**

### Estimated Impact

- **Lines to remove**: ~150
- **Files affected**: 12
- **Reduction in bundle size**: ~2%
```

## Instructions

- **Be conservative** - flag as "needs review" if uncertain
- **Check for dynamic usage**:
  - `do.call("function_name", ...)`
  - `get("function_name")`
  - String interpolation in JS
- **Consider entry points**:
  - Exported functions in NAMESPACE
  - Functions called from external packages
- **Document confidence level** for each finding
- **Suggest safe removal order** (dependencies)

## False Positive Patterns

Be careful with:

1. **R Functions**:
   - S3/S4 methods
   - Functions passed as callbacks
   - Functions called via `match.fun()`

2. **CSS Classes**:
   - Classes added by JavaScript
   - Classes from external libraries (DT, shiny)
   - Conditional classes

3. **Translation Keys**:
   - Keys constructed dynamically: `i18n$t(paste0("prefix_", var))`

4. **Variables**:
   - Used in non-standard evaluation
   - Part of `...` arguments
