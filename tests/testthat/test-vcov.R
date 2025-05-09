skip_on_cran()
skip_on_os(c("mac", "solaris"))
skip_if_not_installed("sandwich")

test_that("ggpredict, vcov can be own function", {
  # example taken from "?clubSandwich::vcovCR"
  m <- 8
  cluster <- factor(rep(LETTERS[1:m], 3 + rpois(m, 5)))
  n <- length(cluster)
  X <- matrix(rnorm(3 * n), n, 3)
  nu <- rnorm(m)[cluster]
  e <- rnorm(n)
  y <- X %*% c(0.4, 0.3, -0.3) + nu + e
  dat <- data.frame(y, X, cluster, row = 1:n)

  # fit linear model
  model_vcov <- lm(y ~ X1 + X2 + X3, data = dat)
  out1 <- ggpredict(model_vcov, "X1", vcov = "HC0")
  out2 <- ggpredict(model_vcov, "X1", vcov = sandwich::vcovHC, vcov_args = list(type = "HC0"))
  expect_equal(out1$conf.low, out2$conf.low, tolerance = 1e-4)

  expect_message(
    ggeffect(model_vcov, "X1", vcov = "HC0"),
    "The following arguments are not supported"
  )

  # test clubsandwich
  skip_if_not_installed("clubSandwich")
  out1 <- ggpredict(
    model_vcov, "X1",
    vcov = clubSandwich::vcovCR,
    vcov_args = list(type = "CR0", cluster = dat$cluster)
  )
  out2 <- ggpredict(model_vcov, "X1", vcov = "CR0", vcov_args = list(cluster = dat$cluster))
  expect_equal(out1$conf.low, out2$conf.low, tolerance = 1e-4)
})


test_that("ggemmeans, vcov can be own function", {
  skip_if_not_installed("emmeans")

  # example taken from "?clubSandwich::vcovCR"
  set.seed(1234)
  m <- 8
  cluster <- factor(rep(LETTERS[1:m], 3 + rpois(m, 5)))
  n <- length(cluster)
  X <- matrix(rnorm(3 * n), n, 3)
  nu <- rnorm(m)[cluster]
  e <- rnorm(n)
  y <- X %*% c(0.4, 0.3, -0.3) + nu + e
  dat <- data.frame(y, X, cluster, row = 1:n)

  # fit linear model
  model_vcov <- lm(y ~ X1 + X2 + X3, data = dat)

  out1 <- ggemmeans(model_vcov, "X1", vcov = "HC0")
  out2 <- ggemmeans(model_vcov, "X1", vcov = sandwich::vcovHC, vcov_args = list(type = "HC0"))
  expect_equal(out1$conf.low, out2$conf.low, tolerance = 1e-4)

  out3 <- ggemmeans(model_vcov, "X1", vcov = sandwich::vcovHC(model_vcov, type = "HC0"))
  expect_equal(out1$conf.low, out3$conf.low, tolerance = 1e-4)

  data(iris)
  fit <- lm(Sepal.Length ~ Species, data = iris)
  out <- predict_response(fit, terms = "Species", margin = "marginalmeans")
  expect_equal(out$conf.low, c(4.86213, 5.79213, 6.44413), tolerance = 1e-4)
  out <- predict_response(fit, terms = "Species", vcov = "HC3", margin = "marginalmeans")
  expect_equal(out$conf.low, c(4.906485, 5.790275, 6.408479), tolerance = 1e-4)
  out2 <- predict_response(fit, terms = "Species", vcov = sandwich::vcovHC, margin = "marginalmeans")
  expect_equal(out$conf.low, out2$conf.low, tolerance = 1e-4)
  vc <- sandwich::vcovHC(fit, type = "HC3")
  out3 <- as.data.frame(emmeans::emmeans(fit, "Species", vcov = vc))
  expect_equal(out$conf.low, out3$lower.CL, tolerance = 1e-4)
})


test_that("ggpredict, CI based on robust SE", {
  data(iris)
  fit <- lm(Sepal.Length ~ Species, data = iris)
  out <- ggpredict(fit, terms = "Species", vcov = "HC1")
  expect_equal(out$conf.low, c(4.90749, 5.79174, 6.41028), tolerance = 1e-4)
  out2 <- ggpredict(fit, terms = "Species", vcov = "HC1")
  expect_equal(out$conf.low, out2$conf.low, tolerance = 1e-4)
})


test_that("ggemmeans and clubsandwich", {
  skip_if_not_installed("emmeans")
  skip_if_not_installed("clubSandwich")
  data(mtcars)
  fit <- lm(mpg ~ hp + as.factor(cyl), data = mtcars)
  mtcars$gear <- as.factor(mtcars$gear)
  out <- ggemmeans(
    fit,
    terms = "cyl",
    vcov = clubSandwich::vcovCR(fit, type = "CR0", cluster = mtcars$gear)
  )
  expect_equal(out$conf.low, c(21.60913, 17.71294, 14.6084), tolerance = 1e-4)
})


skip_if_not_installed("marginaleffects")

test_that("ggaverage, CI based on robust SE", {
  data(iris)
  fit <- lm(Sepal.Length ~ Species, data = iris)
  out <- predict_response(fit, terms = "Species", margin = "average")
  expect_equal(out$conf.low, c(4.86213, 5.79213, 6.44413), tolerance = 1e-4)
  out <- predict_response(fit, terms = "Species", vcov = "HC1", margin = "average")
  expect_equal(out$conf.low, c(4.90749, 5.79174, 6.41028), tolerance = 1e-4)
  out <- ggaverage(fit, terms = "Species", vcov = "HC1")
  expect_equal(out$conf.low, c(4.90749, 5.79174, 6.41028), tolerance = 1e-4)
})
