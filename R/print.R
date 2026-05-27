
#' Print Method for Fight Predictions
#'
#' @description Custom print method to format the output of model_fight_outcome cleanly to the console using the cli package.
#' @param x An object of class \code{fight_prediction}.
#' @param ... Additional arguments passed to print.
#' @export
print.fight_prediction <- function(x, ...) {

  has_cli <- requireNamespace("cli", quietly = TRUE)

  if (has_cli) {
    cli::cli_h1("MATCHUP: {.val {x$fighter1}} vs. {.val {x$fighter2}}")
    cli::cli_text(cli::col_grey("Derived via: {x$model_name_label}"))
    cli::cli_text("")

    cli::cli_h2("Overall Win Probability")

    # Determine favored fighter to highlight green vs red
    if (x$prob_f1_wins > x$prob_f2_wins) {
      cli::cli_alert_success("{x$fighter1}: {cli::col_green(sprintf('%.2f%%', x$prob_f1_wins * 100))}")
      cli::cli_alert_danger("{x$fighter2}: {cli::col_red(sprintf('%.2f%%', x$prob_f2_wins * 100))}")
    } else {
      cli::cli_alert_danger("{x$fighter1}: {cli::col_red(sprintf('%.2f%%', x$prob_f1_wins * 100))}")
      cli::cli_alert_success("{x$fighter2}: {cli::col_green(sprintf('%.2f%%', x$prob_f2_wins * 100))}")
    }

    cli::cli_h2("Implied Fair Betting Odds (Decimal)")
    cli::cli_bullets(c(
      "*" = "{x$fighter1}: {.val {sprintf('%.2f', 1 / x$prob_f1_wins)}}",
      "*" = "{x$fighter2}: {.val {sprintf('%.2f', 1 / x$prob_f2_wins)}}"
    ))

    cli::cli_h2("Detailed Prop Probabilities")

    # Clean dataframe printing
    df_print <- x$method_probs |>
      dplyr::arrange(Fighter, Method) |>
      dplyr::mutate(estimate = sprintf("%.2f%%", estimate * 100))

    print(df_print, row.names = FALSE)
    cli::cli_text("")

  } else {
    # Fallback if cli is not installed
    cat(sprintf("\nMATCHUP: %s vs. %s [%s]\n", x$fighter1, x$fighter2, x$model_name_label))
    cat("=================================================================\n")
    cat(sprintf("Probability %s wins: %.2f%%\n", x$fighter1, x$prob_f1_wins * 100))
    cat(sprintf("Probability %s wins: %.2f%%\n", x$fighter2, x$prob_f2_wins * 100))

    cat("\n--- Implied Fair Betting Odds (Decimal) ---\n")
    cat(sprintf("%s: %.2f\n", x$fighter1, 1 / x$prob_f1_wins))
    cat(sprintf("%s: %.2f\n", x$fighter2, 1 / x$prob_f2_wins))

    cat("\n--- PREDICTED PROBABILITIES ---\n")
    print(x$method_probs |> dplyr::arrange(Fighter, Method), row.names = FALSE)
  }

  # Only render the plot if the user hasn't toggled plot_chart to FALSE
  if (x$plot_chart && !is.null(x$plot)) {
    suppressWarnings(print(x$plot))
  }

  invisible(x)
}
