# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Git Commits

Do not commit changes to git. The user handles all commits.

## Project Overview

This is an R research compendium for Bayesian capture-mark-recapture (CMR) analyses of mountain yellow-legged frog populations. Each frog population is referenced only by a 5-digit site ID — no names or coordinates appear anywhere in the code or data. The core analysis package is [`mrmr`](https://github.com/SNARL1/mrmr), which wraps Stan models via `cmdstanr`.

## Two-Step Workflow Per Population

Every population has two paired scripts:

1. **`{site_id}_createdata_mrmr.{Rmd|qmd}`** — pulls raw data from a PostgreSQL database (`amphibians`), error-checks it, and writes cleaned CSVs to `data/clean/`.
2. **`{site_id}_analysis_mrmr.{Rmd|qmd}`** — reads the cleaned CSVs, calls `mrmr::clean_data()` and `mrmr::fit_model()`, diagnostics, and writes plots/model objects to `out/`.

Templates for new sites are in `code/template_createdata_mrmr.Rmd` and `code/template_analysis_mrmr.Rmd`. Replace all `xxxxx` placeholders with the target site ID. Newer sites use `.qmd` format instead of `.Rmd`.

Some sites (e.g., 22008) have `_2groups` / `_3groups` variants where frogs are split into treatment cohorts; these produce separate clean data files with suffixes in `data/clean/`.

## Data Files

`data/clean/` contains one set per population:
- `{site_id}_survey.csv` — primary/secondary period structure
- `{site_id}_capture.csv` — PIT tag records per survey date
- `{site_id}_translocation.csv` or `{site_id}_reintroduction.csv` — release events (only when applicable)

Raw data files are not committed (they expose sensitive location information). Cleaned files are committed so analyses can run without database access.

## Database Connection

`createdata` scripts connect to a PostgreSQL database (`amphibians`). Connection profiles are in `config.yml`. The typical workflow when accessing remotely is to open an SSH tunnel first, then connect using the `slip-eri` or `amphibians-eri` profile. The newer `.qmd` createdata files use `pgutils::connect_to_pg()` (from GitHub package `SNARL1/pgutils`). Older `.Rmd` files use `RPostgreSQL::dbConnect()` with credentials from `Sys.getenv()` (host, port, dbname) plus `rstudioapi::askForPassword()`.

Users without database access can work with the committed clean CSVs directly and skip the createdata step.

## Database Schema (amphibians v2, revised May 2026)

See `doc/amphibians_v2_field_surveys_erd.png` for the full ERD. The tables most relevant to `createdata` scripts are:

**Survey hierarchy** (`site` → `visit` → `survey`):
- `site` — site metadata; join key is `site_id`
- `visit` — one row per site visit (`visit_id`, `site_id`, `visit_date`, `visit_status`, `visit_type`)
- `survey` — one row per survey event within a visit (`survey_id`, `visit_id`, `survey_type`, environmental conditions)

**Capture data**:
- `capture_survey` — one row per frog captured (`capture_survey_id`, `survey_id`, `pit_tag_ref`, `tag_new`, `species`, `capture_life_stage`, `sex`, `length`, `weight`, `swab_id`, `surveyor_id`)

**Release/reintroduction data** (replaces old `relocate`/`relocate_frog` tables):
- `release` — one row per release event (`release_id`, `visit_id`, `release_type`, `species`, `release_life_stage`, `release_count`)
- `release_frog` — one row per individual released (`release_frog_id`, `release_id`, `collect_id`, `pit_tag_ref`, `tag_new`, `sex`, `length`, `weight`, `swab_id`, `bd_exposure`, `surveyor_id`)

**Collection source** (frogs collected from donor sites):
- `collect` — one collection event (`collect_id`, `collect_type`, `species`, `collect_life_stage`, `collect_count`)
- `collect_release` — junction table linking `collect` to `release`
- `visit_collect` — junction table linking `visit` to `collect`

**Supporting tables**: `surveyor` (surveyor_id, surveyor_name), `survey_surveyor` (junction), `visual_survey` (count-based observations), `bd_load` (Bd qPCR results).

**Important**: Older `createdata` scripts (`.Rmd` files) query the previous schema using `relocate` and `relocate_frog` tables. New and updated scripts (`.qmd` files) use `release` and `release_frog`. When updating or creating scripts, use the v2 schema.

## Key R Packages

- `mrmr` (GitHub: SNARL1/mrmr) — CMR model fitting and visualization
- `cmdstanr` + CmdStan — Stan backend for MCMC
- `pgutils` (GitHub: SNARL1/pgutils) — database helpers used in newer `.qmd` files
- `here` — all file paths use `here::here()` anchored at the project root
- `tidyverse`, `lubridate`, `assertthat` — data wrangling and validation

Install non-CRAN packages:
```r
remotes::install_github("SNARL1/mrmr")
remotes::install_github("SNARL1/pgutils")
install.packages("cmdstanr", repos = c("https://mc-stan.org/r-packages/", getOption("repos")))
cmdstanr::install_cmdstan()
```

## Running Analyses

Run scripts interactively chunk-by-chunk in RStudio (output: `html_notebook`) or render with:
```r
rmarkdown::render("code/{site_id}_analysis_mrmr.Rmd")
# or for .qmd files:
quarto::quarto_render("code/{site_id}_analysis_mrmr.qmd")
```

The `fit_model()` call is the slow step. Typical runtimes are 5–30 minutes on 8 cores/32 GB RAM. Site 70550 is the exception — it requires 256 GB RAM and ~6 hours on 16 cores.

Model fit objects are saved as compressed `.rds` files in `out/model/` via:
```r
write_rds(model_xxxxx, here::here("out", "model", "xxxxx_model.rds"), "xz", compression = 9L)
```

## Output Directories

- `out/model/` — compressed model `.rds` files
- `out/plots/` — survival, abundance, and recruitment plots
- `out/tables/` — per-cohort and per-individual survival CSVs
- `doc/notebook/` — `notebook_results.Rmd` / `.md` summarizing all populations

## Docker Alternative

The full environment is available as a Docker image:
```bash
docker run -e PASSWORD=yourpassword --rm -p 8787:8787 rolandknapp/cmr-analysis
```
Access at `http://localhost:8787` (user: `rstudio`).
