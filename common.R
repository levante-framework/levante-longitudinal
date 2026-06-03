# common.R
#
# Shared LEVANTE conventions for this project:
#  - plotting theme & palettes (matched to ~/Projects/levante-pilots/plot_settings.R)
#  - task / construct lookups
#  - site label lookups
#  - dataset loader for levante_data_latest with disk cache
#
# Each notebook should `source(here::here("common.R"))` near the top.

suppressPackageStartupMessages({
  library(tidyverse)
  library(here)
  library(glue)
  library(fs)
  library(ggthemes)
  library(rlevante)
})

# ---- Theme ------------------------------------------------------------------
# Matches levante-pilots/plot_settings.R. Source Sans 3 is loaded via
# sysfonts/showtext if available; otherwise we fall back to the system default
# so this still works in headless renders without those packages installed.

.levante_font <- "sans"
if (requireNamespace("sysfonts", quietly = TRUE) &&
    requireNamespace("showtext", quietly = TRUE)) {
  .levante_font <- "Source Sans 3"
  sysfonts::font_add_google(.levante_font)
  showtext::showtext_auto()
  showtext::showtext_opts(dpi = 300)
}

theme_set(theme_bw(base_size = 14, base_family = .levante_font))
theme_update(panel.grid = element_blank(),
             strip.background = element_blank(),
             legend.key = element_blank(),
             panel.border = element_blank(),
             axis.line = element_line(),
             strip.text = element_text(face = "bold"))

options("ggplot2.continuous.colour" = viridis::scale_colour_viridis)
options("ggplot2.continuous.fill"   = viridis::scale_fill_viridis)

# ---- Palettes ---------------------------------------------------------------

# Construct/task category palette (ptol)
task_categories_vec <- c("Executive function", "Math", "Reasoning",
                         "Spatial cognition", "Language", "Reading",
                         "Social cognition")
task_pal <- ptol_pal()(length(task_categories_vec)) |>
  rlang::set_names(task_categories_vec)

scale_colour_task <- function(...) scale_colour_manual(values = task_pal, ...)
scale_color_task  <- scale_colour_task
scale_fill_task   <- function(...) scale_fill_manual(values = task_pal, ...)

# Site palette (solarized) — mapped to internal site codes
site_pal <- solarized_pal()(6) |>
  rlang::set_names(c("pilot_uniandes_co", "pilot_mpieva_de",
                     "pilot_western_ca", "partner_mpib_de",
                     "partner_sparklab_us", "pilot_langcog_us"))

scale_colour_site <- function(...) {
  scale_colour_manual(values = site_pal, labels = site_labels_named, ...)
}
scale_color_site <- scale_colour_site
scale_fill_site  <- function(...) {
  scale_fill_manual(values = site_pal, labels = site_labels_named, ...)
}

# ---- Lookups ----------------------------------------------------------------

# Internal site → friendly label
site_labels_named <- c(
  pilot_uniandes_co   = "Colombia",
  pilot_mpieva_de     = "Germany (MPI EVA Leipzig)",
  pilot_western_ca    = "Canada (Western)",
  partner_mpib_de     = "Germany (MPIB Berlin)",
  partner_sparklab_us = "US (Sparklab, downext)",
  pilot_langcog_us    = "US (LangCog, downext)"
)

# dataset → finer label (preserves bogota / rural / main distinctions)
dataset_labels_named <- c(
  pilot_uniandes_co_bogota   = "Colombia — Bogotá",
  pilot_uniandes_co_rural    = "Colombia — Caquetá/Boyacá",
  pilot_mpieva_de_main       = "Germany — Leipzig",
  pilot_western_ca_main      = "Canada — Ontario",
  partner_mpib_de_main       = "Germany — Berlin (MPIB)",
  partner_sparklab_us_downex = "US — Sparklab (downext)",
  pilot_langcog_us_downex    = "US — LangCog (downext)"
)

# task_id → short label + category + display label
task_lookup <- tribble(
  ~task_id,                    ~short,    ~task_category,        ~task_label,
  "hearts-and-flowers",        "hf",      "Executive function",  "Hearts and Flowers",
  "memory-game",               "mg",      "Executive function",  "Memory",
  "same-different-selection",  "sds",     "Executive function",  "Same and Different",
  "mefs",                      "mefs",    "Executive function",  "MEFS",
  "matrix-reasoning",          "matrix",  "Reasoning",           "Pattern Matching",
  "mental-rotation",           "mrot",    "Spatial cognition",   "Shape Rotation",
  "egma-math",                 "math",    "Math",                "Math",
  "vocab",                     "vocab",   "Language",            "Vocabulary",
  "trog",                      "trog",    "Language",            "Sentence Understanding",
  "theory-of-mind",            "tom",     "Social cognition",    "Stories (ToM)",
  "swr",                       "swr",     "Reading",             "ROAR-Word",
  "sre",                       "sre",     "Reading",             "ROAR-Sentence",
  "pa",                        "pa",      "Reading",             "ROAR-Phoneme"
)

# Convenience: the 9 LEVANTE core tasks (excluding ROAR + MEFS)
core_task_ids <- c(
  "hearts-and-flowers", "memory-game", "same-different-selection",
  "matrix-reasoning", "mental-rotation",
  "egma-math",
  "vocab", "trog",
  "theory-of-mind"
)

# ---- Data loading -----------------------------------------------------------

#' Load the unified LEVANTE scores dataset (levante_data_latest), with
#' on-disk cache.
#'
#' @param refresh re-download even if cached
#' @param version Redivis version qualifier; defaults to v1_2 (corrected scores; v1.0 had the
#'        documented in the rlevante warning. Use "current" to always pull
#'        the latest.
load_levante_scores <- function(refresh = FALSE,
                                version = "v1_2",
                                cache_dir = here("data")) {
  dir_create(cache_dir)
  cache_path <- file.path(cache_dir,
                          glue("levante_data_latest__{version}__scores.rds"))

  if (!refresh && file_exists(cache_path)) {
    return(read_rds(cache_path))
  }

  ref <- if (version == "current") "levante_data_latest"
         else glue("levante_data_latest:e9pf:{version}")

  out <- rlevante::get_scores(ref) |>
    label_levante_scores()

  write_rds(out, cache_path)
  out
}

#' Load trial-level data for one task (or all tasks) from
#' levante_data_latest. The full trials table is ~280 MB so we cache it
#' once and slice by task on demand.
#'
#' @param task_ids character vector of task_ids to keep, or NULL for all
#' @param refresh re-download even if cached
#' @param version Redivis version qualifier (default "v1_2"; v1.0 was pre-bugfix)
load_levante_trials <- function(task_ids = NULL, refresh = FALSE,
                                version = "v1_2",
                                cache_dir = here("data")) {
  dir_create(cache_dir)
  cache_path <- file.path(cache_dir,
                          glue("levante_data_latest__{version}__trials.rds"))

  if (!refresh && file_exists(cache_path)) {
    out <- read_rds(cache_path)
  } else {
    ref <- if (version == "current") "levante_data_latest"
           else glue("levante_data_latest:e9pf:{version}")
    out <- rlevante::get_trials(ref)
    write_rds(out, cache_path)
  }
  # Apply labels every time (label_levante_scores is idempotent enough)
  out <- label_levante_scores(out)
  if (!is.null(task_ids)) out <- out |> filter(task_id %in% task_ids)
  out
}

# ---- Rescoring with the production mirt model -------------------------------
#
# Mirror of rlevante:::score_irt but parameterized by fscores method so we can
# compare EAP (the pipeline default) against ML on the same data and model.
#
# Returns a tibble with one row per run_id: { score, score_se, method }.
score_with_method <- function(trials, task, dataset, method = "EAP",
                              scoring_table = NULL, registry_table = NULL,
                              mod_rec = NULL) {
  if (!requireNamespace("mirt", quietly = TRUE)) {
    stop("Install the mirt R package to use score_with_method().")
  }
  if (is.null(scoring_table)) scoring_table <- rlevante::fetch_scoring_table()
  if (is.null(registry_table)) registry_table <- rlevante::fetch_registry_table()
  spec <- rlevante:::get_model_spec(task, dataset, scoring_table)
  if (is.null(mod_rec)) mod_rec <- rlevante:::get_model_record(spec, registry_table)

  trials_task <- trials |> filter(task_id == spec$task_id | item_task == spec$item_task)
  recoded     <- rlevante::recode_trials(trials_task)

  data_filtered <- rlevante:::dedupe_items(recoded |> rename(group = "site"))
  data_wide     <- rlevante:::to_mirt_shape_grouped(data_filtered)
  data_prepped  <- data_wide |> select(-"group")
  groups        <- data_wide |> pull("group")
  data_group    <- unique(groups)
  # Mirror score_irt's group handling: only intervene when the data group is
  # absent from the model AND the model has an invariance type (multigroup).
  # Single-group by_language models have invariance = NA and ignore data_group
  # entirely (the SingleGroupClass branch below uses mirt() without a group).
  if (any(!(data_group %in% mod_rec@group_names))) {
    if (!is.na(spec$invariance) && spec$invariance %in% c("metric", "configural")) {
      stop("metric/configural model requires all data groups to be in the model.")
    } else if (!is.na(spec$invariance) && spec$invariance == "scalar") {
      data_group <- mod_rec@group_names[[1]]
    }
  }

  overlap_items <- intersect(colnames(data_prepped), rlevante::items(mod_rec))
  data_aligned  <- data_prepped |> select(all_of(overlap_items))
  missing_items <- setdiff(rlevante::items(mod_rec), colnames(data_prepped))
  data_aligned[, missing_items] <- NA
  # CRITICAL: reorder columns to match the model's item order. Without this,
  # mirt::fscores can mismatch response.pattern columns to the model by
  # position, producing wildly wrong θ estimates for some kids.
  data_aligned <- data_aligned[, rlevante::items(mod_rec)]

  mod_vals <- rlevante::model_vals(mod_rec)
  if (rlevante::model_class(mod_rec) == "MultipleGroupClass") {
    mod_recon <- mirt::multipleGroup(data = mod_rec@data, group = mod_rec@groups,
                                      pars = mod_vals, TOL = NaN)
    mod <- mirt::extract.group(mod_recon, group = data_group)
  } else {
    mod <- mirt::mirt(data = mod_rec@data, pars = mod_vals, TOL = NaN)
  }

  fs <- mirt::fscores(mod, method = method, response.pattern = data_aligned)
  raw_score <- as.numeric(fs[, "F1"])
  # ML can return ±Inf or extreme values for boundary patterns (all correct /
  # all incorrect, or thin information). Clip at ±6 to match the bounded
  # MLE convention used in the hand-rolled diagnostic.
  clipped <- pmin(pmax(raw_score, -6), 6)
  tibble::tibble(
    run_id   = rownames(data_prepped),
    score_raw = raw_score,
    score    = clipped,
    score_se = as.numeric(fs[, "SE_F1"]),
    method   = method
  )
}

# ---- Item parameters --------------------------------------------------------
#
# IRT item parameters live in the levante_metadata_scoring dataset on Redivis,
# not in rlevante (as of v1.0). Pull them directly via the redivis R package.
# Each calibration model writes its own row; for cross-site analyses we want
# the multigroup_site / scalar Rasch fits.

#' Load item parameters from levante_metadata_scoring, with disk cache.
#'
#' @param version metadata-scoring version qualifier, default v1_14
#' @param refresh re-download even if cached
load_item_parameters <- function(version = "v1_14", refresh = FALSE,
                                 cache_dir = here("data")) {
  dir_create(cache_dir)
  cache_path <- file.path(cache_dir,
                          glue("item_parameters_{version}.rds"))
  if (!refresh && file_exists(cache_path)) return(read_rds(cache_path))

  if (!requireNamespace("redivis", quietly = TRUE)) {
    stop("Install the redivis R package to load item parameters.")
  }
  user    <- redivis::redivis$user("levante")
  dataset <- user$dataset(glue("levante_metadata_scoring:e97h:{version}"))
  table   <- dataset$table("item_parameters:4cvk")
  out     <- table$to_tibble()
  write_rds(out, cache_path)
  out
}

# ---- Cleaning helpers -------------------------------------------------------
#
# These encode the decisions documented in 01_data_integrity, reports/, and
# tasks/. They are applied once in 00_load_data; downstream notebooks read
# the cleaned tibble.

#' Backfill `adaptive` = FALSE for the 196 documented NA rows.
#' See `reports/adaptive_missingness.html` for the diagnosis: all NA rows are
#' in early beta task_versions of Bogotá Memory and Leipzig/Western Math, and
#' trial-level theta_estimate is entirely absent → non-adaptive administration.
backfill_adaptive_na <- function(scores) {
  scores |> mutate(adaptive = if_else(is.na(adaptive), FALSE, adaptive))
}

#' Return run_ids that should be dropped from ROAR-Word due to non-engagement.
#' Rule: trial-level accuracy < 0.4 OR median RT < 500 ms. See
#' `tasks/roar_word.html`.
roar_word_engagement_drops <- function(trials,
                                       min_accuracy = 0.4,
                                       min_rt_ms = 500) {
  trials |>
    filter(task_id == "swr") |>
    group_by(run_id) |>
    summarise(
      pct_correct = mean(correct, na.rm = TRUE),
      median_rt_ms = median(rt_numeric, na.rm = TRUE),
      n_trials = n(),
      .groups = "drop"
    ) |>
    filter(pct_correct < min_accuracy | median_rt_ms < min_rt_ms) |>
    mutate(reason = case_when(
      pct_correct < min_accuracy & median_rt_ms < min_rt_ms ~ "low_acc_and_fast",
      pct_correct < min_accuracy                             ~ "low_accuracy",
      median_rt_ms < min_rt_ms                                ~ "fast_rt"
    ))
}

#' One-shot clean: apply all documented fixes. Returns a list with the cleaned
#' scores tibble and a small report tibble describing what was changed.
clean_levante_scores <- function(scores, trials = NULL) {
  scores0 <- scores
  n_adapt_na <- sum(is.na(scores0$adaptive))
  scores1 <- backfill_adaptive_na(scores0)

  if (!is.null(trials)) {
    drops <- roar_word_engagement_drops(trials)
  } else {
    drops <- tibble(run_id = character(0), reason = character(0),
                    pct_correct = numeric(0), median_rt_ms = numeric(0),
                    n_trials = integer(0))
  }
  scores2 <- scores1 |> anti_join(drops, by = "run_id")

  report <- tibble(
    step = c("adaptive_na_backfilled", "roar_word_runs_dropped"),
    n    = c(n_adapt_na, nrow(drops))
  )
  list(scores = scores2, report = report, roar_drops = drops)
}

#' Add site / dataset / task labels to a scores tibble.
label_levante_scores <- function(df) {
  df |>
    mutate(
      site_label    = factor(site,    levels = names(site_labels_named),
                             labels  = site_labels_named),
      dataset_label = factor(dataset, levels = names(dataset_labels_named),
                             labels  = dataset_labels_named)
    ) |>
    left_join(task_lookup, by = "task_id") |>
    mutate(task_category = factor(task_category, levels = task_categories_vec))
}

# ---- Plot helpers -----------------------------------------------------------

#' Age × score plot, faceted by task, coloured by site.
levante_age_score_plot <- function(df, point_alpha = 0.2, smooth = TRUE) {
  p <- ggplot(df, aes(x = age, y = score, color = site)) +
    geom_point(alpha = point_alpha, size = 0.7)
  if (smooth) {
    p <- p + geom_smooth(method = "lm", se = FALSE, linewidth = 0.7)
  }
  p +
    facet_wrap(vars(task_category, task_label), scales = "free_y") +
    scale_colour_site() +
    labs(x = "Age (years)", y = "Score", color = NULL) +
    theme(legend.position = "bottom")
}

#' Spaghetti plot of repeat measurements for a single site.
levante_spaghetti <- function(df, color_var = "adaptive") {
  ggplot(df, aes(x = age, y = score, group = user_id,
                 colour = .data[[color_var]])) +
    geom_line(alpha = 0.4) +
    geom_point(alpha = 0.4, size = 0.6) +
    facet_wrap(vars(task_category, task_label), scales = "free_y") +
    labs(x = "Age (years)", y = "IRT ability")
}
