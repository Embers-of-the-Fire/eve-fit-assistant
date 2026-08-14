# Design Principles

Cross-product styling principles for EVE Fit Assistant — the app (all platforms) and the
sites (`site/`). These are platform-agnostic: they describe *what* the design is, not how
any specific framework implements it. When the app and a site disagree, align the new work
with the closest existing surface instead of inventing a third look.

## Identity

EFA is a tool for spaceship engineers. The aesthetic is a **ship's console in deep space**:
dark, calm, information-dense, with a small set of luminous accents used sparingly. Think
"terminal in the dark", not "neon arcade". Every surface should feel precise, technical,
and trustworthy.

## Color

### Mood

- **Dark-first.** Dark themes are the primary experience on every surface. Light themes
  exist where the platform demands them, but are secondary and must not drive design
  decisions.
- **Low-noise backgrounds.** Backgrounds and surfaces stay in the near-black blue/gray
  family (the app's `deepSpace`/`deepBlue`, the site's `eve-bg`/`eve-surface`). Surfaces
  layer in small, subtle lightness steps — never large jumps, never pure black-on-black
  ambiguity.
- **Restrained glow.** Glow, shimmer, and neon effects are accents, not ambience. A screen
  should have at most one or two glowing elements at a time.

### Palette roles

The full color system — the two palette families (Brand vs. Workload), per-surface
assignment, concrete token values, and shared semantic colors — is defined in
@docs/agents/color and is canonical. Summary:

- **Brand surfaces** (the homepage and other presentation surfaces) use the gold/cyan
  "New Eden" family.
- **Workload platforms** (the app, the share platform, the future discussion platform)
  share the single cyan-blue "Console" family.
- Everywhere: pick colors by **role** (primary accent, surface, border, text hierarchy,
  semantic status), keep each role consistent, and keep semantic status hues (green /
  amber / red / gray) fixed by meaning regardless of theme.

### Rules

- **Semantic colors are fixed by meaning.** Success is always green, destructive is always
  red, warning is always amber — regardless of theme. Do not reuse these hues for
  decoration.
- **One accent per emphasis.** A view highlights its single most important action with the
  primary accent; everything else uses neutral surfaces. If two things are glowing, one of
  them is wrong.
- **Contrast over decoration.** Text must remain readable against its surface; dim and
  muted text exist for hierarchy, not for hiding required information.
- **Borders instead of shadows in the dark.** Dark surfaces separate through subtle
  borders and small lightness steps, not heavy elevation shadows.

## Shape and Surfaces

- **Slightly rounded, mostly rectangular.** Cards, dialogs, and inputs use small corner
  radii — soft enough to feel modern, sharp enough to feel technical. Fully circular
  shapes are reserved for status dots, badges, and progress indicators.
- **Angular cuts as a signature.** The site's clipped-corner buttons (`eve-angle-cut`)
  express the "engineered hardware" motif. The equivalent on other platforms is a sharp,
  chamfered, or minimally-rounded primary action — not a pill button.
- **Density is a feature.** This is a data tool. Prefer compact spacing and rich
  information over large empty areas; whitespace is used to group, not to decorate.
- **Dividers fade.** Hairline dividers that fade toward the edges (gradient dividers) are
  preferred over hard full-width rules.

## Motion

- **Purposeful and short.** Animations communicate state changes, entrances, and hover
  feedback. Standard transitions run in the 200–400 ms range; entrance animations up to
  ~700 ms. Nothing animates without a reason.
- **Subtle idle life.** Slow ambient effects (pulse, twinkle, float, scanline) are allowed
  on hero/branding elements only, at very low intensity, and never on functional controls
  or data displays.
- **Hover feedback is consistent.** Interactive elements respond with a small, predictable
  set of cues: slight lift, border/accent color shift, gentle glow. Use one or two cues
  per element, not all of them.
- **Respect reduced motion.** Honor the platform's reduced-motion setting; all
  non-essential animation must degrade gracefully.

## Typography

- **Two voice families.** A geometric/technical display face for headings and brand text
  (site: Orbitron); a neutral, highly legible face for everything else (site: Inter, app:
  platform default sans). Never use the display face for body copy or dense data.
- **Clear hierarchy through weight and tone, not size jumps.** Headings are bold and
  tight-tracking; body text is regular weight, relaxed leading, dim color; captions and
  metadata use muted colors. 
- **Eyebrow labels.** Short uppercase, wide-tracking accent-colored labels ("ARCHITECTURE",
  status badges) are a recurring motif for section markers and pills. Use them for
  categories, not sentences.
- **Data is text too.** Numbers, attributes, and stats are first-class content: keep them
  aligned, tabular where possible, and never sacrifice their legibility for style.

## Text Flavor (Voice)

- **Technical, confident, concise.** Copy reads like well-written engineering
  documentation, not marketing. Short declarative sentences; no exclamation marks; no
  hype adjectives ("amazing", "revolutionary").
- **Action-oriented labels.** Buttons and links use short verb phrases: "Get Started",
  "Open Web App", "View on GitHub". Avoid vague labels like "Click Here" or "Submit".
- **Honest about state.** The project is in active development; copy says so plainly
  ("Alpha — Now in Development") instead of over-promising.
- **EVE-native vocabulary.** Use the game's own terms (fit, ship, module, capsuleer, New
  Eden) where the audience expects them; keep meta-vocabulary (data bundle, checkout,
  channel) precise and consistent with the storage docs.
- **Errors and empty states explain and direct.** Say what happened, why if known, and
  what the user can do next. Never blame the user.

## Lingual Design (zh / en)

The product is **bilingual Chinese–English**; both languages are first-class everywhere
user-facing text appears.

- **Equal quality, not translation afterthought.** Chinese copy is written natively, not
  transliterated. Tone stays equivalent: where English is crisp and technical, Chinese is
  简洁、专业 (e.g. "Fit Smarter, Fly Better" ↔ "更智能的装配，更好的飞行").
- **Keep brand and technical loanwords stable.** Product names (EVE Fit Assistant / EFA),
  technology names (Flutter, Rust), and established game terms stay in their canonical
  form in both languages; do not invent Chinese renderings for them.
- **Punctuation follows the language.** Chinese text uses full-width punctuation
  (，。；：、——) and no spaces between CJK characters; English uses standard ASCII
  punctuation. Em-dashes separating clauses in English become — or 、 in Chinese as fits
  the sentence.
- **Layout tolerance.** Chinese text is denser and shorter; English text wraps longer.
  Layouts must accommodate both without truncation or overflow — never size containers to
  fit only one language.
- **One string, one key.** All user-facing strings go through the localization system of
  the relevant platform; no hardcoded user-facing copy in either language. (Exception
  noted in AGENTS.md: developer-mode-only UI in the app uses hardcoded English.)

## Accessibility and Platform Behavior

- **Respect platform conventions.** Each platform's implementation follows its own HIG
  where it does not conflict with these principles (e.g. navigation patterns, system
  fonts, safe areas).
- **Interactive targets stay comfortable.** Compact density never shrinks touch/click
  targets below comfortable platform minimums.
- **State is always visible.** Loading, empty, error, and offline states are designed
  states with skeletons or indicators — never blank screens or silent failures.
