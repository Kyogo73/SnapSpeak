# SnapSpeak Design System (Master)

Source: ui-ux-pro-max `--design-system` (2026-08-23, warmth pass 2026-08-25).
Query: `adult language learning iOS warm human commute focused`.
Dials: variance 4 / motion 3 / density 5.

Open Design MCP はこの Cloud VM では daemon 未接続のため使えない。視覚確認の正本は `docs/mockups/` のコード忠実 HTML と SwiftUI 実装。

## Adopted from ui-ux-pro-max

- **Style:** Soft Minimal — Swiss clarity with rounded SF titles, continuous corners, and a warm teal accent. Not Claymorphism (chunky toy shadows / 3–4px borders are rejected).
- **Color:** LMS education teal + course amber notes (`#0F766E` / `#5EEAD4`). Not the skill default indigo wash.
- **Mode:** Light and Dark (iOS `prefers-color-scheme` / system appearances).
- **Motion:** Subtle only. Honor Reduce Motion; no decorative motion on the dashboard.
- **Accessibility:** Text contrast ≥ 4.5:1, visible focus, no color-only state, VoiceOver labels, 44pt targets.

## Product overrides (required)

The skill mapped “education” to children’s typography (Baloo 2 / Comic Neue), Claymorphism, and an indigo marketing palette (`#4F46E5` on `#EEF2FF`). SnapSpeak is an adult, commute-and-drive-first language app on iOS. Those defaults are **rejected**.

| Token | Skill default (rejected) | SnapSpeak (adopted) |
|-------|--------------------------|---------------------|
| Heading / body | Baloo 2 / Comic Neue | SF Rounded via `Typography.title` / `headline` / `score`. Body / callout / caption stay default SF |
| Primary / on-primary | Indigo / white | `Colors.accent` `#0F766E` (light) / `#5EEAD4` (dark). `Colors.onAccent` white / `#042F2E` |
| Background | `#EEF2FF` | `Colors.background` `#F3F6F4` / `#0C1211` |
| Card | White on indigo wash | `CardContainer` = `Colors.cardFill` `#FFFEFB` / `#16201E`, radius 22 continuous, 1pt `cardStroke`, soft shadow |
| Warning / danger / success | Hex marketing | `Colors.warning` / `danger` / `success` (system orange / red / green) |
| Muted text | `#475569` | `Colors.secondaryFill` (`Color.secondary`) |
| Landing pattern | Hero + testimonials + CTA | Native NavigationStack. No marketing landing inside the app |

Do not introduce Google Fonts, raw hex in feature views, or a second palette. Semantic tokens and hex live only in `Packages/SnapSpeakiOS/Sources/DesignSystem/`.

Contrast (WCAG AA text): white on `#0F766E` = 5.47:1; `#5EEAD4` on `#0C1211` = 12.79:1; `#042F2E` on `#5EEAD4` = 9.78:1.

## Spacing and density

Density dial 5 → standard mobile rhythm already used by the app:

- Card stack gap 16pt
- Card padding 18pt
- In-card stack 4–8pt
- Card corner 22pt continuous
- Button corner 14pt
- Chart height 180pt (ux-design §4.8 の唯一の固定高)

## Charts

ui-ux-pro-max chart search: 7 discrete day counts, exact values matter, cells < 20 → **vertical bar**, not heatmap or waffle.

- Empty day is a value of 0, not a missing datum (placeholder bar + `0` label).
- Goal-met is accent + numeric label + checkmark (color is not the only signal).
- Screen-reader summary includes the weekly total (`dashboard.week.summary_a11y`).

## Anti-patterns to keep rejecting

- Kids / playful display type (Baloo, Comic Neue)
- Claymorphism chunky borders and toy-like 3D
- Emoji as structural icons (streak uses SF Symbol `flame` / `flame.fill`)
- Color-only at-risk / goal-met
- Duplicate VoiceOver labels that only repeat the card title
- Animating layout size; dashboard stays static
- Default iOS blue as the only accent (reads cold / inorganic on this product)
