# Design Guidelines / Hướng dẫn thiết kế / デザインガイドライン

Visual language, design tokens, and UI patterns for CashFlow Manager. All screens must inherit this vocabulary.

## Design Tokens

### Color System

| Token | Light Mode | Dark Mode | Usage |
|-------|-----------|-----------|-------|
| `--color-primary` | `#16A34A` (green-600) | `#22C55E` (green-500) | Primary actions, active states |
| `--color-primary-foreground` | `#FFFFFF` | `#052E16` | Text on primary |
| `--color-surface` | `#FFFFFF` | `#0F172A` | Card backgrounds |
| `--color-surface-elevated` | `#F8FAFC` | `#1E293B` | Elevated cards, dialogs |
| `--color-background` | `#F1F5F9` | `#020617` | Page background |
| `--color-text-primary` | `#0F172A` | `#F8FAFC` | Headings, body |
| `--color-text-secondary` | `#475569` | `#94A3B8` | Captions, metadata |
| `--color-border` | `#E2E8F0` | `#1E293B` | Dividers, card borders |
| `--color-income` | `#16A34A` | `#22C55E` | Income amounts |
| `--color-expense` | `#DC2626` | `#EF4444` | Expense amounts |
| `--color-warning` | `#D97706` | `#F59E0B` | Budget warning, alerts |
| `--color-info` | `#2563EB` | `#3B82F6` | Info badges |

### Typography

| Level | Font | Weight | Size | Usage |
|-------|------|--------|------|-------|
| `display-lg` | Be Vietnam Pro | 700 | 32px | Dashboard balance |
| `display-md` | Be Vietnam Pro | 600 | 24px | Report totals |
| `headline` | Be Vietnam Pro | 600 | 20px | Screen titles |
| `title` | Be Vietnam Pro | 600 | 16px | Card titles, section headers |
| `body-lg` | Be Vietnam Pro | 400 | 16px | List items, form labels |
| `body` | Be Vietnam Pro | 400 | 14px | Paragraphs, descriptions |
| `caption` | Be Vietnam Pro | 400 | 12px | Metadata, timestamps |
| `label` | Be Vietnam Pro | 500 | 11px | Badges, chips |

Japanese text uses Noto Sans JP as fallback with matching weights.

### Spacing

| Token | Value | Usage |
|-------|-------|-------|
| `space-xs` | 4px | Tight icon-label pairs |
| `space-sm` | 8px | Inline gaps |
| `space-md` | 16px | Card padding, list gaps |
| `space-lg` | 24px | Section spacing |
| `space-xl` | 32px | Page margins |
| `space-2xl` | 48px | Hero section padding |

### Roundness

| Token | Value | Usage |
|-------|-------|-------|
| `radius-sm` | 8px | Inputs, chips |
| `radius-md` | 12px | Cards |
| `radius-lg` | 16px | Modals, sheets |
| `radius-full` | 9999px | Avatars, FAB |

### Shadows

| Token | Value | Usage |
|-------|-------|-------|
| `shadow-sm` | 0 1px 2px rgba(0,0,0,0.05) | Subtle lift |
| `shadow-md` | 0 4px 6px rgba(0,0,0,0.07) | Cards |
| `shadow-elevated` | 0 10px 25px rgba(0,0,0,0.1) | Elevated states |
| `shadow-glow` | 0 0 20px rgba(22,163,74,0.3) | CTA active state |

## UI Vocabulary (Anti-Patterns)

These are the shared CSS/animation tokens. Every page MUST use them — never inline raw values.

### Required Classes

| Class | Usage |
|-------|-------|
| `gradient-text` | H1 keyword in hero/heading blocks |
| `bg-grid` | Subtle grid pattern on hero backgrounds |
| `bg-radial-fade` | Radial gradient fade on surfaces |
| `shadow-glow` | Primary CTA active/hover state |
| `animate-fade-in-up` | Heading block entrance animation |
| `animate-shimmer` | Skeleton loading indicators |

### Required Patterns

1. **`<Breadcrumb>`** at top of every page
2. **`animate-fade-in-up`** on every heading block
3. **`gradient-text`** on primary H1 keyword
4. **`<EmptyState>`** component for every "no data" branch — never raw `<p>` placeholder
5. **Status badge** with dot-prefix pattern for all status indicators
6. **Card hover**: `hover:shadow-elevated hover:-translate-y-0.5 transition-all`
7. **CTA active**: `shadow-glow` on primary action buttons
8. **`loading.tsx`** / **`<Skeleton>`** for async states — wrapped in layout structure

### Anti-Patterns — Fix on Sight

| ❌ Bad | ✅ Good |
|--------|---------|
| `text-yellow-500` raw | Use `--color-warning` token |
| `bg-blue-500` raw | Use `--color-info` token |
| Inline `<p>No data</p>` | `<EmptyState>` component |
| Native `<select>` unstyled | Styled dropdown component |
| Inline mobile menu | Mobile menu component |
| Native `<Tooltip title>` | Custom tooltip component |
| Default Next 404/500 page | Branded error page |

## Iconography

- Material Icons (filled) for primary navigation
- Material Icons (outlined) for secondary actions
- Icon size: 20px (inline), 24px (standalone), 32px (hero)
- Custom brand mark: `assets/brand/cashflow-logo-mark.png`

## Animation

| Pattern | Duration | Easing | Usage |
|---------|----------|--------|-------|
| Fade in up | 400ms | `ease-out` | Page/section entrance |
| Shimmer | 1.5s | `linear` infinite | Skeleton loading |
| Hover lift | 200ms | `ease-out` | Card hover |
| Scale press | 100ms | `ease-in-out` | Button press feedback |
| Number counter | 800ms | `ease-out` | Balance animation |
| Page transition | 250ms | `ease-in-out` | Route changes |

## Responsive Breakpoints

| Breakpoint | Width | Target |
|------------|-------|--------|
| `sm` | ≥ 360px | Small phones |
| `md` | ≥ 600px | Tablets portrait |
| `lg` | ≥ 900px | Tablets landscape |
| `xl` | ≥ 1200px | Desktop (linux/windows/macos) |

## Accessibility

- Contrast ratio ≥ 4.5:1 (text), ≥ 3:1 (large text)
- Touch targets ≥ 48×48px
- Focus indicators visible on all interactive elements
- Labels on all form inputs (not placeholder-only)
- Screen reader support via `Semantics` widget
- `NSFaceIDUsageDescription` in iOS Info.plist for biometric prompt

## Brand Assets

| Asset | Path | Usage |
|-------|------|-------|
| Logo mark | `assets/brand/cashflow-logo-mark.png` | App icon, favicon |
| Logo master | `assets/brand/cashflow-logo-master-1024.png` | High-res source |
| Hero dashboard | `docs/media/hero-dashboard.png` | README hero |
| Demo GIF | `docs/media/demo-cashflow-flow.gif` | README demo |

## Screenshot Standards

- **Must show populated data** — never empty states, 404s, loading skeletons, or login redirects
- Seed DB with ≥ 3-5 rows for list pages; full data for detail pages
- Login before capture if auth-gated
- Use `data-testid="content-ready"` with `page.waitForSelector` in Playwright
- All amounts in VND (đồng) format
- Screenshots are the #1 first-impression signal — empty UI looks broken
