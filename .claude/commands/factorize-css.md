# CSS Factorization Analysis

Analyze inline styles and CSS classes to improve stylesheet maintainability.

## Arguments

$ARGUMENTS

If no arguments provided, analyze all R files and `inst/www/style.css`.
If a file path is provided, focus the analysis on that specific file.

## Analysis Steps

### Phase 1: Extract inline styles

1. **Scan all R files** (`mod_*.R`, `app_ui.R`, `utils_ui.R`) for:
   - `style = "..."` attributes in tags
   - `tags$style()` inline definitions
   - `sprintf()` or `paste()` building style strings

2. **Parse each inline style** and extract:
   - CSS properties used
   - Values
   - Context (what element, what module)

### Phase 2: Identify patterns

1. **Group identical styles**:
   - Same property-value combinations
   - Flag occurrences >= 2 as candidates

2. **Group similar styles**:
   - Same properties, different values (candidates for CSS variables)
   - Related semantic purpose (e.g., all "error states")

3. **Categorize by type**:
   - Layout (display, flex, grid, position)
   - Spacing (margin, padding)
   - Typography (font, color, text)
   - Visual (background, border, shadow)
   - State (hover, active, disabled)

### Phase 3: Audit existing CSS

1. **Scan `inst/www/style.css`** for:
   - Defined classes
   - CSS custom properties (variables)
   - Media queries

2. **Cross-reference with R files**:
   - Find unused CSS classes
   - Find inline styles that duplicate existing classes
   - Find inconsistent usage (class exists but inline used)

### Phase 4: Generate recommendations

1. **New classes to create** (for repeated inline styles)
2. **CSS variables to add** (for repeated values like colors, spacing)
3. **Inline styles to replace** with existing classes
4. **Dead CSS to remove** (unused classes)

## Output Format

```markdown
## CSS Factorization Report

### 1. Inline Styles Inventory

| Style | Occurrences | Files | Suggested Class |
|-------|-------------|-------|-----------------|
| `display: flex; gap: 10px;` | 5 | mod_a, mod_b | `.flex-row-gap` |

### 2. Repeated Values (CSS Variables Candidates)

| Value | Property | Occurrences | Suggested Variable |
|-------|----------|-------------|-------------------|
| `#0f60af` | color, border-color | 12 | `--color-primary` |
| `10px` | padding, margin, gap | 8 | `--spacing-sm` |

### 3. New Classes to Create

```css
/* Layout utilities */
.flex-row {
  display: flex;
  flex-direction: row;
}

.flex-row-gap {
  display: flex;
  flex-direction: row;
  gap: var(--spacing-sm);
}

/* State styles */
.text-error {
  color: var(--color-danger);
  font-weight: 600;
}
```

### 4. Inline Styles to Replace

| File:Line | Current | Replace With |
|-----------|---------|--------------|
| mod_a.R:123 | `style = "display: flex;"` | `class = "flex-row"` |

### 5. Unused CSS Classes (Dead Code)

| Class | File | Lines |
|-------|------|-------|
| `.old-button` | style.css | 234-240 |

### 6. Inconsistent Usage

| Pattern | Class Exists | But Inline Used In |
|---------|--------------|-------------------|
| Error text styling | `.input-error-message` | mod_b.R:456 |
```

## Naming Conventions for New Classes

Follow these patterns for suggested class names:

- **Layout**: `.flex-row`, `.flex-col`, `.flex-center`, `.grid-2-col`
- **Spacing**: `.mt-sm`, `.p-md`, `.gap-lg` (using t/r/b/l/x/y prefixes)
- **Typography**: `.text-sm`, `.text-bold`, `.text-muted`
- **Colors**: `.text-primary`, `.bg-success`, `.border-danger`
- **State**: `.is-active`, `.is-disabled`, `.is-loading`
- **Components**: `.card`, `.badge`, `.chip`

## Instructions

- **Prioritize semantic naming** over visual naming (`.error-message` not `.red-text`)
- **Group related styles** into logical classes
- **Consider CSS specificity** when suggesting replacements
- **Preserve existing class names** - add new ones, don't rename
- **Use CSS variables** for colors, spacing, and repeated values
- **Update `.claude/analysis/css-index.md`** with findings

## CSS Index Location

The persistent index is maintained at: `.claude/analysis/css-index.md`

After analysis, update this file with:
- Inventory of existing CSS classes and their usage
- Inline style patterns identified
- Factorization progress
- Date of last analysis
