# CSS Index

This file tracks CSS classes, inline styles, and factorization candidates.

**Last updated**: Not yet analyzed
**Run `/factorize-css` to update this index**

---

## 1. CSS Classes Inventory (`style.css`)

### Layout Classes

| Class | Properties | Used In | Occurrences |
|-------|------------|---------|-------------|
| *Run /factorize-css to populate* | | | |

### Typography Classes

| Class | Properties | Used In | Occurrences |
|-------|------------|---------|-------------|
| *Run /factorize-css to populate* | | | |

### Button Classes

| Class | Properties | Used In | Occurrences |
|-------|------------|---------|-------------|
| *Run /factorize-css to populate* | | | |

### Component Classes

| Class | Properties | Used In | Occurrences |
|-------|------------|---------|-------------|
| *Run /factorize-css to populate* | | | |

### Utility Classes

| Class | Properties | Used In | Occurrences |
|-------|------------|---------|-------------|
| *Run /factorize-css to populate* | | | |

---

## 2. Inline Styles Inventory

### Repeated Patterns (Candidates for Classes)

| Style | Occurrences | Files | Suggested Class |
|-------|-------------|-------|-----------------|
| *Run /factorize-css to populate* | | | |

### One-off Styles (Keep Inline)

| Style | File:Line | Context |
|-------|-----------|---------|
| *Run /factorize-css to populate* | | |

---

## 3. CSS Variables

### Existing Variables

| Variable | Value | Usage |
|----------|-------|-------|
| *Run /factorize-css to populate* | | |

### Suggested Variables

| Value | Occurrences | Suggested Variable |
|-------|-------------|-------------------|
| *Run /factorize-css to populate* | | |

---

## 4. Unused CSS Classes

| Class | File | Lines | Recommendation |
|-------|------|-------|----------------|
| *Run /factorize-css or /dead-code css to identify* | | | |

---

## 5. Inconsistent Usage

| Pattern | Class Exists | But Inline Used In |
|---------|--------------|-------------------|
| *Run /factorize-css to identify* | | |

---

## 6. Factorization Progress

| Date | Action | Classes Added | Inlines Replaced |
|------|--------|---------------|------------------|
| *None yet* | | | |

---

## CSS Architecture Notes

### Naming Conventions

- **Layout**: `.flex-*`, `.grid-*`, `.container-*`
- **Spacing**: `.m-*`, `.p-*`, `.gap-*` (margin, padding, gap)
- **Typography**: `.text-*`, `.font-*`
- **Colors**: `.bg-*`, `.text-*`, `.border-*`
- **State**: `.is-*`, `.has-*`
- **Components**: `.card-*`, `.btn-*`, `.modal-*`

### Color Palette

| Name | Hex | CSS Variable | Usage |
|------|-----|--------------|-------|
| Primary | #0f60af | `--color-primary` | Buttons, links |
| Success | #28a745 | `--color-success` | Standard concepts |
| Danger | #dc3545 | `--color-danger` | Non-standard, errors |
| Warning | #ffc107 | `--color-warning` | Warnings |
| Muted | #6c757d | `--color-muted` | Secondary text |
| Light | #f8f9fa | `--color-light` | Backgrounds |
| Dark | #333333 | `--color-dark` | Primary text |

### Spacing Scale

| Name | Value | CSS Variable |
|------|-------|--------------|
| xs | 4px | `--spacing-xs` |
| sm | 8px | `--spacing-sm` |
| md | 16px | `--spacing-md` |
| lg | 24px | `--spacing-lg` |
| xl | 32px | `--spacing-xl` |

---

## Notes

- This index is maintained by running `/factorize-css` command
- Cross-reference with `/dead-code css` for unused classes
- Prioritize semantic class names over visual descriptions
