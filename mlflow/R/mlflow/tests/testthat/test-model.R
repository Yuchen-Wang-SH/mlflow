context("Model")

library("carrier")

test_that("mlflow can save model function", {
  mlflow_clear_test_dir("model")
  model <- lm(Sepal.Width ~ Sepal.Length, iris)
  fn <- crate(~ stats::predict(model, .x), model = model)
  mlflow_save_model(fn, "model")
  expect_true(dir.exists("model"))
  # Test that we can load the model back and score it.
  loaded_back_model <- mlflow_load_model("model")
  prediction <- mlflow_predict(loaded_back_model, iris)
  expect_equal(
    prediction,
    predict(model, iris)
  )
  # Test that we can score this model with RFunc backend
  temp_in_csv <- tempfile(fileext = ".csv")
  temp_in_json <- tempfile(fileext = ".json")
  temp_in_json_split <- tempfile(fileext = ".json")
  temp_out <- tempfile(fileext = ".json")
  write.csv(iris, temp_in_csv, row.names = FALSE)
  mlflow_cli("models", "predict", "-m", "model", "-i", temp_in_csv, "-o", temp_out, "-t", "csv")
  prediction <- unlist(jsonlite::read_json(temp_out))
  expect_true(!is.null(prediction))
  expect_equal(
    prediction,
    unname(predict(model, iris))
  )
  # json records
  jsonlite::write_json(iris, temp_in_json, row.names = FALSE)
  mlflow_cli("models", "predict", "-m", "model", "-i", temp_in_json, "-o", temp_out, "-t", "json",
             "--json-format", "records")
  prediction <- unlist(jsonlite::read_json(temp_out))
  expect_true(!is.null(prediction))
  expect_equal(
    prediction,
    unname(predict(model, iris))
  )
  # json split
  iris_split <- list(columns = names(iris)[1:4], index = row.names(iris),
                     data = as.matrix(iris[, 1:4]))
  jsonlite::write_json(iris_split, temp_in_json_split, row.names = FALSE)
  mlflow_cli("models", "predict", "-m", "model", "-i", temp_in_json_split, "-o", temp_out, "-t",
             "json", "--json-format", "split")
  prediction <- unlist(jsonlite::read_json(temp_out))
  expect_true(!is.null(prediction))
  expect_equal(
    prediction,
    unname(predict(model, iris))
  )
})

test_that("mlflow can log model and load it back with a uri", {
  with(run <- mlflow_start_run(), {
    model <- structure(
      list(some = "stuff"),
      class = "test"
    )
    predictor <- crate(~ mean(as.matrix(.x)), model)
    predicted <- predictor(0:10)
    expect_true(5 == predicted)
    mlflow_log_model(predictor, "model")
  })
  runs_uri <- paste("runs:", run$run_uuid, "model", sep = "/")
  loaded_model <- mlflow_load_model(runs_uri)
  expect_true(5 == mlflow_predict(loaded_model, 0:10))
  actual_uri <- paste(run$artifact_uri, "model", sep = "/")
  loaded_model_2 <- mlflow_load_model(actual_uri)
  expect_true(5 == mlflow_predict(loaded_model_2, 0:10))
  temp_in  <- tempfile(fileext = ".json")
  temp_out  <- tempfile(fileext = ".json")
  jsonlite::write_json(0:10, temp_in)
  mlflow:::mlflow_cli("models", "predict", "-m", runs_uri, "-i", temp_in, "-o", temp_out,
                      "--content-type", "json", "--json-format", "records")
  prediction <- unlist(jsonlite::read_json(temp_out))
  expect_true(5 == prediction)
  mlflow:::mlflow_cli("models", "predict", "-m", actual_uri, "-i", temp_in, "-o", temp_out,
                      "--content-type", "json", "--json-format", "records")
  prediction <- unlist(jsonlite::read_json(temp_out))
  expect_true(5 == prediction)
})
