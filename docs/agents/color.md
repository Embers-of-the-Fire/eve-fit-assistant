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
  the future discussion platform. New workload surfaces must adopt this family rather than
  inventing a new one.
- **Mood:** functional terminal; information-dense, restrained glow, borders over shadows.
- **Reference values** (as deployed in the app):

| Token | Value | Role |
| ----- | ----- | ---- |
| `primaryBlue` | `#30b2e6` | **primary accent** — brand within workload surfaces, primary actions |
| `deepSpace` | `#0a1a2a` | theme seed / deep background |
| `deepBlue` | `#0c1213` | background |
| `cyberTeal` | `#2a7b9c` | secondary surfaces / subdued accent |
| `neonHighlight` | `#4ed4ff` | **secondary accent** — highlights, links, hover emphasis |
| `terminalText` | `#e0f4ff` | primary text |
| `neonGreen` | `#4dffdf` | decorative highlight (sparing) |
| `neonPurple` | `#9b6dff` | decorative highlight (sparing) |
| `neonPink` | `#ff4dff` | decorative highlight (sparing) |
| `consoleSurface` | `#12202a` | cards, panels (site/platform) |
| `consoleSurfaceAlt` | `#1a2e3a` | hover / nested surfaces (site/platform) |
| `consoleBorder` | `#22404f` | hairline separators (site/platform) |
| `consoleTextDim` | `#9db8c6` | secondary text (site/platform) |
| `consoleTextMuted` | `#64808f` | captions, metadata (site/platform) |

`site/share` currently ships a close neutral-dark approximation (`#0d1117` bg, `#4d9fff`
accent); when it is next rebuilt it should converge on the exact workload tokens above.

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
