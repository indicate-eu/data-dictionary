# Full Codebase Audit

Run all audit and analysis commands to get a complete picture of the codebase health.

## Arguments

$ARGUMENTS

Options:
- No arguments: Run all audits
- `quick`: Skip detailed analysis, summary only
- `fix`: Include automated fix suggestions

## Audits to Run

Execute these commands in sequence:

### 1. Code Factorization (`/factorize`)
- Inventory all `fct_*.R` functions
- Identify redundant code patterns
- Update `codebase-index.md`

### 2. CSS Factorization (`/factorize-css`)
- Inventory inline styles
- Identify CSS class candidates
- Update `css-index.md`

### 3. i18n Audit (`/audit-i18n`)
- Check translation coverage
- Find hard-coded strings
- Update `i18n-index.md`

### 4. Shiny Patterns Audit (`/audit-patterns`)
- Verify observer patterns
- Check cascade reactivity
- Validate UI patterns

### 5. Dead Code Analysis (`/dead-code`)
- Find unused R functions
- Find unused CSS classes
- Find unused translation keys

### 6. Accessibility Audit (`/audit-accessibility`)
- Check semantic HTML
- Verify ARIA attributes
- Check keyboard navigation

## Execution Instructions

Run each audit sequentially and compile results into a unified report.

For each audit:
1. Execute the audit command
2. Capture key findings
3. Note critical issues
4. Track in the summary

## Output Format

Generate a unified report:

```markdown
# Full Codebase Audit Report

**Date**: [Current date]
**Branch**: [Current branch]
**Commit**: [Current commit hash]

---

## Executive Summary

| Audit | Critical | High | Medium | Low | Status |
|-------|----------|------|--------|-----|--------|
| Code Factorization | 0 | 2 | 5 | 3 | Needs attention |
| CSS Factorization | 0 | 1 | 8 | 2 | OK |
| i18n | 0 | 0 | 3 | 5 | OK |
| Shiny Patterns | 3 | 5 | 2 | 0 | Critical |
| Dead Code | 0 | 0 | 4 | 8 | OK |
| Accessibility | 1 | 3 | 4 | 2 | Needs attention |
| **Total** | **4** | **11** | **26** | **20** | - |

### Overall Health Score: 7.5/10

---

## Critical Issues (Must Fix)

1. **[Audit name]**: [Issue description]
   - File: [file:line]
   - Impact: [description]
   - Fix: [suggested fix]

---

## High Priority Issues

### Code Factorization
- [List of high priority items]

### Shiny Patterns
- [List of high priority items]

### Accessibility
- [List of high priority items]

---

## Detailed Reports

### 1. Code Factorization
[Summary of /factorize results]

### 2. CSS Factorization
[Summary of /factorize-css results]

### 3. i18n Audit
[Summary of /audit-i18n results]

### 4. Shiny Patterns
[Summary of /audit-patterns results]

### 5. Dead Code
[Summary of /dead-code results]

### 6. Accessibility
[Summary of /audit-accessibility results]

---

## Recommended Action Plan

### Immediate (This Sprint)
1. Fix critical Shiny patterns violations
2. Address accessibility critical issues

### Short-term (Next Sprint)
1. Refactor identified redundant code
2. Replace inline styles with CSS classes
3. Add missing translations

### Long-term (Backlog)
1. Remove dead code
2. Improve test coverage
3. Document complex modules

---

## Index Files Updated

- [x] `.claude/analysis/codebase-index.md`
- [x] `.claude/analysis/css-index.md`
- [x] `.claude/analysis/i18n-index.md`
```

## Quick Mode

If `quick` argument is provided:
- Skip detailed file-by-file analysis
- Only report counts and critical issues
- Faster execution for CI/CD

## Fix Mode

If `fix` argument is provided:
- Include automated fix commands where possible
- Generate a fix script for batch operations
- Prioritize by impact and safety

## Notes

- Run this audit before major releases
- Compare results with previous audits to track progress
- Address critical issues before merging to main
- Update index files after fixing issues
