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

writeLines(json_text, "data/octagon_api_fighters.json")

octagon_api_fighters <- fromJSON(json_text)|>
  imap_dfr(function(x, id) {
    x |>
      map_chr(~ if (length(.x) == 0) NA_character_ else as.character(.x[[1]])) |>
      as.list() |>
      as_tibble() |>
      mutate(fighter_id = id, .before = 1)
  })


# Handle APIs that return either:
# 1. a top-level list/dataframe of fighters
# 2. a nested object like { "fighters": [...] }
if (!is.data.frame(fighter_json)) {
  stop("Could not find fighter records in the API response.")
}


save(fighter_json, file = "data/octagon_api_fighters.RData")

message("Saved flattened fighter dataframe to data/octagon_api_fighters.RData")
message("Rows: ", nrow(fighter_json))
message("Columns: ", ncol(fighter_json))
