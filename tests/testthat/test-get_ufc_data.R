test_that("get_ufc_data validates arguments", {
  # Should fail if given a non-existent dataset name
  expect_error(
    get_ufc_data("fake_dataset"),
    "should be one of"
  )
})

test_that("get_ufc_data handles offline scenarios gracefully", {
  # This tells the CRAN test servers to skip this test entirely
  # if they are running in an offline environment.
  skip_if_offline(host = "github.com")

  # Since we are online, let's test a very quick fetch of a small file to
  # ensure the binary parsing and environment loading works.
  # Note: Testing heavy downloads on CRAN is discouraged, but ensuring the
  # function completes successfully without throwing an error is standard.

  expect_no_error({
    dat <- get_ufc_data("ufcstats_data", force_update = TRUE)
  })

  expect_true(is.data.frame(dat))
})

test_that("update_all_ufc_data returns paths invisibly", {
  skip_if_offline(host = "github.com")

  # Capture the invisible return
  res <- withVisible(update_all_ufc_data())

  expect_false(res$visible)
  expect_type(res$value, "list")
  expect_true(all(c("ufc_athletes", "ufc_fights", "ufcstats_data","ultimate_ufc_dataset","ufc_rankings_dataset") %in% names(res$value)))
})
