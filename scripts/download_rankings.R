library(httr2)
library(jsonlite)
library(dplyr)
library(tidyr)
library(purrr)

api_url <- Sys.getenv("RANKINGS_API_URL")

dir.create("data", showWarnings = FALSE, recursive = TRUE)

request <- request(api_url)

response <- request |>
  req_perform()

json_text <- response |>
  resp_body_string()

writeLines(json_text, "data/octagon_api_rankings.json")

rankings_json <- fromJSON(json_text)|>
  as_tibble()

# Handle APIs that return either:
# 1. a top-level list/dataframe of fighters
# 2. a nested object like { "fighters": [...] }
if (!is.data.frame(rankings_json)) {
  stop("Could not find rankings data in the API response.")
}


save(rankings_json, file = "data/octagon_api_rankings.RData")

message("Saved flattened rankings taframe to data/octagon_api_rankings.RData")
message("Rows: ", nrow(rankings_json))
message("Columns: ", ncol(rankings_json))
