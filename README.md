# levante-longitudinal

Exploratory longitudinal analyses of LEVANTE core-task data, built as a
sequence of reproducible Quarto notebooks. Data come from `levante_data_latest`
on Redivis (currently **v1.2**, the bug-fixed release) via the `rlevante`
package. Shared conventions, palettes, loaders, and cleaning helpers live in
`common.R`; every notebook starts with `source(here::here("common.R"))`.

See `~/Projects/LEVANTE.md` for cross-project LEVANTE context.

## Main notebook stack (run in order)

| Notebook | What it does |
|---|---|
| `00_load_data.qmd` | Pull + cache `levante_data_latest` v1.2, apply cleaning, inventory by site/task/age, **log of known data issues**. Writes `data/scores_all_sites.rds` (cleaned) and `scores_raw.rds`. |
| `01_data_integrity.qmd` | Per-(site, task) audit + verdict table (`data/task_site_verdict.rds`). Adaptive/mode coverage, RTM, extreme scores, score SE. |
| `02_growth.qmd` | Per-task longitudinal growth (LMMs) for Leipzig / Bogotá; within-child vs cross-sectional slopes. |
| `03_sem_growth.qmd` | Construct-level latent growth (Leipzig 3-factor, Bogotá Language) **plus** cross-sectional structure: g vs 3-factor vs bifactor, per-site CFAs, Germany+Canada multigroup, SEM path plots. |

`tasks/` holds per-task trial-level deep dives; `reports/` holds DCC-facing
write-ups; `old/` holds retired exploratory notebooks. Data and rendered HTML
are git-ignored.

## Headline findings so far

- **A column-order IRT scoring bug** in `rlevante::score_irt` mis-scored the
  v1.0 release (worst for CAT / guessing-floor items). Found, validated, and
  fixed upstream; data re-released as v1.2. Write-up: `reports/rlevante_handoff.md`.
- With corrected scores, apparent longitudinal **declines disappear** — growth
  is uniformly positive (math steepest, ~0.6 θ/yr).
- The core battery is a **strong general factor** with only weakly-separable
  reasoning / EF / language domains (inter-factor r ≈ 0.85–0.96; bifactor
  specifics degenerate). Structure **replicates across Germany, Bogotá, Canada**.
- **Stories/ToM** is a reliable but heterogeneous composite (not unidimensional);
  question type organizes it more than story construct; controls drive most
  cross-language non-invariance; partial scalar invariance achievable on targets.

## Remaining known data issues (v1.2)

1. **Memory (`memory-game`) — DROP.** Release-notes scoring issue (2×2 vs 3×3
   grid complexity unmodeled); reinforced by super-low Bogotá scores.
2. **Same & Different (`same-different-selection`) — CAVEAT.** Scoring update
   pending (release notes); also zero T2 at Bogotá.
3. **ROAR-Word non-engagement — handled in cleaning.** Rushers (median RT <
   500 ms) and near-chance non-readers floor at θ = −6; `00` filters
   accuracy < 0.4 OR median RT < 500 ms.
4. **`adaptive` flag missing on 235 runs — backfilled.** Early-beta
   task_versions; all confirmed non-adaptive (DCC); set to FALSE in cleaning.
   Still unfixed upstream.
5. **EAP shrinkage across mode boundaries** (minor): two-wave θ that cross a
   CAT/non-CAT boundary (notably Bogotá math) are mildly compressed by the
   EAP prior. Not a bug; see EAP-vs-WLE discussion.
6. **Open question, not a defect:** Pattern Matching & Sentence Understanding
   show T2 > T1 (release notes) — training vs. development, undetermined.

## Task examination status (stock-take)

Deep-dived = has a dedicated `tasks/` trial-level notebook. `kids_2wave` =
children with ≥ 2 administrations (longitudinal signal).

| Task | task_id | runs | kids 2-wave | status |
|---|---|---:|---:|---|
| Math | egma-math | 2967 | 470 | **deep-dived** (`tasks/math*.qmd`) |
| Stories / ToM | theory-of-mind | 1931 | 198 | **deep-dived** (`tasks/stories_tom*`, `tom_*`) |
| Vocabulary | vocab | 1481 | 239 | **deep-dived** (`tasks/vocab.qmd`) |
| ROAR-Word | swr | 1610 | 195 | **deep-dived** (`tasks/roar_word.qmd`) |
| Memory | memory-game | 1717 | 284 | not yet — **priority** (scoring issue to investigate) |
| Hearts & Flowers | hearts-and-flowers | 1685 | 280 | not yet |
| Pattern Matching | matrix-reasoning | 1536 | 263 | not yet — T2>T1 training question |
| Shape Rotation | mental-rotation | 1482 | 247 | not yet |
| Sentence Understanding | trog | 1465 | 229 | not yet — T2>T1 training question |
| ROAR-Sentence | sre | 1622 | 202 | not yet |
| Same & Different | same-different-selection | 1066 | 201 | not yet — scoring update pending |
| ROAR-Phoneme | pa | 1554 | 69 | not yet |

**Suggested next deep dives:** Memory (resolve the 2×2/3×3 scoring issue at
trial level), then Pattern Matching + Sentence Understanding (test the
training-vs-development T2 > T1 question on corrected data), then the EF block
(Hearts & Flowers, Same & Different).
