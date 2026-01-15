# Code Factorization Analysis

Analyze the codebase to identify redundant code patterns and suggest factorization opportunities.

## Arguments

$ARGUMENTS

If no arguments provided, analyze all `mod_*.R` and `fct_*.R` files.
If a file path is provided, focus the analysis on that specific file.

## Analysis Steps

### Phase 1: Inventory existing functions

1. **Scan all `fct_*.R` files** and list:
   - Function name
   - File location
   - Brief description (from roxygen or inferred)
   - Parameters

2. **Update the codebase index** at `.claude/analysis/codebase-index.md`

### Phase 2: Identify redundant code in modules

1. **Scan all `mod_*.R` files** for:
   - **Repeated code blocks** (same logic in multiple places)
   - **Inline functions** that could be extracted to `fct_*.R`
   - **Similar reactive patterns** that could be standardized
   - **Copy-pasted DataTable configurations**
   - **Repeated UI construction patterns**

2. **Flag patterns appearing 2+ times** as candidates for factorization

### Phase 3: Cross-reference usage

1. **For each `fct_*.R` function**, identify:
   - Which modules use it
   - How many times it's called
   - Any unused functions (dead code)

2. **Identify missing utility functions** that should exist based on repeated patterns

## Output Format

Generate a report with the following structure:

```markdown
## Factorization Analysis Report

### 1. Existing Functions Inventory

| Function | File | Used in | Times |
|----------|------|---------|-------|
| function_name | fct_*.R | mod_a, mod_b | 5 |

### 2. Redundant Code Identified

#### Pattern: [Description]
- **Found in**: mod_a.R:123, mod_b.R:456
- **Occurrences**: 3
- **Suggested function**: `function_name(params)`
- **Target file**: fct_*.R

```r
# Suggested implementation
function_name <- function(param1, param2) {
  # Extracted code here
}
```

### 3. Unused Functions (Dead Code)

| Function | File | Last used |
|----------|------|-----------|
| old_function | fct_old.R | Never |

### 4. Recommendations Summary

1. **High priority**: [Description]
2. **Medium priority**: [Description]
3. **Low priority**: [Description]
```

## Instructions

- Focus on **practical factorization** that improves maintainability
- Prefer extracting to **existing `fct_*.R` files** when thematically appropriate
- Suggest **new `fct_*.R` files** only when a clear theme emerges
- Consider **backward compatibility** - don't break existing calls
- Prioritize by **frequency of duplication** and **complexity**
- Update `.claude/analysis/codebase-index.md` with findings

## Codebase Index Location

The persistent index is maintained at: `.claude/analysis/codebase-index.md`

After analysis, update this file with:
- New functions discovered
- Usage statistics
- Factorization candidates
- Date of last analysis
