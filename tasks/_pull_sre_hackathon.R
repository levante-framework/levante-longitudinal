# Pull SRE / PA / SWR data from the unified hackathon pilots dataset
# (levante_data_pilots_hackathon:fpx0:v1_1) using the new `levante` package,
# and cache locally for tasks/sre.qmd. Run once; triggers Redivis OAuth.

library(levante)
library(dplyr)
library(readr)

data_dir <- here::here("data")
src <- "levante_data_pilots_hackathon:fpx0"
ver <- "v1_1"

trials_file <- file.path(data_dir, "hackathon_v1_1_trials_roar.rds")
scores_file <- file.path(data_dir, "hackathon_v1_1_scores.rds")
participants_file <- file.path(data_dir, "hackathon_v1_1_participants.rds")

if (!file.exists(trials_file)) {
  trials <- get_trials(src, version = ver)
  trials |>
    filter(task_id %in% c("sre", "pa", "swr")) |>
    write_rds(trials_file, compress = "gz")
  rm(trials)
}

if (!file.exists(scores_file)) {
  get_scores(src, version = ver) |>
    write_rds(scores_file, compress = "gz")
}

if (!file.exists(participants_file)) {
  get_participants(src, version = ver) |>
    write_rds(participants_file, compress = "gz")
}

message("done: ", paste(basename(list.files(data_dir, pattern = "hackathon")), collapse = ", "))
