# 1. CRAN & Offline Protections
# These ensure your package doesn't fail CRAN checks due to network timeouts
skip_on_cran()
skip_if_offline(host = "github.com")

# 2. Fetch the Live Data
# We wrap this in suppressMessages so the test output console remains clean
suppressMessages({
  real_athletes <- fightr::get_ufc_data("ufc_athletes")
  real_fights   <- fightr::get_ufc_data("ufc_fights")
})

# --- Tests ---

test_that("model_fight_outcome validates inputs correctly with real data", {
  # Test invalid fighter names
  expect_error(
    model_fight_outcome("Islam Makhachev", "Ghost Fighter",
                        athletes_data = real_athletes, fights_data = real_fights),
    "Fighter not found: Ghost Fighter"
  )

  # Test invalid method type
  expect_error(
    model_fight_outcome("Islam Makhachev", "Alexander Volkanovski",
                        method_type = "random_forest",
                        athletes_data = real_athletes, fights_data = real_fights)
  )
})

test_that("multinomial regression executes on full dataset and returns correct structure", {
  res <- model_fight_outcome(
    "Islam Makhachev", "Alexander Volkanovski",
    method_type = "multinomial",
    athletes_data = real_athletes,
    fights_data = real_fights,
    plot_chart = FALSE
  )

  expect_s3_class(res, "fight_prediction")
  expect_equal(res$fighter1, "Islam Makhachev")
  expect_equal(res$fighter2, "Alexander Volkanovski")
  expect_equal(res$model_name_label, "Multinomial Logistic Regression")
  expect_true(is.data.frame(res$method_probs))
  expect_equal(nrow(res$method_probs), 6) # 3 methods * 2 fighters

  # Probabilities should sum to roughly 1 (accounting for floating point math)
  total_prob <- sum(res$method_probs$estimate)
  expect_true(total_prob >= 0.99 && total_prob <= 1.01)
})

test_that("bradley-terry network model executes on full dataset and returns correct structure", {
  res <- model_fight_outcome(
    "Islam Makhachev", "Alexander Volkanovski",
    method_type = "bradley-terry",
    athletes_data = real_athletes,
    fights_data = real_fights,
    plot_chart = FALSE
  )

  expect_s3_class(res, "fight_prediction")
  expect_equal(res$model_name_label, "Subgraph Bradley-Terry (Logit)")
  expect_s3_class(res$model, "BTm")

  # Ensure the estimates are generated properly
  expect_true(is.numeric(res$prob_f1_wins))
  expect_true(is.numeric(res$prob_f2_wins))
})

test_that("thurstone-mosteller network model executes on full dataset and returns correct structure", {
  res <- model_fight_outcome(
    "Islam Makhachev", "Alexander Volkanovski",
    method_type = "thurstone-mosteller",
    athletes_data = real_athletes,
    fights_data = real_fights,
    plot_chart = FALSE
  )

  expect_s3_class(res, "fight_prediction")
  expect_equal(res$model_name_label, "Thurstone-Mosteller (Probit)")

  total_win_prob <- res$prob_f1_wins + res$prob_f2_wins
  expect_equal(total_win_prob, 1)
})
