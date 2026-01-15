# R Code Linting

Run the `lintr` package to check R code for style and potential issues.

## Arguments

$ARGUMENTS

Options:
- No arguments: Lint all R files in the `R/` directory
- File path: Lint a specific file (e.g., `R/mod_dictionary_explorer.R`)
- `fix`: Show suggestions for auto-fixable issues

## Execution

Run the appropriate lintr command based on arguments:

### Lint entire package
```r
Rscript -e "lintr::lint_package()"
```

### Lint specific file
```r
Rscript -e "lintr::lint('R/mod_example.R')"
```

### Lint with custom configuration
The project uses `.lintr` configuration file if present. If not, use these defaults aligned with CLAUDE.md:

```r
Rscript -e "
lintr::lint_package(
  linters = lintr::linters_with_defaults(
    line_length_linter = lintr::line_length_linter(120),
    object_name_linter = lintr::object_name_linter(styles = 'snake_case'),
    commented_code_linter = NULL,  # Allow commented code (we have structure comments)
    cyclocomp_linter = lintr::cyclocomp_linter(complexity_limit = 25)
  )
)
"
```

## Output Interpretation

Lintr reports issues with severity levels:

| Type | Description | Action |
|------|-------------|--------|
| `error` | Syntax errors, critical issues | Must fix |
| `warning` | Style violations, potential bugs | Should fix |
| `style` | Code style suggestions | Consider fixing |

## Common Issues and Fixes

### 1. Line Length (> 120 characters)
```r
# Before
very_long_function_call(parameter_one = value_one, parameter_two = value_two, parameter_three = value_three)

# After
very_long_function_call(
  parameter_one = value_one,
  parameter_two = value_two,
  parameter_three = value_three
)
```

### 2. Object Naming (should be snake_case)
```r
# Before
myVariable <- 1
getData <- function() {}

# After
my_variable <- 1
get_data <- function() {}
```

### 3. Trailing Whitespace
Remove spaces at end of lines.

### 4. Assignment Operator
```r
# Before
x = 1

# After
x <- 1
```

### 5. Spacing Around Operators
```r
# Before
x<-1+2

# After
x <- 1 + 2
```

### 6. Unused Variables
Remove or use variables that are assigned but never referenced.

### 7. Missing Function Documentation
Add roxygen2 comments for exported functions.

## Integration with Project Patterns

### Shiny-specific Allowances

These patterns are acceptable in our Shiny codebase (don't flag as errors):

1. **Reactive expressions** - `reactive({})` blocks
2. **Observer patterns** - `observe_event()` with complex bodies
3. **UI construction** - Long `tagList()` and `tags$div()` chains
4. **Module namespacing** - `ns()` function calls

### CLAUDE.md Compliance

After linting, also check:
- [ ] Uses `observe_event()` not `observeEvent()`
- [ ] No `shiny::` prefixes
- [ ] No nested observers
- [ ] Validation uses `if/return` not `req()`

Run `/audit-patterns` for full Shiny patterns compliance.

## Report Format

```markdown
## Lint Report

**File(s)**: [file list]
**Date**: [date]
**Total issues**: [count]

### Summary

| Severity | Count |
|----------|-------|
| Error | 0 |
| Warning | 5 |
| Style | 12 |

### Issues by File

#### R/mod_example.R

| Line | Type | Linter | Message |
|------|------|--------|---------|
| 45 | warning | line_length | Line exceeds 120 characters |
| 78 | style | trailing_whitespace | Remove trailing whitespace |

### Recommendations

1. **High priority**: Fix errors and warnings
2. **Medium priority**: Address style issues in new/modified code
3. **Low priority**: Gradually clean up legacy code
```

## Quick Commands

```bash
# Lint entire package
Rscript -e "lintr::lint_package()"

# Lint single file
Rscript -e "lintr::lint('R/mod_dictionary_explorer.R')"

# Lint and output to file
Rscript -e "writeLines(capture.output(lintr::lint_package()), 'lint_report.txt')"

# Check if lintr is installed
Rscript -e "if (!require('lintr')) install.packages('lintr')"
```

## Configuration File

If `.lintr` doesn't exist, consider creating one:

```yaml
linters:
  line_length_linter:
    length: 120
  object_name_linter:
    styles: snake_case
  cyclocomp_linter:
    complexity_limit: 25
exclusions:
  - "inst/*"
  - "man/*"
  - "tests/testthat/test-*.R"
```

## Notes

- Run before committing significant changes
- Focus on new/modified code first
- Don't try to fix everything at once in legacy code
- Combine with `/audit-patterns` for full code quality check
