---
name: Kinetic Editorial
colors:
  surface: '#f6faf6'
  surface-dim: '#d6dbd7'
  surface-bright: '#f6faf6'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f0f5f1'
  surface-container: '#eaefeb'
  surface-container-high: '#e5e9e5'
  surface-container-highest: '#dfe4e0'
  on-surface: '#181d1b'
  on-surface-variant: '#414844'
  inverse-surface: '#2c322f'
  inverse-on-surface: '#edf2ee'
  outline: '#727974'
  outline-variant: '#c1c8c3'
  surface-tint: '#456557'
  primary: '#022218'
  on-primary: '#ffffff'
  primary-container: '#19382c'
  on-primary-container: '#81a292'
  inverse-primary: '#accebd'
  secondary: '#4e6700'
  on-secondary: '#ffffff'
  secondary-container: '#c7f257'
  on-secondary-container: '#536d00'
  tertiary: '#001d40'
  on-tertiary: '#ffffff'
  tertiary-container: '#003265'
  on-tertiary-container: '#559bfd'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#c7ead9'
  primary-fixed-dim: '#accebd'
  on-primary-fixed: '#012116'
  on-primary-fixed-variant: '#2e4d40'
  secondary-fixed: '#c7f257'
  secondary-fixed-dim: '#acd53d'
  on-secondary-fixed: '#151f00'
  on-secondary-fixed-variant: '#3a4d00'
  tertiary-fixed: '#d6e3ff'
  tertiary-fixed-dim: '#a8c8ff'
  on-tertiary-fixed: '#001b3c'
  on-tertiary-fixed-variant: '#00468a'
  background: '#f6faf6'
  on-background: '#181d1b'
  surface-variant: '#dfe4e0'
typography:
  display-xl:
    fontFamily: Plus Jakarta Sans
    fontSize: 48px
    fontWeight: '800'
    lineHeight: 52px
    letterSpacing: -0.03em
  display-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 36px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.025em
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 34px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 22px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.015em
  headline-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
    letterSpacing: -0.01em
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
    letterSpacing: -0.005em
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
  label-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 18px
    letterSpacing: 0.01em
  label-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 10px
    fontWeight: '600'
    lineHeight: 14px
    letterSpacing: 0.03em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  margin: 1.25rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2.25rem
---

## Brand & Style

This design system establishes an authentic, grounded, and photo-first performance aesthetic tailored for runners, cyclists, and fitness enthusiasts. Moving completely away from faux-tactical sci-fi HUDs, cyan laser glows, and aggressive all-caps data dashboards, the interface embraces an editorial balance inspired by modern endurance print publications, Swiss typography, and high-performance physical gear. 

The emotional tone is quiet confidence, precision, and natural vitality. Rather than shouting through neon overlays, it puts real-world physical exertion front and center through full-bleed aerial topography, cinematic runner photography, and calm, scannable data layouts.

Key visual attributes:
- **Quiet Performance:** High-contrast legibility using natural deep ink and warm off-white tones instead of synthetic stark grays.
- **Editorial Athletics:** Sentence-case humanized microcopy, ample breathing room around complex biometric metrics, and sharp typographic pacing.
- **Physical Grounding:** Subtle ambient diffusion, soft environmental card tones, and refined pill geometry that mirrors modern running hardware and minimalist apparel.

## Colors

The palette balances biological endurance with technical clarity:

- **Primary (`#19382C` - Deep Forest Green):** The core grounding anchor. Applied to active states, navigation headers, primary badge surfaces, and high-emphasis brand elements.
- **Secondary (`#C8F358` - Performance Volt Lime):** A high-visibility kinetic spark reserved exclusively for the most critical user actions (e.g., "Start Workout", active splits, current milestone progress). It is used sparingly to prevent visual fatigue.
- **Tertiary (`#2878D8` - Route Map Blue):** Dedicated to precision spatial and navigational contexts—GPS vector paths, pace polyline heatmaps, and telemetry charts.
- **Neutral (`#101513` - Deep Ink Black):** The deepest text and display metric value color, carrying a subtle green-black undertone that feels warmer and more organic than raw `#000000`.

### Surface & Canvas Tones
- **Canvas Base (Light):** `#F6F7F5` (Surface Soft) paired with `#FFFFFF` for primary cards and `#EDF0EB` for secondary module tints.
- **Canvas Base (Dark):** `#0D1311` (Deep Forest Charcoal) paired with `#151D1A` for elevated module surfaces.
- **Dividers & Outlines:** `#E2E6DF` (Light) and `#1F2B26` (Dark) maintain micro-separation without visual hardness.
- **Muted Semantic Slate:** `#7D8581` for auxiliary metrics, inactive toggle targets, and units (e.g., `bpm`, `/km`, `w`).
- **Milestone Accent:** `#E8A72C` (Warm Gold) celebrates PRs, trophies, and segment achievements.

## Typography

The typography uses **Plus Jakarta Sans** across all roles to achieve an open, athletic, and contemporary editorial voice. 

- **Dynamic Metric Legibility:** Fast-glance reading while running or cycling requires strong, tightly tracked metric glyphs (`display-xl` and `display-lg`). Tabular numeral features (`tnum`) must be enforced for metric values to eliminate visual jitter during real-time GPS updates.
- **Editorial Microcopy:** Never use aggressive, tracking-expanded all-caps for captions or standard labels. All subheaders, labels, and summaries rely on natural sentence case with slight negative tracking on large scales and subtle positive tracking on tiny labels (`label-sm`).
- **Hierarchy Pairing:** Metric cards position numbers prominently at the top with unit descriptors (`km`, `avg pace`, `cal`) placed as quiet, inline or trailing labels using `body-sm` in Muted Slate (`#7D8581`).

## Layout & Spacing

The layout is built on a compact, responsive 4-column mobile grid adapting into an 8-column tablet grid, structured around edge-to-edge media viewports.

- **Mobile Viewport (Base):** 20px (`1.25rem`) side margins provide an expansive, unconfined breathing room for maps and photo carousels. Internal card modules align to a uniform 16px (`1rem`) gutter.
- **Photo & Map Hero Treatment:** Hero map sessions and outdoor photographic journals span full bleed (`margin: 0`), while overlying metric drawers, floating stats bars, and bottom sheets adhere strictly to internal safe padding of `space-md` or `space-lg`.
- **Rhythmic Densities:** Real-time workout tracking dashboards utilize compact padding (`space-sm` to `space-md`) within metric tiles to maximize the vertical view for map lines, while post-run analytical recaps switch to generous editorial padding (`space-lg` to `space-xl`) to encourage leisurely reflection.

## Elevation & Depth

This design system deliberately rejects glowing drop-shadows, synthetic neon halos, and glassy skeletal skeuomorphism. Depth is achieved via tonal contrast and organic daylight shadows:

- **Level 0 (Flat Canvas):** `#F6F7F5` in light mode or `#0D1311` in dark mode. Provides the resting bed for inline content.
- **Level 1 (Card Modules):** Pure white `#FFFFFF` (or `#151D1A` dark) resting on the canvas, bounded by a 1px soft hairline border (`#E2E6DF` / `#1F2B26`). Shadows are ambient and soft: `0 2px 8px rgba(16, 21, 19, 0.04)`.
- **Level 2 (Floating Action Controls & Map Overlays):** Interactive floating map controls (re-center, map layer toggle, split counter) utilize a crisp surface elevated with: `0 8px 24px -4px rgba(16, 21, 19, 0.08)`, supplemented by an ultra-thin 1px border.
- **Level 3 (Modal Sheets & Workout HUD Sheets):** Sliding bottom sheets resting above active GPS routes feature an ambient multi-stop shadow: `0 20px 40px -8px rgba(16, 21, 19, 0.16)`.

## Shapes

The geometric signature combines organic curve transitions with aerodynamic pill ergonomics:

- **Cards & Data Modules:** Standardized to `rounded-lg` (16px / `1rem`), generating a solid, comfortable enclosure for complex multi-stat arrangements.
- **Control Pills & Chips:** Category chips, outdoor/indoor segmented toggles, filter tags, and primary CTAs use absolute pill shaping (`rounded-full`), reflecting the ergonomic curves of athletic smartwatches and handheld monitors.
- **Nested Progress Tracks:** Inner progress indicators and elevation bar charts retain fully rounded caps (`rounded-full`) to maintain an athletic, fluid visual rhythm.

## Components

### Buttons & Interactive CTAs
- **Primary Kinetic Action:** The core workout triggers ("Start Run", "Resume") use high-contrast Performance Volt (`#C8F358`) paired with Deep Ink text (`#101513`), pill shape, minimum 52px height, and `label-lg` font weight. No drop-shadow glow; crisp elevation only.
- **Secondary Action:** Forest Green (`#19382C`) container with white text, or clean white container with `#E2E6DF` border for auxiliary workout actions.
- **Destructive / Stop Action:** A deep crimson ink tone (`#D43D3D`), avoiding high-saturation neon reds. Requires a 2-second continuous circular hold-to-confirm pattern for ending sessions.

### Segmented Activity Toggles (Outdoor GPS vs. Indoor Stationary)
- An enclosed pill track (`#EDF0EB` in light, `#151D1A` in dark) containing smooth sliding pill buttons. Active state lifts with pure white surface, 1px border, and soft ambient shadow. Icons use micro 16px geometry paired with sentence-case text ("Outdoor GPS", "Indoor treadmill").

### Metric Grid Tiles
- White or soft-tinted cards displaying a single prominent figure (`display-lg`) in Deep Ink, an inline unit label in slate (`body-sm`), and a bottom-aligned contextual sparkline or micro-caption ("2s faster than avg"). All numbers render with fixed-width numerals.

### Route Maps & Photo Journal Cards
- Map containers are rendered edge-to-edge or with 16px card radiuses. GPS vector tracks use Route Map Blue (`#2878D8`) with a 4px clean stroke and rounded cap joints, avoiding glowing halos. Waypoint markers use high-contrast white circles with forest green rings.
- User photos anchor workout recaps with 4:5 portrait or 16:9 cinematic crops, layered with a subtle bottom vignette to support overlaid white metric typography.

### Chips & Filter Pills
- 36px height with generous horizontal padding (16px). Inactive: `#FFFFFF` with `#E2E6DF` border. Active: Deep Forest Green (`#19382C`) fill with clean white text.

### Form Inputs & Sensor Fields
- Clean input containers (48px height) using `#FFFFFF` with `#E2E6DF` outline. Focused inputs transition to a 1.5px `#19382C` border with zero colored outer glow rings.