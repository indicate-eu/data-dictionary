# CSS Index

This file tracks CSS classes, inline styles, and factorization candidates.

**Last updated**: 2026-01-15
**Analysis summary**: 847 inline style occurrences across 17 R module files

---

## 1. CSS Classes Inventory (`style.css`)

### Button Classes

| Class | Used In | Occurrences |
|-------|---------|-------------|
| `.btn-primary-custom` | mod_dictionary_explorer, mod_concept_mapping, mod_users | 18 |
| `.btn-success-custom` | mod_dictionary_explorer, mod_concept_mapping | 11 |
| `.btn-secondary-custom` | mod_dictionary_explorer, mod_projects | 9 |
| `.btn-danger-custom` | mod_users, mod_dictionary_settings | 3 |
| `.btn-toggle` | mod_dictionary_explorer | 4 |
| `.btn-cancel` | *UNUSED - should replace inline cancel button styles* | 0 |
| `.btn-action` | *UNUSED - consolidate with .dt-action-btn* | 0 |
| `.btn-icon-only` | *May be generated dynamically* | ~0 |

### Layout Classes

| Class | Properties | Used In | Occurrences |
|-------|------------|---------|-------------|
| `.main-panel` | Flex layout, padding | Multiple modules | 10+ |
| `.card-container` | White box, shadow, rounded corners | Multiple modules | 15+ |
| `.card-container-flex` | Card with flex: 1 | Multiple modules | 8+ |
| `.table-container` | Table styling | Multiple modules | 12+ |
| `.quadrant-layout` | 4-panel grid | mod_dictionary_explorer | 2 |
| `.modal-overlay` | Full-screen modal backdrop | Multiple modules | 8+ |
| `.modal-content` | Modal dialog container | Multiple modules | 8+ |

### Typography Classes

| Class | Properties | Used In | Occurrences |
|-------|------------|---------|-------------|
| `.section-title` | 18px, weight 600, blue | Multiple modules | 10+ |
| `.breadcrumb-link` | Clickable navigation | mod_dictionary_explorer, mod_projects | 5 |
| `.bold-value` | *UNUSED* | N/A | 0 |
| `.true-value` | Green bold text | *UNUSED - should replace `color: #28a745`* | 0 |
| `.false-value` | Red bold text | *UNUSED - should replace `color: #dc3545`* | 0 |

### Badge/Status Classes

| Class | Used In | Occurrences |
|-------|---------|-------------|
| `.category-badge` | mod_dictionary_explorer | 5+ |
| `.badge-status` | *UNUSED* | 0 |
| `.badge-success` | *UNUSED* | 0 |
| `.badge-danger` | *UNUSED* | 0 |
| `.badge-secondary` | *UNUSED* | 0 |

---

## 2. Inline Styles Inventory

### Repeated Patterns (High Priority - Create Classes)

| Style | Occurrences | Files | Suggested Class |
|-------|-------------|-------|-----------------|
| `display: none;` | 32 | Multiple modules | `.hidden` |
| `font-weight: 600; color: #666;` | 24 | mod_dictionary_settings, mod_projects, mod_users | `.label-text` |
| `margin-bottom: 20px;` | 23 | Multiple modules | `.mb-20` |
| `display: block; font-weight: 600; margin-bottom: 8px;` | 22 | mod_users, mod_projects, mod_dictionary_settings | `.form-label` |
| `color: #999; font-style: italic;` | 20 | Multiple modules | `.text-muted-italic` |
| `margin-bottom: 6px;` | 18 | Multiple modules | `.mb-6` |
| `display: flex; align-items: center; gap: 8px;` | 14 | Multiple modules | `.flex-center-gap-8` |
| `margin-right: 6px;` | 13 | Multiple modules | `.mr-6` |
| `flex: 1;` | 13 | Multiple modules | `.flex-1` |
| `display: flex; align-items: center; gap: 10px;` | 13 | Multiple modules | `.flex-center-gap-10` |
| `flex: 1; min-width: 150px;` | 12 | mod_dictionary_settings | `.flex-input-field` |
| `flex: 1; min-height: 0; overflow: auto;` | 11 | Multiple modules | `.flex-scroll-container` |
| `display: flex; gap: 10px;` | 10 | Multiple modules | `.flex-gap-10` |
| `color: #dc3545;` | 10 | Multiple modules | `.text-danger` (or use `.false-value`) |
| `height: 100%; display: flex; flex-direction: column;` | 9 | Multiple modules | `.flex-column-full` |

### Medium Priority Patterns

| Style | Occurrences | Suggested Class |
|-------|-------------|-----------------|
| `padding: 20px;` | 64 | `.p-20` |
| `gap: 10px;` | 57 | Part of flex utilities |
| `padding: 10px;` | 47 | `.p-10` |
| `padding: 15px;` | 40 | `.p-15` |
| `color: #666;` | 102 | `.text-secondary` |
| `border-radius: 4px;` | 93 | Use `--border-radius-sm` |

---

## 3. CSS Variables

### Existing Variables

Currently no CSS variables defined in `style.css`.

### Recommended Variables to Add

```css
:root {
  /* Colors - Text */
  --color-text-primary: #333;
  --color-text-secondary: #666;
  --color-text-muted: #999;
  --color-text-dark: #2c3e50;

  /* Colors - Brand */
  --color-primary: #0f60af;
  --color-success: #28a745;
  --color-danger: #dc3545;
  --color-warning: #ffc107;
  --color-secondary: #6c757d;
  --color-info: #17a2b8;

  /* Colors - Background */
  --bg-light-gray: #f8f9fa;
  --bg-white: #ffffff;
  --bg-danger-light: #f8d7da;
  --bg-success-light: #d4edda;
  --bg-warning-light: #fff3cd;
  --bg-primary-light: #f0f7ff;

  /* Spacing */
  --spacing-5: 5px;
  --spacing-6: 6px;
  --spacing-8: 8px;
  --spacing-10: 10px;
  --spacing-12: 12px;
  --spacing-15: 15px;
  --spacing-20: 20px;
  --spacing-40: 40px;

  /* Gap */
  --gap-small: 8px;
  --gap-default: 10px;
  --gap-medium: 15px;
  --gap-large: 20px;

  /* Border Radius */
  --border-radius-sm: 4px;
  --border-radius-default: 6px;
  --border-radius-md: 8px;
  --border-radius-lg: 20px;

  /* Font Sizes */
  --font-size-xs: 11px;
  --font-size-sm: 12px;
  --font-size-default: 13px;
  --font-size-md: 14px;
  --font-size-lg: 16px;
  --font-size-xl: 18px;
}
```

---

## 4. Unused CSS Classes

| Class | File | Recommendation |
|-------|------|----------------|
| `.badge-status` | style.css | Remove or document for future use |
| `.badge-success` | style.css | Should be used for status indicators |
| `.badge-danger` | style.css | Should be used for error states |
| `.badge-secondary` | style.css | Should be used for neutral states |
| `.bold-value` | style.css | Remove or replace inline `font-weight: bold` |
| `.check-icon` | style.css | Remove or use for checkmarks |
| `.true-value` | style.css | Should replace `color: #28a745` inline styles |
| `.false-value` | style.css | Should replace `color: #dc3545` inline styles (10+ uses!) |
| `.btn-action` | style.css | Consolidate with `.dt-action-btn` |
| `.btn-action-test` | style.css | Remove or consolidate |
| `.btn-action-delete` | style.css | Remove or consolidate |
| `.btn-cancel` | style.css | Should replace inline cancel button styles |
| `.has-tooltip` | style.css | Remove or implement tooltips consistently |

---

## 5. Inconsistent Usage

| Pattern | Class Exists | But Inline Used In |
|---------|--------------|-------------------|
| Error text (red `#dc3545`) | `.false-value` | 10+ files with `style="color: #dc3545;"` |
| Success text (green `#28a745`) | `.true-value` | Multiple files with `style="color: #28a745;"` |
| Cancel buttons | `.btn-cancel` | Multiple files with inline cancel button styles |
| Primary buttons | `.btn-primary-custom` | Some buttons still use inline `background: #0f60af` |
| Error messages | `.input-error-message` | Inconsistent validation message styling |

---

## 6. Recommended New Classes

### High Priority Utility Classes

```css
/* Display & Visibility */
.hidden { display: none; }
.flex-center { display: flex; align-items: center; }
.flex-center-gap-8 { display: flex; align-items: center; gap: 8px; }
.flex-center-gap-10 { display: flex; align-items: center; gap: 10px; }
.flex-gap-10 { display: flex; gap: 10px; }
.flex-column { display: flex; flex-direction: column; }
.flex-column-full { height: 100%; display: flex; flex-direction: column; }
.flex-1 { flex: 1; }
.flex-scroll-container { flex: 1; min-height: 0; overflow: auto; }

/* Spacing Utilities */
.mb-6 { margin-bottom: 6px; }
.mb-8 { margin-bottom: 8px; }
.mb-10 { margin-bottom: 10px; }
.mb-15 { margin-bottom: 15px; }
.mb-20 { margin-bottom: 20px; }
.mr-6 { margin-right: 6px; }
.mr-10 { margin-right: 10px; }
.mt-10 { margin-top: 10px; }
.p-10 { padding: 10px; }
.p-15 { padding: 15px; }
.p-20 { padding: 20px; }
.p-15-20 { padding: 15px 20px; }

/* Text Utilities */
.text-muted-italic { color: #999; font-style: italic; }
.text-secondary { color: #666; }
.text-danger { color: #dc3545; }
.text-success { color: #28a745; }
.font-weight-600 { font-weight: 600; }
.text-center { text-align: center; }

/* Form Elements */
.form-label {
  display: block;
  font-weight: 600;
  margin-bottom: 8px;
  color: #2c3e50;
  font-size: 14px;
}
.label-text { font-weight: 600; color: #666; }
.flex-input-field { flex: 1; min-width: 150px; }
```

---

## 7. File-by-File Analysis

| File | Inline Styles | Top Issues | Priority |
|------|---------------|-----------|----------|
| mod_dictionary_settings.R | 150+ | Heavy flex layouts, repeated spacing, color inconsistency | HIGH |
| mod_dictionary_explorer.R | 120+ | Modal styling, flex layouts, quadrant layout duplication | HIGH |
| mod_concept_mapping.R | 100+ | Complex flex patterns, modal styling, form layouts | HIGH |
| mod_users.R | 80+ | Form labels (22 duplicates), modal styling | MEDIUM |
| mod_projects.R | 70+ | Form layouts, modal styling, display:none | MEDIUM |
| mod_page_header.R | 50+ | Dropdown menu items (4 duplicates), user button styling | MEDIUM |
| mod_login.R | 30+ | Form styling, centered layouts | LOW |
| mod_general_settings.R | 40+ | Settings-specific layouts | LOW |
| Others | ~150 | Mixed patterns | LOW |

---

## 8. Factorization Progress

| Date | Action | Classes Added | Inlines Replaced |
|------|--------|---------------|------------------|
| 2026-01-15 | Initial analysis completed | 0 | 0 |
| 2026-01-15 | Added CSS variables to :root | 35 variables | 0 |
| 2026-01-15 | Added utility classes | 45+ classes | 0 |
| 2026-01-15 | Replaced `display: none;` with `.hidden` | 0 | 32 occurrences |
| 2026-01-15 | Replaced common patterns (mb-20, form-label, flex-*, text-*, p-*, etc.) | 0 | ~150 occurrences |

### Current Status (after factorization)

**Total inline styles remaining**: ~794 (down from 847+)
| File | Count |
|------|-------|
| mod_concept_mapping.R | 346 |
| mod_dictionary_explorer.R | 179 |
| mod_general_settings.R | 85 |
| mod_dictionary_settings.R | 71 |
| Other modules | ~113 |

**Note**: Many remaining inline styles are complex/unique and would require dedicated classes. Consider creating component-specific classes for modals, panels, and grids in future iterations.

---

## Implementation Priority

### Phase 1: Foundation ✅ COMPLETED
1. Add CSS variables to `:root` in `style.css`
2. Create top 15 utility classes (display, flex, spacing)
3. Create `.hidden` class and replace 32 `display: none;` occurrences

### Phase 2: High-Value Replacements ✅ COMPLETED
4. Replace form labels with `.form-label`
5. Replace text colors with utility classes
6. Replace spacing with `.mb-*`, `.p-*`, `.mr-*` classes

### Phase 3: Layout Consolidation (Future)
7. Create flex layout utilities
8. Standardize modal layouts
9. Remove unused CSS classes

---

## Notes

- **Total inline styles identified**: 847 across 17 R files
- **Estimated reduction possible**: 60-70% (500-600 inline styles)
- **Key insight**: Color `#666` appears 102 times inline - create `.text-secondary`
- **Quick win**: `.hidden` class would replace 32 `display: none;` occurrences
- Cross-reference with `/dead-code css` for detailed unused class analysis
