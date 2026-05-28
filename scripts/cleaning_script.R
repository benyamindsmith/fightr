# Cleaning Scripts
ufc_athletes <- readr::read_csv("data/ufc_athletes.csv", show_col_types = FALSE)
ufc_fights   <- readr::read_csv("data/ufc_fights.csv",   show_col_types = FALSE)
ufcstats_data <- readr::read_csv("data/ufcstats_data.csv", show_col_types = FALSE)

ufc_athletes<-ufc_athletes|>
  dplyr::mutate(
    Record = trimws(Record),
    Wins = stringr::str_extract(Record, "^(\\d+)-\\d+-\\d+",group=1),
    Losses = stringr::str_extract(Record, "^\\d+-(\\d+)-\\d+",group=1),
    Draws = stringr::str_extract(Record, "^\\d+-\\d+-(\\d+)",group=1),
    `Sig. Str. Defense` = stringr::str_remove(`Sig. Str. Defense`, ' ')|>
      readr::parse_number()*0.01,
    `Takedown Defense` = stringr::str_remove(`Takedown Defense`, ' ')|>
      readr::parse_number()*0.01,
    `Average fight time` = lubridate::ms(`Average fight time` ),
    `Standing Count` = readr::parse_number(Standing),
    `Standing Pct` = stringr::str_extract(Standing, "\\((\\d+)\\s*%\\)", group = 1) |>
      readr::parse_number() * 0.01,

    `Clinch Count` = readr::parse_number(Clinch),
    `Clinch %`= stringr::str_extract(Clinch, "\\((\\d+)\\s*%\\)", group = 1) |>
      readr::parse_number() * 0.01,

    `Ground Count` = readr::parse_number(Ground),
    `Ground %` = stringr::str_extract(Ground, "\\((\\d+)\\s*%\\)", group = 1) |>
      readr::parse_number() * 0.01,
    `Octagon Debut` = stringr::str_remove_all(`Octagon Debut`, "\\.") |>
      lubridate::mdy(),
    `KO/TKO Win` = readr::parse_number(`KO/TKO`),
    `KO/TKO %` = stringr::str_extract(`KO/TKO`, "\\((\\d+)\\s*%\\)", group = 1) |>
      readr::parse_number() * 0.01,

    `DEC Wins` = readr::parse_number(DEC),
    `DEC %` = stringr::str_extract(DEC, "\\((\\d+)\\s*%\\)", group = 1) |>
      readr::parse_number() * 0.01,

    `SUB Wins` = readr::parse_number(SUB),
    `SUB %` = stringr::str_extract(SUB, "\\((\\d+)\\s*%\\)", group = 1) |>
      readr::parse_number() * 0.01
  )|>
  dplyr::select(!c(Record, Standing, Clinch, Ground, `KO/TKO`, DEC, SUB ))|>
  janitor::clean_names()


ufc_fights <-ufc_fights |>
  # 1. Standardize missing values
  dplyr::mutate(
    dplyr::across(
      dplyr::where(is.character),
      \(x) dplyr::na_if(x, "---") |>
        dplyr::na_if("--") |>
        dplyr::na_if("<NA>")
    )
  ) |>
  # 2. Parse Dates and Times safely
  dplyr::mutate(
    date = lubridate::mdy(date),
    time = lubridate::ms(time),
    # f1_ctrl_total = lubridate::ms(f1_ctrl_total),
    # f2_ctrl_total = lubridate::ms(f2_ctrl_total),

    # 3. Parse Percentages
    dplyr::across(
      dplyr::ends_with("_pct_total"),
      \(x) readr::parse_number(x) * 0.01
    )
  ) |>
  # 4. Dynamically split the fractional strike counts
  tidyr::separate_wider_delim(
    cols = dplyr::where(\(x) any(stringr::str_detect(x, " of "), na.rm = TRUE)),
    delim = " of ",
    names_sep = "_",
    too_few = "align_start"
  ) |>
  # 5. Clean up names
  dplyr::rename_with(~ stringr::str_replace(.x, "_1$", "_succ")) |>
  dplyr::rename_with(~ stringr::str_replace(.x, "_2$", "_att")) |>
  # 6. Extract digits safely to bypass coercion warnings
  dplyr::mutate(
    dplyr::across(
      dplyr::ends_with(c("_succ", "_att")),
      \(x) as.numeric(stringr::str_extract(x, "\\d+"))
    )
  )|>
  janitor::clean_names()

ufcstats_data<- ufcstats_data |>
  # 1. Standardize missing values across all character columns first
  dplyr::mutate(
    dplyr::across(
      dplyr::where(is.character),
      \(x) dplyr::na_if(x, "---") |>
        dplyr::na_if("--") |>
        dplyr::na_if("<NA>") |>
        dplyr::na_if("")
    )
  ) |>
  dplyr::mutate(
    # 2. Parse Date of Birth safely
    DOB = lubridate::mdy(DOB),

    # 3. Clean string measurements into pure numerics
    # readr::parse_number() automatically strips " lbs." and """ (quotes)
    Weight = readr::parse_number(Weight),
    Reach = readr::parse_number(Reach),

    # 4. Convert Height (e.g., "5' 11\"") to total inches
    # Extracts the first digit (feet) * 12, then adds the digit before the quote (inches)
    Height = (as.numeric(stringr::str_extract(Height, "^\\d+")) * 12) +
      as.numeric(stringr::str_extract(Height, "\\d+(?=\")")),

    # 5. Parse Percentage metrics (converts "55%" to 0.55)
    dplyr::across(
      c(`Str. Acc.`, `Str. Def.`, `TD Acc.`, `TD Def.`),
      \(x) readr::parse_number(x) * 0.01
    ),

    # 6. Ensure per-minute and average metrics are numeric (if imported as character)
    dplyr::across(
      c(SLpM, SApM, `TD Avg.`, `Sub. Avg.`),
      as.numeric
    )
  )|>
  janitor::clean_names()

save(ufc_athletes,  file = "data/ufc_athletes.RData")
save(ufc_fights,    file = "data/ufc_fights.RData")
save(ufcstats_data, file = "data/ufcstats_data.RData")
