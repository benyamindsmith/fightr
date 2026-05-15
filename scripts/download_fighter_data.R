# scripts/download_fighter_data.R

library(httr2)
library(jsonlite)
library(dplyr)
library(tidyr)
library(purrr)

api_url <- Sys.getenv("FIGHTER_API_URL")

dir.create("data", showWarnings = FALSE, recursive = TRUE)

request <- request(api_url)

response <- request |>
  req_perform()

json_text <- response |>
  resp_body_string()

writeLines(json_text, "data/fighter_data_raw.json")

fighter_json <- fromJSON(json_text, flatten = TRUE)

# Handle APIs that return either:
# 1. a top-level list/dataframe of fighters
# 2. a nested object like { "fighters": [...] }
if (is.data.frame(fighter_json)) {
  fighter_df <- fighter_json
} else if ("fighters" %in% names(fighter_json)) {
  fighter_df <- fighter_json$fighters
} else if ("data" %in% names(fighter_json)) {
  fighter_df <- fighter_json$data
} else {
  stop("Could not find fighter records in the API response.")
}

fighter_df <- as_tibble(fighter_df)

# Flatten any remaining list-columns
fighter_df <- fighter_df |>
  mutate(across(
    where(is.list),
    ~ map_chr(.x, function(value) {
      if (is.null(value) || length(value) == 0) {
        NA_character_
      } else if (length(value) == 1 && !is.list(value)) {
        as.character(value)
      } else {
        toJSON(value, auto_unbox = TRUE)
      }
    })
  ))

save(fighter_df, file = "data/fighter_data.RData")

message("Saved flattened fighter dataframe to data/fighter_data.RData")
message("Rows: ", nrow(fighter_df))
message("Columns: ", ncol(fighter_df))
