# SnapSpeak Design System (Master)

Source: ui-ux-pro-max `--design-system` (2026-08-23).
Query: `adult language learning iOS productivity native calm focused commute`.
Dials: variance 3 / motion 3 / density 5.

Open Design MCP はこの Cloud VM では daemon 未接続のため使えない。視覚確認の正本は `docs/mockups/` のコード忠実 HTML と SwiftUI 実装。

## Adopted from ui-ux-pro-max

- **Style:** Minimalism & Swiss — clean, spacious, high contrast, geometric, system sans, grid.
- **Mode:** Light and Dark (iOS `prefers-color-scheme` / system appearances).
- **Motion:** Subtle only. Honor Reduce Motion; no decorative motion on the dashboard.
- **Accessibility:** Text contrast ≥ 4.5:1, visible focus, no color-only state, VoiceOver labels, 44pt targets.

## Product overrides (required)

The skill mapped “education” to children’s typography (Baloo 2 / Comic Neue) and an indigo marketing palette (`#4F46E5` on `#EEF2FF`). SnapSpeak is an adult, commute-and-drive-first language app on iOS. Those defaults are **rejected**.

| Token | Skill default (rejected) | SnapSpeak (adopted) |
|-------|--------------------------|---------------------|
| Heading / body | Baloo 2 / Comic Neue | SF Pro via `Typography` (`title` / `headline` / `body` / `callout` / `caption` / `score`) |
| Primary / background | Indigo / `#EEF2FF` | `Colors.accent` (`Color.accentColor`) / `Colors.background` (`systemBackground`) |
| Card | White on indigo wash | `CardContainer` = `secondarySystemBackground`, radius 16, padding 16 |
| Warning / danger / success | Hex marketing | `Colors.warning` / `danger` / `success` (system orange / red / green) |
| Muted text | `#475569` | `Colors.secondaryFill` (`Color.secondary`) |
| Landing pattern | Hero + testimonials + CTA | Native NavigationStack. No marketing landing inside the app |

Do not introduce Google Fonts, raw hex in SwiftUI views, or a second palette. Semantic tokens live in `Packages/SnapSpeakiOS/Sources/DesignSystem/`.

## Spacing and density

Density dial 5 → standard mobile rhythm already used by the app:

- Card stack gap 16pt
- Card padding 16pt
- In-card stack 4–8pt
- Chart height 180pt (ux-design §4.8 の唯一の固定高)

## Charts

ui-ux-pro-max chart search: 7 discrete day counts, exact values matter, cells < 20 → **vertical bar**, not heatmap or waffle.

- Empty day is a value of 0, not a missing datum (placeholder bar + `0` label).
- Goal-met is accent + numeric label + checkmark (color is not the only signal).
- Screen-reader summary includes the weekly total (`dashboard.week.summary_a11y`).

## Anti-patterns to keep rejecting

- Kids / playful display type
- Emoji as structural icons (streak uses SF Symbol `flame` / `flame.fill`)
- Color-only at-risk / goal-met
- Duplicate VoiceOver labels that only repeat the card title
- Animating layout size; dashboard stays static
