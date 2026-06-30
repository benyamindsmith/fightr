#' Get Cached UFC Data
#'
#' Retrieves the latest UFC datasets. If the data is not cached locally, or if
#' the cached data is stale (older than 7 days), it downloads the latest .RData
#' files from GitHub.
#'
#' @param dataset Character. Which dataset to load: "ufc_athletes", "ufc_fights", "ufcstats_data", "ultimate_ufc_dataset" or "ufc_rankings_dataset".
#' @param force_update Logical. If TRUE, forces a fresh download from GitHub.
#'
#' @return A data frame of the requested dataset.
#' @export
#'
#' @examples
#' \dontrun{
#' athletes_df <- get_ufc_data("ufc_athletes")
#' fights_df <- get_ufc_data("ufc_fights", force_update = TRUE)
#' }
get_ufc_data <- function(
    dataset = c(
      "ufc_athletes",
      "ufc_fights",
      "ufcstats_data",
      "ultimate_ufc_dataset",
      "ufc_rankings_dataset"
    ),
    force_update = FALSE
) {
  dataset <- match.arg(dataset)

  urls <- c(
    ufc_athletes  = "https://raw.githubusercontent.com/benyamindsmith/fightr/main/data/ufc_athletes.RData",
    ufc_fights    = "https://raw.githubusercontent.com/benyamindsmith/fightr/main/data/ufc_fights.RData",
    ufcstats_data = "https://raw.githubusercontent.com/benyamindsmith/fightr/main/data/ufcstats_data.RData",
    ultimate_ufc_dataset = "https://raw.githubusercontent.com/benyamindsmith/fightr/main/data/ultimate_ufc_dataset.RData",
    ufc_rankings_dataset = "https://raw.githubusercontent.com/benyamindsmith/fightr/main/data/ufc_rankings_dataset.RData"
  )

  cache_dir <- tools::R_user_dir("fightr", which = "cache")

  if (!dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  }

  cache_file <- file.path(cache_dir, paste0(dataset, ".RData"))

  needs_download <- force_update || !file.exists(cache_file)

  if (!needs_download) {
    file_age_days <- as.numeric(
      difftime(Sys.time(), file.info(cache_file)$mtime, units = "days")
    )

    if (file_age_days > 7) {
      needs_download <- TRUE
    }
  }

  if (needs_download) {
    message(sprintf("Downloading the latest '%s' dataset from GitHub...", dataset))

    tmp_file <- tempfile(fileext = ".RData")
    on.exit(unlink(tmp_file), add = TRUE)

    old_timeout <- getOption("timeout")
    on.exit(options(timeout = old_timeout), add = TRUE)

    # R's default is 60 seconds; use a safer value without lowering user settings.
    options(timeout = max(300, old_timeout))

    dl_status <- tryCatch(
      utils::download.file(
        urls[[dataset]],
        destfile = tmp_file,
        mode = "wb",
        quiet = TRUE
      ),
      warning = function(w) {
        # Treat download warnings as failures because they often mean partial files.
        1
      },
      error = function(e) {
        1
      }
    )

    valid_download <- FALSE

    if (identical(dl_status, 0L) || identical(dl_status, 0)) {
      valid_download <- tryCatch({
        test_env <- new.env(parent = emptyenv())
        load(tmp_file, envir = test_env)
        length(ls(test_env)) > 0
      }, error = function(e) {
        FALSE
      })
    }

    if (valid_download) {
      ok <- file.copy(tmp_file, cache_file, overwrite = TRUE)

      if (!ok) {
        stop("Downloaded data successfully, but failed to write it to the cache.")
      }
    } else {
      if (file.exists(cache_file)) {
        warning(
          "Failed to download a valid fresh copy. ",
          "Falling back to the existing cached version."
        )
      } else {
        stop(
          "No cached data available and download failed. ",
          "Check your internet connection or try again later."
        )
      }
    }
  }

  temp_env <- new.env(parent = emptyenv())

  loaded <- tryCatch(
    load(cache_file, envir = temp_env),
    error = function(e) {
      stop(
        "Cached data file could not be loaded. ",
        "It may be corrupted. Try running again with force_update = TRUE. ",
        "Original error: ",
        conditionMessage(e),
        call. = FALSE
      )
    }
  )

  if (exists(dataset, envir = temp_env, inherits = FALSE)) {
    return(get(dataset, envir = temp_env, inherits = FALSE))
  }

  obj_names <- ls(temp_env)

  if (length(obj_names) > 0) {
    return(get(obj_names[1], envir = temp_env, inherits = FALSE))
  }

  stop("The cached .RData file appears to be empty.", call. = FALSE)
}
#' Update All Cached UFC Data
#'
#' Forces a fresh download of all three UFC datasets from GitHub and
#' updates the local package cache.
#'
#' @return Invisibly returns a list containing the file paths of the cached data.
#' @export
update_all_ufc_data <- function() {
  datasets <- c("ufc_athletes", "ufc_fights", "ufcstats_data", "ultimate_ufc_dataset", "ufc_rankings_dataset")
  paths <- list()

  for (ds in datasets) {
    get_ufc_data(dataset = ds, force_update = TRUE)
    cache_dir <- tools::R_user_dir("fightr", which = "cache")
    paths[[ds]] <- file.path(cache_dir, paste0(ds, ".rds"))
  }

  message("All UFC datasets have been successfully updated and cached.")
  invisible(paths)
}
