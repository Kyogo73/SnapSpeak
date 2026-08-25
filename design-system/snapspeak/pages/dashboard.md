# Dashboard page override

Overrides `MASTER.md` for `DashboardView.readyContent` (ux-design §4.8, beads `ss-j36`, plan Tasks 1–6).

## Structure (do not restyle into a marketing dashboard)

1. Streak card — `StreakBadge` + longest / total. At-risk adds `streak.at_risk` caption (same copy as Home).
2. Week card — 7 vertical bars, 180pt, value labels, weekly total caption.
3. Modes card — shadowing = average script-match rate; composition = pass rate. Caption names the metric only when a rate exists.
4. Notes card — three captions: metric honesty, local-only, 30 study-day window.

## Phase 1 visual rules

| Finding | Treatment |
|---------|-----------|
| 0-item day looks like a gap | `yEnd` placeholder 0.15 + `secondaryFill` 35% opacity + visible `0`. Y 軸は `max(1, peak)` で、全日 0 でもプレースホルダがフルバーに伸びない |
| Bare `%` on mode rows | Caption `平均スクリプト一致率` / `正解率` under the score |
| At-risk is flame outline only | Warning caption `今日まだ学習していません` |
| 30-day window is implicit | `dashboard.window_note` as the third note line |
| Chart a11y repeats the title | `dashboard.week.summary_a11y` with weekly total |
| Goal-met is accent only | Value + SF Symbol `checkmark` (`accessibilityHidden`; VO already says `dashboard.bar.goal_met`) |

## Chart type

Keep the existing Swift Charts `BarMark`. Do not switch to waffle / heatmap / gauge.
