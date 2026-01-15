# Accessibility (a11y) Audit

Audit the codebase for accessibility compliance and WCAG guidelines.

## Arguments

$ARGUMENTS

If no arguments provided, audit all UI-related files.
If a file path is provided, focus the analysis on that specific file.

## Accessibility Checklist

### 1. Semantic HTML

| Check | Good | Bad |
|-------|------|-----|
| Buttons | `tags$button()`, `actionButton()` | `tags$div(onclick=...)` |
| Links | `tags$a(href=...)` | `tags$span(onclick=...)` |
| Headings | Proper hierarchy h1 > h2 > h3 | Skipped levels, styling-only |
| Lists | `tags$ul/ol/li` for lists | `tags$div` with bullets |
| Tables | `tags$table` with `th` | `div` grid layout for data |

### 2. ARIA Attributes

| Element | Required ARIA |
|---------|---------------|
| Interactive divs | `role`, `tabindex`, `aria-label` |
| Icons | `aria-hidden="true"` or `aria-label` |
| Modals | `role="dialog"`, `aria-modal="true"`, `aria-labelledby` |
| Live regions | `aria-live` for dynamic content |
| Expandable | `aria-expanded`, `aria-controls` |
| Tabs | `role="tablist"`, `role="tab"`, `aria-selected` |

### 3. Keyboard Navigation

| Check | Requirement |
|-------|-------------|
| Tab order | Logical, follows visual order |
| Focus visible | Clear focus indicator |
| Skip links | Skip to main content |
| Escape key | Close modals/dropdowns |
| Arrow keys | Navigate within components |

### 4. Color & Contrast

| Check | WCAG Requirement |
|-------|------------------|
| Text contrast | 4.5:1 for normal, 3:1 for large text |
| UI components | 3:1 against adjacent colors |
| Color alone | Never sole indicator (add icons/text) |
| Focus indicator | 3:1 contrast |

### 5. Forms

| Check | Requirement |
|-------|-------------|
| Labels | Every input has associated label |
| Error messages | Programmatically associated |
| Required fields | Indicated visually AND programmatically |
| Instructions | Before the input, not just placeholder |

### 6. Images & Icons

| Check | Requirement |
|-------|-------------|
| Informative images | Descriptive alt text |
| Decorative images | `alt=""` or `aria-hidden="true"` |
| Icon buttons | `aria-label` or visible text |
| Complex images | Long description available |

## Analysis Steps

### Phase 1: Scan UI code

1. **Find clickable non-buttons**:
   ```r
   tags$div(onclick = ...)
   tags$span(onclick = ...)
   # Without role="button" and tabindex
   ```

2. **Find images without alt**:
   ```r
   tags$img(src = ...)  # Missing alt
   ```

3. **Find form inputs without labels**:
   ```r
   textInput(ns("id"), label = NULL)  # No label
   textInput(ns("id"), label = "")    # Empty label
   ```

4. **Find headings hierarchy**:
   ```r
   tags$h1(), tags$h2(), tags$h3()
   # Check for skipped levels
   ```

### Phase 2: Scan CSS

1. **Check focus styles**:
   ```css
   :focus { outline: none; }  # BAD - removes focus
   ```

2. **Check color contrast** for:
   - `.text-*` classes
   - Button backgrounds
   - Error/success states

### Phase 3: Scan JavaScript

1. **Check keyboard handlers**:
   - Escape key for modals
   - Enter/Space for custom buttons
   - Arrow keys for navigation

2. **Check focus management**:
   - Focus trap in modals
   - Focus restoration after modal close

## Output Format

```markdown
## Accessibility Audit Report

### Summary

| Category | Issues | Severity |
|----------|--------|----------|
| Semantic HTML | 5 | High |
| ARIA attributes | 8 | Medium |
| Keyboard navigation | 3 | High |
| Color contrast | 2 | Medium |
| Forms | 4 | High |
| Images | 1 | Low |
| **Total** | **23** | - |

### Critical Issues (Must Fix)

#### 1. Non-semantic clickable elements

| File:Line | Element | Issue | Fix |
|-----------|---------|-------|-----|
| mod_a.R:123 | `tags$div(onclick=...)` | Not keyboard accessible | Use `actionButton()` |

**Impact**: Users cannot interact with keyboard/screen reader

#### 2. Missing form labels

| File:Line | Input | Fix |
|-----------|-------|-----|
| mod_b.R:45 | `textInput(ns("search"), label = NULL)` | Add descriptive label |

### High Priority (Should Fix)

#### 3. Heading hierarchy issues

| File | Issue |
|------|-------|
| mod_a.R | h1 -> h3 (skipped h2) |
| mod_b.R | Multiple h1 elements |

#### 4. Focus not visible

| File:Line | Selector | Issue |
|-----------|----------|-------|
| style.css:234 | `.btn-custom:focus` | `outline: none` without alternative |

### Medium Priority (Consider)

#### 5. Missing ARIA attributes

| File:Line | Element | Missing |
|-----------|---------|---------|
| mod_a.R:200 | Modal div | `role="dialog"`, `aria-modal` |
| mod_b.R:150 | Icon button | `aria-label` |

#### 6. Color contrast warnings

| Element | Foreground | Background | Ratio | Required |
|---------|------------|------------|-------|----------|
| `.text-muted` | #6c757d | #ffffff | 4.0:1 | 4.5:1 |

### Low Priority (Nice to Have)

#### 7. Decorative images

| File:Line | Image | Recommendation |
|-----------|-------|----------------|
| app_ui.R:50 | Logo | Add `alt=""` for decorative |

### Recommended Fixes

#### Quick Wins (< 1 hour)
1. Add `aria-label` to icon buttons
2. Fix heading hierarchy
3. Add labels to form inputs

#### Medium Effort
1. Replace div onclick with proper buttons
2. Add focus styles to custom components
3. Implement keyboard navigation for custom widgets

#### Larger Changes
1. Add skip link to main content
2. Implement focus trap for modals
3. Add live regions for dynamic updates

### Testing Recommendations

1. **Keyboard-only testing**: Tab through entire app
2. **Screen reader**: Test with NVDA/VoiceOver
3. **Color blindness**: Use simulator tools
4. **Zoom**: Test at 200% zoom
```

## Color Contrast Reference

Project colors to check (from style.css):

| Color | Hex | Usage |
|-------|-----|-------|
| Primary | #0f60af | Buttons, links |
| Success | #28a745 | Standard concepts |
| Danger | #dc3545 | Non-standard, errors |
| Muted | #6c757d | Secondary text |
| Background | #f8f9fa | Page background |

## Instructions

- **Prioritize by impact** on users with disabilities
- **Test with real tools** when possible (axe, WAVE)
- **Consider context** - not all violations are equal
- **Provide specific fixes** with code examples
- **Group by component** for easier fixing
