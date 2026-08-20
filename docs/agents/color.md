# Color System

Canonical color guidance for all EVE Fit Assistant surfaces. The general design principles
live in @docs/agents/style; this file is the authority on **which palette a surface uses**
and on concrete palette values.

## Two Families

The product deliberately runs **two color families**. Picking a family is the first design
decision for any new surface; never blend the two accent systems within one surface.

### Brand family — "New Eden" (gold / cyan)

For **brand-facing, marketing, and presentation surfaces** — surfaces whose job is to
represent the project to the outside world.

- **Used by:** the homepage (`site/home`) and any future brand page (landing, announcement
  banners, promotional material).
- **Mood:** cinematic deep-space console; luminous, atmospheric, glow accents allowed on
  hero/branding elements.
- **Reference values** (as deployed in `site/home`):

| Token | Value | Role |
| ----- | ----- | ---- |
| `bg` | `#05080f` | page background |
| `surface` | `#0a1020` | cards, panels |
| `surface-alt` | `#0f162a` | hover / nested surfaces |
| `border` | `#1a2744` | hairline separators |
| `border-accent` | `#2a3f6a` | emphasized borders, divider gradients |
| `gold` | `#c8a951` | **primary accent** — brand, primary actions, active states |
| `gold-dim` | `#8a6d2b` | subdued gold |
| `gold-glow` | `#3d3115` | ambient glow washes |
| `cyan` | `#00e5ff` | **secondary accent** — gradient partners, links, hover highlights |
| `cyan-dim` | `#0a2a3a` | ambient cyan washes |
| `text` | `#cdd4de` | primary text |
| `text-dim` | `#9ca3af` | secondary text |
| `text-muted` | `#6b7280` | captions, metadata |
| `red` | `#d32f2f` | danger |

### Workload family — "Console" (cyan-blue / teal)

For **workload platforms** — surfaces where users do actual work: dense data, tools,
dashboards, interactive content. One consistent console look across all of them.

- **Used by:** the app (all native/web targets), the share platform (`site/share`), and
  the discussion platform (`site/platform`). New workload surfaces must adopt this family
  rather than inventing a new one.
- **Mood:** functional terminal; information-dense, restrained glow, borders over shadows.
- **Reference values** — the app's rendered theme is the Material 3 tonal-spot dark scheme
  derived from seed `#0a1a2a` (`ColorScheme.fromSeed` in `main.dart`); these computed values
  are canonical. The legacy named constants (`primaryBlue` `#30b2e6`, `deepBlue` `#0c1213`,
  `terminalText` `#e0f4ff`, …) still exist in `lib/constant/colors.dart` but are not what
  the app renders with; do not use them for new surfaces.

| Token | Value | Role |
| ----- | ----- | ---- |
| `surface` | `#101418` | page background, base surfaces |
| `surfaceContainerLowest` | `#0b0e13` | inset wells (code blocks) |
| `surfaceContainerLow` | `#191c20` | cards, panels, topbars |
| `surfaceContainerHigh` | `#272a2f` | hover / nested surfaces |
| `surfaceContainerHighest` | `#32353a` | progress/bar tracks |
| `primary` | `#9fcafc` | **primary accent** — primary actions, active states |
| `onPrimary` | `#003257` | text/icons on `primary` fills |
| `primaryContainer` | `#174974` | subdued accent fills |
| `onPrimaryContainer` | `#d1e4ff` | **secondary accent** — highlights, links, hover emphasis |
| `outlineVariant` | `#42474e` | hairline separators, frame borders |
| `outline` | `#8d9199` | captions, metadata |
| `onSurface` | `#e1e2e8` | primary text |
| `onSurfaceVariant` | `#c3c7cf` | secondary text |

### Semantic colors (shared, family-independent)

Semantic hues are fixed by **meaning** and stay constant across both families and all
themes. Never reuse these hues decoratively.

| Meaning | Hue | App reference |
| ------- | --- | ------------- |
| Success / active | green | `colorStatusActive` `#2e7d32` |
| Warning / limited | amber | `colorSkillAlphaLimited` `#fbc02d` |
| Danger / overload / destructive | red | `colorStatusOverload` `#ef5350`, `colorActionDelete` `#fe4a49` |
| Online-but-neutral / disabled | gray | `colorStatusOnline` `#bdbdbd`, `colorStatusPassive` `#2d2d2d` |

## Rules

1. **Classify the surface first.** Brand-facing → Brand family. User-work surface →
   Workload family. If a surface does both (e.g. an in-app announcement view), it is a
   workload surface; brand styling may appear only in embedded brand assets (logo,
   banners), not in the surface's own palette.
2. **One accent system per surface.** Gold and cyan-blue never mix on the same screen.
   Within a surface, the family's primary accent marks the single most important action.
3. **Cross-links may switch families.** Navigating from the homepage to the app, share, or
   discussion platform *is* a visible palette switch — that is intentional product
   differentiation, not inconsistency.
4. **Dark-first in both families.** Both palettes are designed dark-first; light variants
   are secondary and must preserve the family's accent identity.
5. **New tokens join a family.** When a new color is genuinely needed, add it to the
   matching family table here before using it, following the existing naming (role-based,
   not appearance-based where possible).
