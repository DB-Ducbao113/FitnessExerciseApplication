---
name: Kinetic Telemetry
colors:
  surface: '#0e1417'
  surface-dim: '#0e1417'
  surface-bright: '#343a3d'
  surface-container-lowest: '#090f12'
  surface-container-low: '#161c1f'
  surface-container: '#1a2024'
  surface-container-high: '#252b2e'
  surface-container-highest: '#303639'
  on-surface: '#dee3e7'
  on-surface-variant: '#c0c8ca'
  inverse-surface: '#dee3e7'
  inverse-on-surface: '#2b3135'
  outline: '#8a9294'
  outline-variant: '#40484a'
  surface-tint: '#9bcfda'
  primary: '#cff6ff'
  on-primary: '#00363e'
  primary-container: '#a8dce7'
  on-primary-container: '#2e626c'
  inverse-primary: '#32666f'
  secondary: '#73d4e9'
  on-secondary: '#00363f'
  secondary-container: '#349db1'
  on-secondary-container: '#002f36'
  tertiary: '#ffece6'
  on-tertiary: '#5c1a00'
  tertiary-container: '#ffc7b4'
  on-tertiary-container: '#944324'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#b7ebf6'
  primary-fixed-dim: '#9bcfda'
  on-primary-fixed: '#001f24'
  on-primary-fixed-variant: '#154e57'
  secondary-fixed: '#a4eeff'
  secondary-fixed-dim: '#73d4e9'
  on-secondary-fixed: '#001f25'
  on-secondary-fixed-variant: '#004e5a'
  tertiary-fixed: '#ffdbcf'
  tertiary-fixed-dim: '#ffb59b'
  on-tertiary-fixed: '#380d00'
  on-tertiary-fixed-variant: '#7a3012'
  background: '#0e1417'
  on-background: '#dee3e7'
  surface-variant: '#303639'
typography:
  display-xl:
    fontFamily: Plus Jakarta Sans
    fontSize: 56px
    fontWeight: '800'
    lineHeight: 64px
    letterSpacing: -0.03em
  display-xl-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 40px
    fontWeight: '800'
    lineHeight: 48px
    letterSpacing: -0.02em
  metric-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 44px
    fontWeight: '700'
    lineHeight: 48px
    letterSpacing: -0.02em
  metric-lg-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 36px
    letterSpacing: -0.01em
  metric-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 32px
    letterSpacing: -0.01em
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-lg-mobile:
    fontFamily: Plus Jakarta Sans
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.01em
  headline-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 24px
    letterSpacing: 0em
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
    letterSpacing: 0em
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: 0em
  body-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
    letterSpacing: 0.01em
  label-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.05em
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 10px
    fontWeight: '700'
    lineHeight: 12px
    letterSpacing: 0.08em
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  gutter: 1.25rem
  gutter-mobile: 0.75rem
  margin: 2rem
  margin-mobile: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2.5rem
---

## Brand & Style

This design system expresses high-precision athletic engineering and physiological telemetry. The aesthetic balances deep, quiet performance surfaces with sharp, luminous accents. It avoids visual clutter, faux-futuristic cyberpunk grids, and harsh neon overkill in favor of an understated, instrument-grade interface engineered for focus, metrics mastery, and low-light training conditions.

### Visual Principles
- **Subdued Foundation:** Structural backgrounds recede into deep charcoal obsidian tones to eliminate visual fatigue and accentuate operational data.
- **Luminescent Purpose:** The electric cyan accent (`#A8DCE7`) operates strictly as an active state, visual confirmation, or high-priority metric marker. Glowing effects are applied solely to active states, biometric thresholds, and primary actions.
- **Architectural Clarity:** Layouts favor structural calm, using tonal contrast and microscopic border dividers rather than abrasive lines.
- **Telemetry-Grade Precision:** Data points, numerical values, and progression metrics command hierarchy through typographic scale and stark white luminance against shadowy structural containers.

## Colors

The palette relies on deep abyssal teal-charcoals layered systematically to create optical depth, punctuated by arctic cyan-blue as the functional catalyst.

### Palette Architecture
- **Canvas Base (`#0C1113`):** Global viewport background. Absorptive, near-black teal-slate.
- **Surface Layer 1 (`#12181B`):** Base container cards, standard structural modules, and persistent sidebars.
- **Surface Layer 2 (`#192226`):** Elevated cards, interactive panels, dropdowns, and modal sheets.
- **Surface Layer 3 (`#232F35`):** Hover surfaces, active card highlights, and inner input troughs.
- **Primary Accent (`#A8DCE7`):** Pure telemetry focus. Used for primary CTAs, active graph paths, heart rate spikes, toggle checks, and glowing focus rings.
- **Secondary Support (`#50B4C8`):** Mid-depth cyan used for secondary active controls, data gradients, and metric comparisons.
- **Tertiary Performance Alert (`#F38D68`):** Calibrated coral used for physiological strain, zone thresholds, recovery warnings, and critical metrics.
- **Text & Contrast Tier:**
  - *Metric / Display:* `#FFFFFF` (100% white for instant reading of metrics and values).
  - *Primary Typography:* `#E1E8EB` (90% contrast for comfortable reading).
  - *Secondary / Label:* `#7D919A` (Muted cool gray for units, timestamps, and secondary descriptors).
  - *Divider / Ghost Border:* `rgba(168, 220, 231, 0.08)` or solid `#202B30`.

## Typography

Typography is clean, highly legible, and engineered for split-second biometric comprehension. Plus Jakarta Sans provides clean geometry with open apertures, maximizing legibility in low-light environments and dense dashboard arrangements.

### Rules & Formatting
- **Telemetry & Numbers:** Metric sizes (`metric-lg`, `metric-md`) use tabular figures (`font-variant-numeric: tabular-nums`) to prevent horizontal jitter during real-time data streaming.
- **Labels & Units:** Units of measure (e.g., `BPM`, `WATT`, `KCAL`, `MS`) and tracking labels use `label-sm` or `label-md` with uppercase styling and expanded tracking (`letter-spacing: 0.05em` to `0.08em`).
- **Headlines:** Keep title and section headers concise. Tight negative tracking creates a solid, engineered posture.

## Layout & Spacing

The layout is built around a structured 12-column responsive fluid grid on desktop, 8 columns on tablet, and 4 columns on mobile devices.

### Rhythm & Alignment
- **Component Breathing Room:** High-density telemetry cards require strict internal spacing. A base 4px/8px modular scale dictates layout offsets.
- **Responsive Adaptations:**
  - *Desktop (>1024px):* 12 columns, 32px margins, 20px gutters. Data grids can run in 3- or 4-column groupings.
  - *Tablet (768px - 1023px):* 8 columns, 24px margins, 16px gutters. Dashboard modules wrap into 2-column configurations.
  - *Mobile (<767px):* 4 columns, 16px margins, 12px gutters. Telemetry blocks collapse to full-width or side-by-side metric pairs.
- **Zero-Grid Clutter:** Do not render decorative grid lines or faux-HUD wireframes. Separation is achieved through distinct panel backgrounds and precise layout spacing.

## Elevation & Depth

Visual hierarchy relies on stacked tonal surfaces paired with low-contrast micro-outlines, augmented by localized glow halos rather than drop shadows.

### Surface Hierarchy
- **Canvas Base (`#0C1113`):** Infinite ground plane.
- **Tier 1 Container (`#12181B`):** Standard resting containers. Bound by 1px solid `#1C272C` or `rgba(168, 220, 231, 0.06)`.
- **Tier 2 Interactive (`#192226`):** Raised surfaces, cards, and popovers. Bound by 1px solid `rgba(168, 220, 231, 0.12)`.
- **Tier 3 Overlays (`#232F35`):** Modals, context menus, tooltips.

### Ambient Shadows & Functional Glow
- **Shadows:** Deep, diffuse black shadows provide separation: `box-shadow: 0 12px 32px -4px rgba(0, 0, 0, 0.65)`.
- **Functional Glow (Accent Halos):** Primary CTAs, active data thresholds, and selected indicators project a light bloom:
  - *Resting Glow:* `0 0 16px -2px rgba(168, 220, 231, 0.25)`
  - *Focus / Critical Accent:* `0 0 24px 0px rgba(168, 220, 231, 0.40)`
  - *Warning/Strain Glow:* `0 0 20px -2px rgba(243, 141, 104, 0.35)`

## Shapes

The shape system utilizes controlled, soft-radius curvature (`roundedness: 1`), reinforcing a precise, instrumentation-hardware feel rather than an informal or toy-like appearance.

### Geometry Hierarchy
- **Standard Controls & Badges (0.25rem / 4px):** Form fields, action chips, tabs, tooltips, and telemetry tags.
- **Cards & Data Modules (0.5rem / 8px):** Primary analytic cards, session logs, charts, and media wrappers.
- **Modals & Overlays (0.75rem / 12px):** Dialog windows and elevated drawer panels.
- **Full Radius (9999px):** Status beads, live workout pulse rings, and toggle switches only.

## Components

### Buttons
- **Primary:** Background `#A8DCE7`, text `#0C1113`, weight 700. In focus/hover, applies an outer cyan glow (`0 0 20px rgba(168, 220, 231, 0.35)`). Border: none.
- **Secondary:** Background `#192226`, text `#E1E8EB`, 1px border `rgba(168, 220, 231, 0.15)`. Hover elevates background to `#232F35` with border `#A8DCE7`.
- **Ghost / Tertiary:** Transparent background, text `#7D919A`, hover text `#FFFFFF` and hover background `rgba(255, 255, 255, 0.04)`.

### Cards & Telemetry Blocks
- Constructed with `#12181B` fill, framed with a 1px solid border (`#1C272C`).
- Metrics inside cards feature a two-part lockup: the raw numeric reading in `#FFFFFF` (`metric-lg` or `metric-md`) paired with a micro uppercase unit descriptor (`label-sm`) in `#7D919A`.
- If an active threshold is triggered, the card's top border receives a 2px highlight in `#A8DCE7` or `#F38D68`.

### Chips & Filter Pills
- Compact height (28px - 32px), 4px border radius.
- Inactive: `#12181B` background, `#7D919A` label, 1px border `#202B30`.
- Active: `#192226` background, `#A8DCE7` label, 1px border `#A8DCE7`, accompanied by a subtle 4px radial cyan glow marker.

### Input Fields
- Background `#0C1113`, border 1px solid `#232F35`, text `#E1E8EB`, placeholder `#4B5A62`.
- Focus state transition: border color snaps to `#A8DCE7` accompanied by an inner/outer focus-glow shadow `0 0 0 1px #A8DCE7, 0 0 12px rgba(168, 220, 231, 0.2)`.

### Checkboxes & Radio Controls
- Base: 18px square (or circle), background `#0C1113`, border 1.5px solid `#313F47`.
- Checked: Background `#A8DCE7`, check mark / indicator rendered in `#0C1113`. Subtle exterior bloom.

### Telemetry Sparklines & Stream Charts
- Line paths use a crisp 2px stroke in `#A8DCE7`.
- Linear vertical gradient fill underneath: `#A8DCE7` at 18% opacity descending cleanly into `#0C1113` at 0% opacity.
- Dynamic data scrub point: 6px solid white circle centered in a 12px `#A8DCE7` ring with `0 0 12px #A8DCE7` glow.