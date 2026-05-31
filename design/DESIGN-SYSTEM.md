# PushToTalk — Design System (Refined Native)

> Direction: **Refined minimal / native macOS.** Restraint, precision, vibrancy,
> SF typography, color used *semantically* (state), never *decoratively* (sections).
> This is the durable spec — the HTML mockups are throwaway; these tokens port 1:1
> into `Sources/Utils/Constants/UIConstants.swift`.

## 1. The core move: kill the rainbow

**Before:** 7 section colors (red/blue/purple/orange/green/pink/cyan). Every tab a
different hue, icons painted by section. Reads as "AI slop" — decorative color with
no meaning.

**After:** one accent + neutrals. Color carries *meaning only*:

| Role | Token | Use |
|------|-------|-----|
| Accent | system `accentColor` (user's macOS tint, default blue) | selected nav, primary buttons, focus, active toggle |
| Recording | `red` | recording state ONLY |
| Processing | `orange` | transcribing/processing ONLY |
| Ready / success | `green` | ready/success ONLY |
| Warning | `yellow` | warnings ONLY |
| Everything else | `label` / `secondaryLabel` / `tertiaryLabel` | all icons, text, structure |

Section icons become **monochrome** (`secondaryLabel`), tinting to **accent** only
when their nav row is selected. No more per-section palette.

## 2. Type scale (SF Pro / SF Mono)

Override the frontend-design "no system fonts" rule on purpose — native is the goal.

| Token | Size / Weight | SwiftUI | Use |
|-------|---------------|---------|-----|
| `largeTitle` | 22 / semibold | `.system(size:22,weight:.semibold)` | window/section title |
| `title` | 17 / semibold | `.title3.weight(.semibold)` | card section headers |
| `headline` | 13 / semibold | `.headline` | card titles, emphasized labels |
| `body` | 13 / regular | `.body` | primary content |
| `subheadline` | 12 / regular | `.subheadline` | secondary labels, descriptions |
| `caption` | 11 / regular | `.caption` | hints, metadata |
| `footnote` | 10 / regular | `.caption2` | badges, fine print |
| `mono` | 12 / SF Mono | `.system(size:12,design:.monospaced)` | timer, version, log commands |

Body text 13pt is the macOS standard control size — current 14pt body reads slightly
oversized for a settings pane.

## 3. Spacing — 4-pt grid

Collapse the ad-hoc 8/12/16/20/24 jumble onto a strict scale. Every gap/padding
references one of these. No raw literals in views.

| Token | px | Use |
|-------|----|-----|
| `xs` | 4 | icon↔label, badge insets |
| `sm` | 8 | tight stacks, control inner padding |
| `md` | 12 | default item spacing, card inner row gap |
| `lg` | 16 | card padding, gap between cards |
| `xl` | 24 | section spacing, content margins |

## 4. Radius hierarchy

One value per role — currently 6/8/10/12/20/30 used interchangeably.

| Token | px | Use |
|-------|----|-----|
| `control` | 6 | badges, small chips, toggles container |
| `card` | 10 | cards, list rows, nav selection pill |
| `window` | 16 | window / floating panel |
| `circle` | — | compact recording orb |

Single decision: **all cards & rows = 10**. (Today: rows 10, SettingsCard 12 — pick 10.)

## 5. Materials & depth (refined, not heavy)

- Sidebar: `NSVisualEffectView` `.sidebar` material (the true native settings look),
  not `.hudWindow`. Content pane: `.contentBackground` / solid window background.
- **Drop the white gradient overlays.** The current `Color.white.opacity(0.25→0.1)`
  meshes fight the vibrancy and add noise. Refined = let the material speak.
- Card fill: `quaternaryLabel`-equivalent (`secondary.opacity(0.06)`), with a 1px
  **hairline** border `separator` (`label.opacity(0.08)`). Subtle, not glassy.
- Shadows: one soft window shadow only. Cards are flat (border, no shadow).
- Hairline separators (`Divider`) instead of gradient dividers.

## 6. Motion (point, don't sprinkle)

- Keep: floating-window fade-in, compact-orb spring, recording pulse, timer color
  shift under 10s. These are the high-impact moments — they stay.
- Add: one staggered content reveal when switching tabs (rows fade+rise 6px,
  `animation-delay` ladder) — the single orchestrated moment per the skill.
- Nav selection: 0.18s ease pill slide.
- Remove: nothing janky exists; just don't add scattered micro-bounces.

## 7. Layout

- Settings window: keep 900×650, sidebar **200** (220 is a touch wide for these labels).
- Nav rows: 28px height, 6px radius pill, icon (16) + label (13), accent tint when selected.
- Content: 24px margins, cards max-width ~620, 16px gap.
- Cards: header (16 icon monochrome + 13 semibold title) + hairline + content.

## 8. Port checklist (UIConstants.swift)

- [ ] Replace `SectionColors` enum with monochrome + single accent usage
- [ ] Add `Typography` enum (the table above)
- [ ] Replace scattered spacing with `Spacing.{xs,sm,md,lg,xl}`
- [ ] Collapse radius to `Radius.{control,card,window}`
- [ ] Remove `GradientColors` white-overlay meshes from backgrounds
- [ ] Sidebar material `.hudWindow` → `.sidebar`
- [ ] Body font 14 → 13
