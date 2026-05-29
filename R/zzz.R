#' @importFrom utils packageDescription
.onAttach <- function(libname, pkgname) {
  cache_dir <- tools::R_user_dir("fightr", which = "cache")

  # Update the extension to .RData
  cache_file <- file.path(cache_dir, "ufcstats_data.RData")

  if (!file.exists(cache_file)) {
    packageStartupMessage(
      "Welcome to fightr!\n",
      "It looks like you don't have the UFC datasets cached yet.\n",
      "Run `fightr::update_all_ufc_data()` to download them."
    )
  } else {
    file_age_days <- as.numeric(difftime(Sys.time(), file.info(cache_file)$mtime, units = "days"))

    if (file_age_days > 7) {
      packageStartupMessage(
        sprintf("Welcome to fightr! Your cached UFC datasets are %.0f days old.\n", file_age_days),
        "Consider running `fightr::update_all_ufc_data()` to get the latest stats."
      )
    }
  }
}
