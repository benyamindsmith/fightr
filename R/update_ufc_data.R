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
get_ufc_data <- function(dataset = c("ufc_athletes", "ufc_fights", "ufcstats_data", "ultimate_ufc_dataset", "ufc_rankings_dataset"), force_update = FALSE) {
  dataset <- match.arg(dataset)

  urls <- c(
    ufc_athletes  = "https://raw.githubusercontent.com/benyamindsmith/fightr/main/data/ufc_athletes.RData",
    ufc_fights    = "https://raw.githubusercontent.com/benyamindsmith/fightr/main/data/ufc_fights.RData",
    ufcstats_data = "https://raw.githubusercontent.com/benyamindsmith/fightr/main/data/ufcstats_data.RData",
    ultimate_ufc_dataset = "https://raw.githubusercontent.com/benyamindsmith/fightr/main/data/ultimate_ufc_dataset.RData",
    ufc_rankings_dataset = "https://raw.githubusercontent.com/benyamindsmith/fightr/main/data/ufc_rankings_dataset.RData"
  )

  # Safely create a CRAN-compliant cache directory
  cache_dir <- tools::R_user_dir("fightr", which = "cache")
  if (!dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  }

  cache_file <- file.path(cache_dir, paste0(dataset, ".RData"))

  # Determine if a download is necessary
  needs_download <- force_update || !file.exists(cache_file)

  if (!needs_download) {
    file_age_days <- as.numeric(difftime(Sys.time(), file.info(cache_file)$mtime, units = "days"))
    if (file_age_days > 7) {
      needs_download <- TRUE
    }
  }

  # Download if necessary
  if (needs_download) {
    message(sprintf("Downloading the latest '%s' dataset from GitHub...", dataset))

    # Use mode = "wb" (write binary) - CRITICAL for .RData files, especially on Windows
    dl_status <- tryCatch({
      download.file(urls[[dataset]], destfile = cache_file, mode = "wb", quiet = TRUE)
    }, error = function(e) {
      return(1) # Return non-zero status on error
    })

    if (dl_status != 0) {
      if (file.exists(cache_file)) {
        warning("Failed to download data. Falling back to the older cached version.")
      } else {
        stop("No cached data available and download failed. Check your internet connection.")
      }
    }
  }

  # Safely load the .RData file into an isolated environment
  temp_env <- new.env()
  load(cache_file, envir = temp_env)

  # Extract the object and return it
  # Assuming the object inside the .RData file is named the same as the dataset
  if (exists(dataset, envir = temp_env)) {
    dat <- get(dataset, envir = temp_env)
    return(dat)
  } else {
    # Fallback: if the object name differs, just grab the first object in the file
    obj_names <- ls(temp_env)
    if (length(obj_names) > 0) {
      return(get(obj_names[1], envir = temp_env))
    } else {
      stop("The cached .RData file appears to be empty.")
    }
  }
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
    cache_dir <- tools::R_user_dir("YourPackageName", which = "cache")
    paths[[ds]] <- file.path(cache_dir, paste0(ds, ".rds"))
  }

  message("All UFC datasets have been successfully updated and cached.")
  invisible(paths)
}
