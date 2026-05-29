#' Analyze Fight Probabilities and Props via Multiple Statistical Frameworks
#'
#' @description
#' Predicts the probability of a win and method of victory for a matchup between two fighters.
#' It supports three statistical frameworks: a multinomial logistic regression, a Bradley-Terry
#' (Logit) network model, and a Thurstone-Mosteller (Probit) network model.
#'
#' @param fighter1 A character string of length 1 naming the first athlete.
#' @param fighter2 A character string of length 1 naming the second athlete.
#' @param method_type A character string specifying the model type. Options are:
#'   `"multinomial"`, `"bradley-terry"`, or `"thurstone-mosteller"`. Default is `"multinomial"`.
#' @param fights_data A data frame containing historical fight records. Default is `ufc_fights`.
#' @param athletes_data A data frame containing athlete statistics. Default is `ufc_athletes`.
#' @param predictors A character vector of variables to use in the model formula. If `NULL`,
#'   a robust default set is used based on the `method_type`.
#' @param plot_chart A logical indicating whether to draw the probability chart. Defaults to `TRUE`.
#'
#' @return Returns an object of class \code{fight_prediction} containing:
#'   \item{model}{The fitted model object (`multinom` or `BTm`).}
#'   \item{method_probs}{A data frame of predicted probabilities for each fighter and method of victory.}
#'   \item{plot}{The generated ggplot2 object (if ggplot2 is available).}
#'
#' @importFrom stats relevel pnorm plogis binomial as.formula
#' @importFrom cli cli_h1 cli_h2 cli_alert_info cli_alert_success cli_alert_danger cli_bullets cli_text col_grey col_green col_red
#' @export
#'
#' @examples
#' \dontrun{
#' # Standard Execution
#' model_fight_outcome("Islam Makhachev", "Alexander Volkanovski", method_type = "multinomial")
#'
#' # Assigned to a Variable (Hidden Output, can be printed later)
#' my_model <- model_fight_outcome(
#'   "Max Holloway", "Justin Gaethje",
#'   method_type = "multinomial",
#'   plot_chart = FALSE
#' )
#'
#' print(my_model)
#' }
model_fight_outcome <- function(fighter1,
                                fighter2,
                                method_type = "multinomial",
                                fights_data = ufc_fights,
                                athletes_data = ufc_athletes,
                                predictors = NULL,
                                plot_chart = TRUE) {
  # --- 1. CORE DEPENDENCIES & CHECKS ---
  stopifnot(
    is.character(fighter1),
    length(fighter1) == 1,
    is.character(fighter2),
    length(fighter2) == 1,
    is.data.frame(fights_data),
    is.data.frame(athletes_data),
    method_type %in% c("multinomial", "bradley-terry", "thurstone-mosteller")
  )

  if (!(fighter1 %in% athletes_data$name))
    stop(paste("Fighter not found:", fighter1))
  if (!(fighter2 %in% athletes_data$name))
    stop(paste("Fighter not found:", fighter2))

  # Ensure cli is available for internal logging, fallback to message if not
  has_cli <- requireNamespace("cli", quietly = TRUE)
  log_info <- function(msg)
    if (has_cli)
      cli::cli_alert_info(msg)
  else
    message("[i] ", msg)

  safe_num <- function(x) {
    if (is.character(x) ||
        is.factor(x))
      return(readr::parse_number(as.character(x)))
    return(as.numeric(x))
  }

  # --- NEW: FIX FOR R CMD CHECK ---
  # Drop any lubridate <Period> objects before running distinct()
  # This entirely prevents the `$ operator is invalid for atomic vectors` crash
  for (col in names(athletes_data)) {
    if (inherits(athletes_data[[col]], "Period")) {
      athletes_data[[col]] <- NULL
    }
  }

  clean_athletes <- athletes_data |> dplyr::distinct(name, .keep_all = TRUE)
  model_name_label <- ""
  # =========================================================================
  # METHOD 1: MULTINOMIAL LOGISTIC REGRESSION
  # =========================================================================
  if (method_type == "multinomial") {
    model_name_label <- "Multinomial Logistic Regression"
    log_info(paste("Engineering features and fitting", model_name_label, "..."))

    multinomial_fights <- fights_data |>
      dplyr::filter(
        f1_result %in% c("W", "L"),
        method %in% c(
          "KO/TKO",
          "TKO - Doctor's Stoppage",
          "Submission",
          "Decision - Unanimous",
          "Decision - Split",
          "Decision - Majority"
        )
      ) |>
      dplyr::mutate(
        fight_outcome = dplyr::case_when(
          f1_result == "W" &
            method %in% c("KO/TKO", "TKO - Doctor's Stoppage") ~ "F1_KO",
          f1_result == "W" & method == "Submission" ~ "F1_SUB",
          f1_result == "W" &
            stringr::str_detect(method, "Decision") ~ "F1_DEC",
          f1_result == "L" &
            method %in% c("KO/TKO", "TKO - Doctor's Stoppage") ~ "F2_KO",
          f1_result == "L" & method == "Submission" ~ "F2_SUB",
          f1_result == "L" &
            stringr::str_detect(method, "Decision") ~ "F2_DEC"
        ) |> as.factor()
      )

    f1_join_stats <- clean_athletes |> dplyr::rename_with( ~ paste0(., "_f1"), -name)
    f2_join_stats <- clean_athletes |> dplyr::rename_with( ~ paste0(., "_f2"), -name)

    fights_with_stats <- multinomial_fights |>
      dplyr::left_join(f1_join_stats, by = c("f1_name" = "name")) |>
      dplyr::left_join(f2_join_stats, by = c("f2_name" = "name")) |>
      tidyr::drop_na(age_f1, age_f2, weight_class_f1)

    model_data <- fights_with_stats |>
      dplyr::mutate(
        win_pct_f1 = safe_num(wins_f1) / pmax(
          safe_num(wins_f1) + safe_num(losses_f1) + safe_num(draws_f1),
          1
        ),
        win_pct_f2 = safe_num(wins_f2) / pmax(
          safe_num(wins_f2) + safe_num(losses_f2) + safe_num(draws_f2),
          1
        )
      ) |>
      dplyr::transmute(
        fight_outcome,
        weight_class    = as.factor(weight_class_f1),
        age_diff        = safe_num(age_f1) - safe_num(age_f2),
        weight_diff     = safe_num(weight_f1) - safe_num(weight_f2),
        height_diff     = safe_num(height_f1) - safe_num(height_f2),
        reach_diff      = safe_num(reach_f1) - safe_num(reach_f2),
        leg_reach_diff  = safe_num(leg_reach_f1) - safe_num(leg_reach_f2),
        # fight_time_diff = safe_num(average_fight_time_f1) - safe_num(average_fight_time_f2),
        win_pct_diff    = win_pct_f1 - win_pct_f2,
        str_landed_diff = safe_num(sig_str_landed_f1) - safe_num(sig_str_landed_f2),
        str_abs_diff    = safe_num(sig_str_absorbed_f1) - safe_num(sig_str_absorbed_f2),
        kd_avg_diff     = safe_num(knockdown_avg_f1) - safe_num(knockdown_avg_f2),
        str_def_diff    = safe_num(sig_str_defense_f1) - safe_num(sig_str_defense_f2),
        td_avg_diff     = safe_num(takedown_avg_f1) - safe_num(takedown_avg_f2),
        td_def_diff     = safe_num(takedown_defense_f1) - safe_num(takedown_defense_f2),
        sub_avg_diff    = safe_num(submission_avg_f1) - safe_num(submission_avg_f2),
        standing_pct_diff = safe_num(standing_pct_f1) - safe_num(standing_pct_f2),
        ground_pct_diff   = safe_num(ground_percent_f1) - safe_num(ground_percent_f2),
        ko_pct_diff     = safe_num(ko_tko_percent_f1) - safe_num(ko_tko_percent_f2),
        sub_pct_diff    = safe_num(sub_percent_f1) - safe_num(sub_percent_f2)
      )

    model_data$fight_outcome <- stats::relevel(model_data$fight_outcome, ref = "F1_DEC")
    numeric_cols <- sapply(model_data, is.numeric)
    model_data[numeric_cols][is.na(model_data[numeric_cols])] <- 0

    if (is.null(predictors)) {
      predictors <- c(
        "weight_class",
        "age_diff",
        "weight_diff",
        "height_diff",
        "reach_diff",
        "leg_reach_diff",
        # "fight_time_diff",
        "win_pct_diff",
        "str_landed_diff",
        "str_abs_diff",
        "kd_avg_diff",
        "str_def_diff",
        "td_avg_diff",
        "td_def_diff",
        "sub_avg_diff",
        "standing_pct_diff",
        "ground_pct_diff",
        "ko_pct_diff",
        "sub_pct_diff"
      )
    }

    formula_str <- paste("fight_outcome ~", paste(predictors, collapse = " + "))
    log_info(paste("Using formula:", formula_str))

    model_obj <- nnet::multinom(
      stats::as.formula(formula_str),
      data = model_data,
      maxit = 1500,
      trace = FALSE
    )

    f1_stats <- clean_athletes |> dplyr::filter(name == fighter1) |> dplyr::slice(1)
    f2_stats <- clean_athletes |> dplyr::filter(name == fighter2) |> dplyr::slice(1)

    f1_win_pct <- safe_num(f1_stats$wins) / max(
      safe_num(f1_stats$wins) + safe_num(f1_stats$losses) + safe_num(f1_stats$draws),
      1
    )
    f2_win_pct <- safe_num(f2_stats$wins) / max(
      safe_num(f2_stats$wins) + safe_num(f2_stats$losses) + safe_num(f2_stats$draws),
      1
    )

    matchup_data <- data.frame(
      weight_class    = factor(f1_stats$weight_class, levels = levels(model_data$weight_class)),
      age_diff        = safe_num(f1_stats$age) - safe_num(f2_stats$age),
      weight_diff     = safe_num(f1_stats$weight) - safe_num(f2_stats$weight),
      height_diff     = safe_num(f1_stats$height) - safe_num(f2_stats$height),
      reach_diff      = safe_num(f1_stats$reach) - safe_num(f2_stats$reach),
      leg_reach_diff  = safe_num(f1_stats$leg_reach) - safe_num(f2_stats$leg_reach),
      # fight_time_diff = safe_num(f1_stats$average_fight_time) - safe_num(f2_stats$average_fight_time),
      win_pct_diff    = f1_win_pct - f2_win_pct,
      str_landed_diff = safe_num(f1_stats$sig_str_landed) - safe_num(f2_stats$sig_str_landed),
      str_abs_diff    = safe_num(f1_stats$sig_str_absorbed) - safe_num(f2_stats$sig_str_absorbed),
      kd_avg_diff     = safe_num(f1_stats$knockdown_avg) - safe_num(f2_stats$knockdown_avg),
      str_def_diff    = safe_num(f1_stats$sig_str_defense) - safe_num(f2_stats$sig_str_defense),
      td_avg_diff     = safe_num(f1_stats$takedown_avg) - safe_num(f2_stats$takedown_avg),
      td_def_diff     = safe_num(f1_stats$takedown_defense) - safe_num(f2_stats$takedown_defense),
      sub_avg_diff    = safe_num(f1_stats$submission_avg) - safe_num(f2_stats$submission_avg),
      standing_pct_diff = safe_num(f1_stats$standing_pct) - safe_num(f2_stats$standing_pct),
      ground_pct_diff   = safe_num(f1_stats$ground_percent) - safe_num(f2_stats$ground_percent),
      ko_pct_diff     = safe_num(f1_stats$ko_tko_percent) - safe_num(f2_stats$ko_tko_percent),
      sub_pct_diff    = safe_num(f1_stats$sub_percent) - safe_num(f2_stats$sub_percent)
    )

    numeric_matchup_cols <- sapply(matchup_data, is.numeric)
    matchup_data[numeric_matchup_cols][is.na(matchup_data[numeric_matchup_cols])] <- 0

    preds_simple <- marginaleffects::predictions(model_obj, newdata = matchup_data) |> as.data.frame()

    plot_data <- preds_simple |>
      dplyr::mutate(
        Fighter = ifelse(grepl("F1", group), fighter1, fighter2),
        Method = dplyr::case_when(
          grepl("DEC", group) ~ "Decision",
          grepl("KO", group) ~ "KO/TKO",
          grepl("SUB", group) ~ "Submission"
        ),
        Method = factor(Method, levels = c("KO/TKO", "Submission", "Decision"))
      ) |>
      dplyr::select(Fighter, Method, estimate)

    prob_f1_wins <- sum(plot_data$estimate[plot_data$Fighter == fighter1])
    prob_f2_wins <- sum(plot_data$estimate[plot_data$Fighter == fighter2])

    # =========================================================================
    # METHOD 2: PAIRWISE COMPARISONS (Bradley-Terry, Thurstone-Mosteller)
    # =========================================================================
  } else if (method_type %in% c("bradley-terry", "thurstone-mosteller")) {
    model_name_label <- switch(method_type,
                               "bradley-terry" = "Subgraph Bradley-Terry (Logit)",
                               "thurstone-mosteller" = "Thurstone-Mosteller (Probit)")
    log_info(paste(
      "Truncating graph structures and fitting",
      model_name_label,
      "..."
    ))

    fights_base <- fights_data |>
      dplyr::transmute(
        player1 = dplyr::case_when(
          f1_result == "W" ~ f1_name,
          f2_result == "W" ~ f2_name,
          .default = ""
        ),
        player2 = dplyr::case_when(
          f1_result == "L" ~ f1_name,
          f2_result == "L" ~ f2_name,
          .default = ""
        ),
        result_val = dplyr::case_when(f1_result == "W" ~ 1, f1_result == "L" ~ -1, .default = 0)
      ) |>
      dplyr::filter(player1 != "", player2 != "")

    deg1_fights <- fights_base |> dplyr::filter(player1 %in% c(fighter1, fighter2) |
                                                  player2 %in% c(fighter1, fighter2))
    deg1_fighters <- unique(c(deg1_fights$player1, deg1_fights$player2))
    if (length(deg1_fighters) == 0)
      stop("Neither fighter features records inside historical tables.")

    deg2_fights <- fights_base |> dplyr::filter(player1 %in% deg1_fighters |
                                                  player2 %in% deg1_fighters)
    relevant_fighters <- unique(c(deg2_fights$player1, deg2_fights$player2))

    fights_subgraph <- fights_base |> dplyr::filter(player1 %in% relevant_fighters,
                                                    player2 %in% relevant_fighters)
    available_fighters <- intersect(relevant_fighters, clean_athletes$name)

    fights <- fights_subgraph |>
      dplyr::filter(player1 %in% available_fighters,
                    player2 %in% available_fighters) |>
      dplyr::mutate(
        player1 = factor(player1, levels = available_fighters),
        player2 = factor(player2, levels = available_fighters),
        match_id = factor(dplyr::row_number())
      )

    fighter_stats <- clean_athletes |>
      dplyr::filter(name %in% available_fighters) |>
      dplyr::arrange(match(name, available_fighters))

    predictors_df <- data.frame(
      age = safe_num(fighter_stats$age),
      weight = safe_num(fighter_stats$weight),
      reach = safe_num(fighter_stats$reach),
      leg_reach = safe_num(fighter_stats$leg_reach),
      height = safe_num(fighter_stats$height),
      win_pct = safe_num(fighter_stats$wins) / pmax(
        safe_num(fighter_stats$wins) + safe_num(fighter_stats$losses) + safe_num(fighter_stats$draws),
        1
      ),
      sig_str_landed = safe_num(fighter_stats$sig_str_landed),
      sig_str_absorbed = safe_num(fighter_stats$sig_str_absorbed),
      standing_pct = safe_num(fighter_stats$standing_pct),
      ground_percent = safe_num(fighter_stats$ground_percent),
      takedown_avg = safe_num(fighter_stats$takedown_avg),
      submission_avg = safe_num(fighter_stats$submission_avg),
      sig_str_defense = safe_num(fighter_stats$sig_str_defense),
      takedown_defense = safe_num(fighter_stats$takedown_defense),
      # average_fight_time = safe_num(fighter_stats$average_fight_time),
      ko_tko_win = safe_num(fighter_stats$ko_tko_win)
    )

    predictors_df[is.na(predictors_df)] <- 0
    rownames(predictors_df) <- fighter_stats$name

    link_func <- ifelse(method_type == "thurstone-mosteller", "probit", "logit")
    fights_binary <- fights |> dplyr::filter(result_val != 0)

    if (is.null(predictors)) {
      predictors <- c(
        "age",
        "weight",
        "reach",
        "leg_reach",
        "height",
        "win_pct",
        "sig_str_landed",
        "sig_str_absorbed",
        "standing_pct",
        "ground_percent",
        "takedown_avg",
        "submission_avg",
        "sig_str_defense",
        "takedown_defense",
        # "average_fight_time",
        "ko_tko_win"
      )
    }

    bt_predictors <- paste0(predictors, "[player]")
    formula_str <- paste("~", paste(bt_predictors, collapse = " + "), "+ (1 | player)")
    log_info(paste("Using formula: outcome", formula_str))

    model_obj <- BradleyTerry2::BTm(
      outcome = rep(1, nrow(fights_binary)),
      player1 = player1,
      player2 = player2,
      formula = stats::as.formula(formula_str),
      id = "player",
      data = list(fights = fights_binary, predictors = predictors_df),
      family = stats::binomial(link = link_func)
    )

    abilities <- BradleyTerry2::BTabilities(model_obj)
    lambda_f1 <- abilities[fighter1, "ability"]
    lambda_f2 <- abilities[fighter2, "ability"]

    log_odds_diff <- lambda_f1 - lambda_f2

    if (method_type == "thurstone-mosteller") {
      prob_f1_wins <- stats::pnorm(log_odds_diff)
    } else {
      prob_f1_wins <- stats::plogis(log_odds_diff)
    }
    prob_f2_wins <- 1 - prob_f1_wins

    f1_s <- fighter_stats[fighter_stats$name == fighter1, ]
    f2_s <- fighter_stats[fighter_stats$name == fighter2, ]

    f1_tw <- sum(f1_s$ko_tko_win, f1_s$sub_wins, f1_s$dec_wins, na.rm = TRUE)
    f2_tw <- sum(f2_s$ko_tko_win, f2_s$sub_wins, f2_s$dec_wins, na.rm = TRUE)

    f1_p_ko  <- if (f1_tw > 0)
      f1_s$ko_tko_win / f1_tw
    else
      0
    f1_p_sub <- if (f1_tw > 0)
      f1_s$sub_wins / f1_tw
    else
      0
    f1_p_dec <- if (f1_tw > 0)
      f1_s$dec_wins / f1_tw
    else
      0

    f2_p_ko  <- if (f2_tw > 0)
      f2_s$ko_tko_win / f2_tw
    else
      0
    f2_p_sub <- if (f2_tw > 0)
      f2_s$sub_wins / f2_tw
    else
      0
    f2_p_dec <- if (f2_tw > 0)
      f2_s$dec_wins / f2_tw
    else
      0

    plot_data <- data.frame(
      Fighter = rep(c(fighter1, fighter2), each = 3),
      Method = factor(
        rep(c("KO/TKO", "Submission", "Decision"), times = 2),
        levels = c("KO/TKO", "Submission", "Decision")
      ),
      estimate = c(
        prob_f1_wins * f1_p_ko,
        prob_f1_wins * f1_p_sub,
        prob_f1_wins * f1_p_dec,
        prob_f2_wins * f2_p_ko,
        prob_f2_wins * f2_p_sub,
        prob_f2_wins * f2_p_dec
      )
    )
  }

  # =========================================================================
  # VISUALIZATION GENERATION (But do not print yet!)
  # =========================================================================
  p1 <- NULL
  if (requireNamespace("ggplot2", quietly = TRUE)) {
    p1 <- ggplot2::ggplot(plot_data,
                          ggplot2::aes(x = Fighter, y = estimate, fill = Method)) +
      ggplot2::geom_bar(
        stat = "identity",
        position = ggplot2::position_dodge(width = 0.8),
        width = 0.7,
        color = "black",
        alpha = 0.85
      ) +
      ggplot2::scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
      ggplot2::scale_fill_manual(values = c(
        "KO/TKO" = "#d7191c",
        "Submission" = "#2b83ba",
        "Decision" = "#abdda4"
      )) +
      ggplot2::theme_minimal(base_size = 14) +
      ggplot2::labs(
        title = paste("Matchup Prop Odds Spread:\n", fighter1, "vs", fighter2),
        subtitle = paste("Derived via", model_name_label),
        x = "Fighter",
        y = "Implied Probability",
        fill = "Method of Victory"
      ) +
      ggplot2::theme(
        plot.title = ggplot2::element_text(face = "bold"),
        legend.position = "bottom",
        panel.grid.major.x = ggplot2::element_blank()
      )
  }

  # =========================================================================
  # PACKAGE OUTPUT INTO S3 CLASS
  # =========================================================================
  res <- list(
    fighter1 = fighter1,
    fighter2 = fighter2,
    model_name_label = model_name_label,
    prob_f1_wins = prob_f1_wins,
    prob_f2_wins = prob_f2_wins,
    model = model_obj,
    method_probs = plot_data,
    plot = p1,
    plot_chart = plot_chart
  )

  class(res) <- c("fight_prediction", "list")
  return(res)
}
