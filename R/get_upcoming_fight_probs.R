#' Calculate Predictive Probabilities for the Upcoming UFC Fight Card
#'
#' @description
#' Automatically identifies the next scheduled UFC event from the provided datasets
#' and calculates win probabilities and method-of-victory prop spreads (KO/TKO,
#' Submission, Decision) for every matchup on the card.
#'
#' @details
#' The function supports three modeling engines:
#' * \strong{Multinomial Logistic Regression}: Computes feature differentials (e.g., age,
#'   reach, striking defense) between paired fighters and fits a multinomial model to predict
#'   the exact method of victory.
#' * \strong{Bradley-Terry (Logit)} & \strong{Thurstone-Mosteller (Probit)}: Graph-theoretic
#'   approaches that treat the UFC roster as a network. For each fight, the engine builds a
#'   localized, 2-degree subgraph of historical opponents to estimate latent fighter "abilities"
#'   (\eqn{\lambda}). Win probabilities are derived from the difference in abilities, while
#'   method props are proportionally distributed using the fighters' historical win-method distributions.
#'
#' @param method_type A character string specifying the modeling approach. Must be one of
#'   \code{"multinomial"}, \code{"bradley-terry"}, or \code{"thurstone-mosteller"}. Default is \code{"multinomial"}.
#' @param fights_data A data frame containing historical and upcoming UFC bout records.
#'   Upcoming fights must have \code{NA} in the \code{f1_result} column.
#' @param athletes_data A data frame containing fighter biographies and aggregate statistics.
#' @param predictors A character vector of column names to use as independent variables.
#'   If \code{NULL}, a comprehensive default set of differential metrics is utilized.
#' @param plot_chart Logical. If \code{TRUE}, generates a faceted \code{ggplot2} bar chart
#'   visualizing the implied probabilities for the entire card. Default is \code{TRUE}.
#'
#' @return An S3 object of class \code{fight_prediction_card} containing:
#' \describe{
#'   \item{\code{event_title}}{String of the upcoming event name.}
#'   \item{\code{model_name_label}}{String detailing the statistical method used.}
#'   \item{\code{model}}{The final fitted model object (\code{nnet::multinom} or \code{BradleyTerry2::BTm}).}
#'   \item{\code{method_probs}}{A data frame containing the modeled probabilities for each fighter and method.}
#'   \item{\code{plot}}{A \code{ggplot2} object visualizing the card's probability spread.}
#'   \item{\code{plot_chart}}{Logical indicating if the plot was generated.}
#' }
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Run multinomial logistic regression on the upcoming card
#' card_predictions <- get_upcoming_fight_probs(
#'   method_type = "multinomial",
#'   fights_data = my_fights_df,
#'   athletes_data = my_athletes_df
#' )
#'
#' # Print CLI summary
#' print(card_predictions)
#'
#' # View the faceted probability chart
#' plot(card_predictions$plot)
#' }
get_upcoming_fight_probs <- function(method_type = "multinomial",
                                     fights_data = ufc_fights,
                                     athletes_data = ufc_athletes,
                                     predictors = NULL,
                                     plot_chart = TRUE){
  # --- 1. CORE DEPENDENCIES & CHECKS ---
  stopifnot(
    is.data.frame(fights_data),
    is.data.frame(athletes_data),
    method_type %in% c("multinomial", "bradley-terry", "thurstone-mosteller")
  )

  has_cli <- requireNamespace("cli", quietly = TRUE)

  # Dynamic headers and progress alert styles
  if (has_cli) {
    cli::cli_h1("UFC Card Probability Pipeline")
  } else {
    message("=== UFC Card Probability Pipeline ===")
  }

  safe_num <- function(x) {
    if (is.null(x) || length(x) == 0) return(NA)
    if (is.character(x) || is.factor(x)) return(readr::parse_number(as.character(x)))
    return(as.numeric(x))
  }

  # Drop any lubridate <Period> objects before running distinct()
  for (col in names(athletes_data)) {
    if (inherits(athletes_data[[col]], "Period")) {
      athletes_data[[col]] <- NULL
    }
  }

  clean_athletes <- athletes_data |> dplyr::distinct(name, .keep_all = TRUE)

  # --- 2. IDENTIFY UPCOMING CARD ---
  upcoming_events <- fights_data |> dplyr::filter(is.na(f1_result))
  if (nrow(upcoming_events) == 0) {
    if (has_cli) {
      cli::cli_abort("No upcoming fights (where {.var f1_result} is NA) found in {.arg fights_data}.")
    } else {
      stop("No upcoming fights (where f1_result is NA) found in fights_data.")
    }
  }

  next_date <- min(upcoming_events$date, na.rm = TRUE)
  upcoming_card <- upcoming_events |> dplyr::filter(date == next_date)

  event_title <- upcoming_card$event_name[1]

  if (has_cli) {
    cli::cli_alert_info("Found upcoming card: {.strong {event_title}} ({next_date})")
    cli::cli_alert_info("Processing {nrow(upcoming_card)} total scheduled matchups.")
  } else {
    message(paste("[i] Found upcoming card:", event_title, "(", next_date, ")"))
  }

  model_name_label <- ""
  plot_data <- NULL
  model_obj <- NULL

  # =========================================================================
  # METHOD 1: MULTINOMIAL LOGISTIC REGRESSION
  # =========================================================================
  if (method_type == "multinomial") {
    model_name_label <- "Multinomial Logistic Regression"
    if (has_cli) {
      cli::cli_alert_info("Engineering features and fitting {.bold {model_name_label}}...")
    }

    multinomial_fights <- fights_data |>
      dplyr::filter(
        !is.na(f1_result),
        f1_result %in% c("W", "L"),
        method %in% c(
          "KO/TKO", "TKO - Doctor's Stoppage", "Submission",
          "Decision - Unanimous", "Decision - Split", "Decision - Majority"
        )
      ) |>
      dplyr::mutate(
        fight_outcome = dplyr::case_when(
          f1_result == "W" & method %in% c("KO/TKO", "TKO - Doctor's Stoppage") ~ "F1_KO",
          f1_result == "W" & method == "Submission" ~ "F1_SUB",
          f1_result == "W" & stringr::str_detect(method, "Decision") ~ "F1_DEC",
          f1_result == "L" & method %in% c("KO/TKO", "TKO - Doctor's Stoppage") ~ "F2_KO",
          f1_result == "L" & method == "Submission" ~ "F2_SUB",
          f1_result == "L" & stringr::str_detect(method, "Decision") ~ "F2_DEC"
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
        win_pct_f1 = safe_num(wins_f1) / pmax(safe_num(wins_f1) + safe_num(losses_f1) + safe_num(draws_f1), 1),
        win_pct_f2 = safe_num(wins_f2) / pmax(safe_num(wins_f2) + safe_num(losses_f2) + safe_num(draws_f2), 1)
      ) |>
      dplyr::transmute(
        fight_outcome,
        weight_class    = as.factor(weight_class_f1),
        age_diff        = safe_num(age_f1) - safe_num(age_f2),
        weight_diff     = safe_num(weight_f1) - safe_num(weight_f2),
        height_diff     = safe_num(height_f1) - safe_num(height_f2),
        reach_diff      = safe_num(reach_f1) - safe_num(reach_f2),
        leg_reach_diff  = safe_num(leg_reach_f1) - safe_num(leg_reach_f2),
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
        "weight_class", "age_diff", "weight_diff", "height_diff", "reach_diff",
        "leg_reach_diff", "win_pct_diff", "str_landed_diff", "str_abs_diff",
        "kd_avg_diff", "str_def_diff", "td_avg_diff", "td_def_diff", "sub_avg_diff",
        "standing_pct_diff", "ground_pct_diff", "ko_pct_diff", "sub_pct_diff"
      )
    }

    formula_str <- paste("fight_outcome ~", paste(predictors, collapse = " + "))
    model_obj <- nnet::multinom(stats::as.formula(formula_str), data = model_data, maxit = 1500, trace = FALSE)

    f1_stats <- data.frame(name = upcoming_card$f1_name) |> dplyr::left_join(clean_athletes, by = "name")
    f2_stats <- data.frame(name = upcoming_card$f2_name) |> dplyr::left_join(clean_athletes, by = "name")

    f1_win_pct <- safe_num(f1_stats$wins) / pmax(safe_num(f1_stats$wins) + safe_num(f1_stats$losses) + safe_num(f1_stats$draws), 1)
    f2_win_pct <- safe_num(f2_stats$wins) / pmax(safe_num(f2_stats$wins) + safe_num(f2_stats$losses) + safe_num(f2_stats$draws), 1)

    matchup_data <- data.frame(
      weight_class    = factor(upcoming_card$weight_class, levels = levels(model_data$weight_class)),
      age_diff        = safe_num(f1_stats$age) - safe_num(f2_stats$age),
      weight_diff     = safe_num(f1_stats$weight) - safe_num(f2_stats$weight),
      height_diff     = safe_num(f1_stats$height) - safe_num(f2_stats$height),
      reach_diff      = safe_num(f1_stats$reach) - safe_num(f2_stats$reach),
      leg_reach_diff  = safe_num(f1_stats$leg_reach) - safe_num(f2_stats$leg_reach),
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

    if(any(is.na(matchup_data$weight_class))) {
      matchup_data$weight_class[is.na(matchup_data$weight_class)] <- levels(model_data$weight_class)[1]
    }

    preds_simple <- marginaleffects::predictions(model_obj, newdata = matchup_data) |> as.data.frame()

    upcoming_indexed <- upcoming_card |>
      dplyr::mutate(rowid = dplyr::row_number()) |>
      dplyr::select(rowid, f1_name, f2_name)

    plot_data <- preds_simple |>
      dplyr::left_join(upcoming_indexed, by = "rowid") |>
      dplyr::mutate(
        Matchup = paste(f1_name, "vs", f2_name),
        Fighter = ifelse(grepl("F1", group), f1_name, f2_name),
        Method = dplyr::case_when(
          grepl("DEC", group) ~ "Decision",
          grepl("KO", group) ~ "KO/TKO",
          grepl("SUB", group) ~ "Submission"
        ),
        Method = factor(Method, levels = c("KO/TKO", "Submission", "Decision"))
      ) |>
      dplyr::select(Matchup, Fighter, Method, estimate)

    if (has_cli) cli::cli_alert_success("Finished fitting Multinomial model and predicting card.")

    # =========================================================================
    # METHOD 2: PAIRWISE COMPARISONS
    # =========================================================================
  } else if (method_type %in% c("bradley-terry", "thurstone-mosteller")) {
    model_name_label <- switch(method_type,
                               "bradley-terry" = "Subgraph Bradley-Terry (Logit)",
                               "thurstone-mosteller" = "Thurstone-Mosteller (Probit)")
    if (has_cli) {
      cli::cli_alert_info("Building localized {.bold {model_name_label}} subgraphs for each matchup...")
    }

    fights_base <- fights_data |>
      dplyr::filter(!is.na(f1_result)) |>
      dplyr::transmute(
        player1 = dplyr::case_when(f1_result == "W" ~ f1_name, f2_result == "W" ~ f2_name, .default = ""),
        player2 = dplyr::case_when(f1_result == "L" ~ f1_name, f2_result == "L" ~ f2_name, .default = ""),
        result_val = dplyr::case_when(f1_result == "W" ~ 1, f1_result == "L" ~ -1, .default = 0)
      ) |>
      dplyr::filter(player1 != "", player2 != "")

    plot_data_list <- list()

    # Iterate exactly like model_fight_outcome for each fight to match the math 1:1
    for (i in seq_len(nrow(upcoming_card))) {
      f1 <- upcoming_card$f1_name[i]
      f2 <- upcoming_card$f2_name[i]
      matchup_name <- paste(f1, "vs", f2)

      # 1. Targeted Subgraph specific to just these two fighters
      deg1_fights <- fights_base |> dplyr::filter(player1 %in% c(f1, f2) | player2 %in% c(f1, f2))
      deg1_fighters <- unique(c(deg1_fights$player1, deg1_fights$player2))

      # Failsafe if we have debuting fighters
      if (length(deg1_fighters) == 0) {
        if(has_cli) cli::cli_alert_warning("No history for {.strong {matchup_name}} - assigning 50/50 probability.")
        prob_f1_wins <- 0.5
        prob_f2_wins <- 0.5
      } else {
        deg2_fights <- fights_base |> dplyr::filter(player1 %in% deg1_fighters | player2 %in% deg1_fighters)
        relevant_fighters <- unique(c(deg2_fights$player1, deg2_fights$player2))

        fights_subgraph <- fights_base |> dplyr::filter(player1 %in% relevant_fighters, player2 %in% relevant_fighters)
        available_fighters <- intersect(relevant_fighters, clean_athletes$name)

        fights <- fights_subgraph |>
          dplyr::filter(player1 %in% available_fighters, player2 %in% available_fighters) |>
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
          win_pct = safe_num(fighter_stats$wins) / pmax(safe_num(fighter_stats$wins) + safe_num(fighter_stats$losses) + safe_num(fighter_stats$draws), 1),
          sig_str_landed = safe_num(fighter_stats$sig_str_landed),
          sig_str_absorbed = safe_num(fighter_stats$sig_str_absorbed),
          standing_pct = safe_num(fighter_stats$standing_pct),
          ground_percent = safe_num(fighter_stats$ground_percent),
          takedown_avg = safe_num(fighter_stats$takedown_avg),
          submission_avg = safe_num(fighter_stats$submission_avg),
          sig_str_defense = safe_num(fighter_stats$sig_str_defense),
          takedown_defense = safe_num(fighter_stats$takedown_defense),
          ko_tko_win = safe_num(fighter_stats$ko_tko_win)
        )

        predictors_df[is.na(predictors_df)] <- 0
        rownames(predictors_df) <- fighter_stats$name

        link_func <- ifelse(method_type == "thurstone-mosteller", "probit", "logit")
        fights_binary <- fights |> dplyr::filter(result_val != 0)

        if (is.null(predictors)) {
          predictors_iter <- c(
            "age", "weight", "reach", "leg_reach", "height", "win_pct",
            "sig_str_landed", "sig_str_absorbed", "standing_pct", "ground_percent",
            "takedown_avg", "submission_avg", "sig_str_defense", "takedown_defense", "ko_tko_win"
          )
        } else {
          predictors_iter <- predictors
        }

        bt_predictors <- paste0(predictors_iter, "[player]")
        formula_str <- paste("~", paste(bt_predictors, collapse = " + "), "+ (1 | player)")

        # Fit model specific to this bout's graph
        local_model_obj <- BradleyTerry2::BTm(
          outcome = rep(1, nrow(fights_binary)),
          player1 = player1, player2 = player2,
          formula = stats::as.formula(formula_str),
          id = "player",
          data = list(fights = fights_binary, predictors = predictors_df),
          family = stats::binomial(link = link_func)
        )

        # Save the final model_obj dynamically so it can be returned inside `res`
        if(i == nrow(upcoming_card)) model_obj <- local_model_obj

        abilities <- BradleyTerry2::BTabilities(local_model_obj)
        lambda_f1 <- if(f1 %in% rownames(abilities)) abilities[f1, "ability"] else 0
        lambda_f2 <- if(f2 %in% rownames(abilities)) abilities[f2, "ability"] else 0

        log_odds_diff <- lambda_f1 - lambda_f2
        prob_f1_wins <- if (method_type == "thurstone-mosteller") stats::pnorm(log_odds_diff) else stats::plogis(log_odds_diff)
        prob_f2_wins <- 1 - prob_f1_wins
      }

      # 2. Extract specific stats for method spreads
      f1_s <- clean_athletes[clean_athletes$name == f1, ]
      f2_s <- clean_athletes[clean_athletes$name == f2, ]

      f1_tw <- sum(f1_s$ko_tko_win, f1_s$sub_wins, f1_s$dec_wins, na.rm = TRUE)
      f2_tw <- sum(f2_s$ko_tko_win, f2_s$sub_wins, f2_s$dec_wins, na.rm = TRUE)

      f1_p_ko  <- if (length(f1_tw) > 0 && f1_tw > 0) f1_s$ko_tko_win / f1_tw else 1/3
      f1_p_sub <- if (length(f1_tw) > 0 && f1_tw > 0) f1_s$sub_wins / f1_tw else 1/3
      f1_p_dec <- if (length(f1_tw) > 0 && f1_tw > 0) f1_s$dec_wins / f1_tw else 1/3

      f2_p_ko  <- if (length(f2_tw) > 0 && f2_tw > 0) f2_s$ko_tko_win / f2_tw else 1/3
      f2_p_sub <- if (length(f2_tw) > 0 && f2_tw > 0) f2_s$sub_wins / f2_tw else 1/3
      f2_p_dec <- if (length(f2_tw) > 0 && f2_tw > 0) f2_s$dec_wins / f2_tw else 1/3

      card_plot_data <- data.frame(
        Matchup = matchup_name,
        Fighter = rep(c(f1, f2), each = 3),
        Method = factor(rep(c("KO/TKO", "Submission", "Decision"), times = 2), levels = c("KO/TKO", "Submission", "Decision")),
        estimate = c(
          prob_f1_wins * f1_p_ko, prob_f1_wins * f1_p_sub, prob_f1_wins * f1_p_dec,
          prob_f2_wins * f2_p_ko, prob_f2_wins * f2_p_sub, prob_f2_wins * f2_p_dec
        )
      )
      plot_data_list[[i]] <- card_plot_data
    }


    plot_data <- dplyr::bind_rows(plot_data_list)
    ordered_matchups <- paste(upcoming_card$f1_name, "vs", upcoming_card$f2_name)

    plot_data <- plot_data |>
      dplyr::mutate(
        Matchup = factor(Matchup, levels = ordered_matchups)
      )
    if (has_cli) cli::cli_alert_success("Finished localized network estimation and prop indexing.")
  }

  # =========================================================================
  # VISUALIZATION GENERATION
  # =========================================================================
  p1 <- NULL
  if (requireNamespace("ggplot2", quietly = TRUE) && plot_chart) {
    p1 <- ggplot2::ggplot(plot_data,
                          ggplot2::aes(x = Fighter, y = estimate, fill = Method)) +
      ggplot2::geom_col(
        position = ggplot2::position_dodge(width = 0.8),
        width = 0.7,
        alpha = 0.9,
        color = "white",       # Crisp white borders separating the clustered bars
        linewidth = 0.4        # Thin, clean border lines
      ) +
      ggplot2::facet_wrap(~ Matchup, scales = "free_x", ncol = 3) +
      ggplot2::scale_y_continuous(
        labels = scales::percent_format(accuracy = 1),
        expand = ggplot2::expansion(mult = c(0, 0.15)) # Lets bars sit perfectly flush on the X-axis
      ) +
      # A more modern, muted palette (Red, Slate Blue, Teal)
      ggplot2::scale_fill_manual(values = c(
        "KO/TKO" = "#E63946",
        "Submission" = "#457B9D",
        "Decision" = "#2A9D8F"
      )) +
      ggplot2::theme_minimal(base_size = 13) +
      ggplot2::labs(
        title = paste("Matchup Prop Odds Spread:", event_title),
        subtitle = paste("Card Derived via", model_name_label),
        x = NULL,
        y = "Implied Probability",
        fill = NULL # Removes 'Method' title for a cleaner legend
      ) +
      ggplot2::theme(
        # Typography and spacing
        plot.title = ggplot2::element_text(face = "bold", size = 18, margin = ggplot2::margin(b = 5)),
        plot.subtitle = ggplot2::element_text(color = "grey40", size = 12, margin = ggplot2::margin(b = 20)),

        # Legend styling
        legend.position = "top",          # Moving legend to the top keeps the bottom edge clean
        legend.justification = "left",
        legend.key.size = ggplot2::unit(0.6, "cm"),
        legend.text = ggplot2::element_text(size = 11, face = "bold"),

        # Facet styling
        strip.text = ggplot2::element_text(face = "bold", size = 11, color = "#333333"),
        strip.background = ggplot2::element_rect(fill = "#f8f9fa", color = NA), # Subtle background box for matchup names
        panel.spacing.y = ggplot2::unit(1.5, "lines"), # Give rows room to breathe

        # Axis and Grid lines
        axis.text.x = ggplot2::element_text(face = "bold", size = 10, margin = ggplot2::margin(t = 5)),
        axis.text.y = ggplot2::element_text(color = "grey50"),
        panel.grid.major.x = ggplot2::element_blank(),
        panel.grid.minor = ggplot2::element_blank(),
        panel.grid.major.y = ggplot2::element_line(color = "grey90", linetype = "dashed")
      )
  }
  # =========================================================================
  # PACKAGE OUTPUT INTO S3 CLASS
  # =========================================================================
  res <- list(
    event_title = event_title,
    model_name_label = model_name_label,
    model = model_obj,
    method_probs = plot_data,
    plot = p1,
    plot_chart = plot_chart
  )

  class(res) <- c("fight_prediction_card", "list")
  return(res)
}
