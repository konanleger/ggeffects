skip_on_cran()
skip_on_os(c("mac", "solaris"))

skip_if_not_installed("glmmTMB")
skip_if_not_installed("marginaleffects")
skip_if_not_installed("lme4")
skip_if_not_installed("emmeans")
skip_if_not_installed("withr")

withr::with_options(
  list(ggeffects_warning_bias_correction = FALSE),
  test_that("validate ggpredict against predict, nbinom", {
    data(Owls, package = "glmmTMB")
    data(Salamanders, package = "glmmTMB")
    m1 <- suppressWarnings(glmmTMB::glmmTMB(
      SiblingNegotiation ~ SexParent + ArrivalTime + (1 | Nest),
      data = Owls,
      family = glmmTMB::nbinom1()
    ))
    m2 <- glmmTMB::glmmTMB(
      SiblingNegotiation ~ SexParent + ArrivalTime + (1 | Nest),
      data = Owls,
      family = glmmTMB::nbinom2()
    )
    m4 <- glmmTMB::glmmTMB(
      SiblingNegotiation ~ FoodTreatment + ArrivalTime + SexParent + (1 | Nest),
      data = Owls,
      ziformula = ~1,
      family = glmmTMB::truncated_poisson(link = "log")
    )
    nd <- data_grid(m1, "SexParent")
    pr <- predict(m1, newdata = nd, type = "link", se.fit = TRUE)
    linv <- insight::link_inverse(m1)
    dof <- insight::get_df(m1, type = "wald", verbose = FALSE)
    tcrit <- stats::qt(0.975, df = dof)

    out1 <- data.frame(
      predicted = linv(pr$fit),
      conf.low = linv(pr$fit - tcrit * pr$se.fit),
      conf.high = linv(pr$fit + tcrit * pr$se.fit)
    )
    out2 <- ggpredict(m1, "SexParent")

    expect_equal(out1$predicted, out2$predicted, tolerance = 1e-4, ignore_attr = TRUE)
    expect_equal(out1$conf.low, out2$conf.low, tolerance = 1e-4, ignore_attr = TRUE)
    expect_equal(out1$conf.high, out2$conf.high, tolerance = 1e-4, ignore_attr = TRUE)

    expect_s3_class(ggpredict(m1, c("ArrivalTime", "SexParent")), "data.frame")
    expect_s3_class(ggpredict(m2, c("ArrivalTime", "SexParent")), "data.frame")
    expect_s3_class(ggpredict(m4, c("FoodTreatment", "ArrivalTime [21,24,30]", "SexParent")), "data.frame") # nolint
    expect_s3_class(
      ggpredict(m1, c("ArrivalTime", "SexParent"), type = "random", verbose = FALSE),
      "data.frame"
    )
    expect_s3_class(
      ggpredict(m4, c("FoodTreatment", "ArrivalTime [21,24,30]", "SexParent"), type = "random", verbose = FALSE), # nolint
      "data.frame"
    )

    expect_message(ggpredict(m1, c("ArrivalTime", "SexParent"), type = "zero_inflated"))

    p1 <- ggpredict(m1, c("ArrivalTime", "SexParent"))
    p2 <- ggpredict(m2, c("ArrivalTime", "SexParent"))
    p3 <- ggemmeans(m1, c("ArrivalTime", "SexParent"))
    p4 <- ggemmeans(m2, c("ArrivalTime", "SexParent"))
    expect_equal(p1$predicted[1], p3$predicted[1], tolerance = 1e-3)
    expect_equal(p2$predicted[1], p4$predicted[1], tolerance = 1e-3)

    # test messages for unit- and population level predictions
    expect_message(
      predict_response(m1, "Nest"),
      regex = "All focal terms are included"
    )
    expect_message(
      predict_response(m1, "SexParent", type = "random"),
      regex = "It seems that unit-level predictions"
    )
  })
)


withr::with_options(
  list(ggeffects_warning_bias_correction = FALSE),
  test_that("validate ggpredict lmer against marginaleffects", {
    data(Owls, package = "glmmTMB")
    m1 <- suppressWarnings(glmmTMB::glmmTMB(
      SiblingNegotiation ~ SexParent + ArrivalTime + (1 | Nest),
      data = Owls,
      family = glmmTMB::nbinom1()
    ))
    out1 <- suppressWarnings(marginaleffects::predictions(
      m1,
      variables = "SexParent",
      newdata = marginaleffects::datagrid(m1),
      vcov = FALSE,
      re.form = NULL
    ))
    out1 <- out1[order(out1$SexParent), ]
    out2 <- ggpredict(
      m1,
      "SexParent",
      condition = c(Nest = "Oleyes"),
      type = "random",
      verbose = FALSE
    )
    expect_equal(
      out1$estimate,
      out2$predicted,
      tolerance = 1e-4,
      ignore_attr = TRUE
    )
  })
)


data(Salamanders, package = "glmmTMB")

m3 <- glmmTMB::glmmTMB(
  count ~ spp + mined + (1 | site),
  ziformula = ~ spp + mined,
  family = glmmTMB::truncated_poisson(),
  data = Salamanders
)
m4 <- glmmTMB::glmmTMB(
  count ~ spp + mined + (1 | site),
  ziformula = ~ spp + mined + (1 | site),
  family = glmmTMB::truncated_poisson(),
  data = Salamanders
)
m5 <- glmmTMB::glmmTMB(
  count ~ spp + mined + cover + (1 | site),
  ziformula = ~ spp + mined,
  family = glmmTMB::truncated_poisson(),
  data = Salamanders
)

test_that("ggpredict, glmmTMB", {
  p1 <- ggpredict(m3, "mined", type = "fixed", verbose = FALSE)
  p2 <- ggpredict(m3, "mined", type = "zero_inflated", verbose = FALSE)
  p3 <- ggpredict(m3, "mined", interval = "prediction", verbose = FALSE)
  p4 <- ggpredict(m3, "mined", type = "zero_inflated", interval = "prediction", verbose = FALSE)
  expect_gt(p3$conf.high[1], p1$conf.high[1])
  expect_gt(p4$conf.high[1], p2$conf.high[1])
  expect_s3_class(ggpredict(m3, "mined", type = "zero_inflated", verbose = FALSE), "data.frame")
})


test_that("ggpredict and ggaverage, glmmTMB", {
  data(Salamanders, package = "glmmTMB")
  mx <- glmmTMB::glmmTMB(
    count ~ mined + (1 | site),
    ziformula = ~mined,
    family = poisson(),
    data = Salamanders
  )
  # make sure that "type" arguments return the same results
  p1 <- ggpredict(mx, "mined", verbose = FALSE)
  p2 <- ggaverage(mx, "mined", verbose = FALSE)
  expect_equal(p1$predicted, p2$predicted, tolerance = 0.1)

  p1 <- ggpredict(mx, "mined", type = "fixed", verbose = FALSE)
  p2 <- ggaverage(mx, "mined", type = "fixed", verbose = FALSE)
  expect_equal(p1$predicted, p2$predicted, tolerance = 0.1)

  p1 <- ggpredict(mx, "mined", type = "zero_inflated", verbose = FALSE)
  p2 <- ggaverage(mx, "mined", type = "zero_inflated", verbose = FALSE)
  expect_equal(p1$predicted, p2$predicted, tolerance = 0.1)

  p1 <- ggpredict(mx, "mined", type = "zi_prob", verbose = FALSE)
  p2 <- ggaverage(mx, "mined", type = "zi_prob", verbose = FALSE)
  expect_equal(p1$predicted, p2$predicted, tolerance = 0.1)
})


test_that("ggpredict, glmmTMB", {
  p1 <- ggpredict(m5, c("mined", "spp", "cover"), type = "fixed", verbose = FALSE)
  p3 <- ggemmeans(m5, c("mined", "spp", "cover"), type = "fixed", verbose = FALSE)
  expect_equal(p1$predicted[1], p3$predicted[1], tolerance = 1e-3)
})


test_that("ggpredict, glmmTMB", {
  p1 <- ggpredict(m3, "mined", type = "fixed", verbose = FALSE)
  p2 <- ggpredict(m3, c("mined", "spp"), type = "zero_inflated", verbose = FALSE)
  p3 <- ggemmeans(m3, "mined", type = "fixed", condition = c(spp = "GP"), verbose = FALSE)
  p4 <- ggemmeans(m3, c("mined", "spp"), type = "zero_inflated", verbose = FALSE)
  p5 <- ggpredict(m3, c("mined", "spp"), type = "fixed", verbose = FALSE)
  p6 <- ggemmeans(m3, c("mined", "spp"), type = "fixed", verbose = FALSE)
  expect_equal(p1$predicted[1], p3$predicted[1], tolerance = 1e-3)
  # expect_equal(p2$predicted[1], p4$predicted[1], tolerance = 1e-3)
  expect_equal(p5$predicted[1], p6$predicted[1], tolerance = 1e-3)
})

test_that("ggpredict, glmmTMB", {
  skip_on_os("linux")
  set.seed(123)
  out <- ggemmeans(m3, "mined", type = "zero_inflated", verbose = FALSE)
  expect_equal(out$conf.low, c(0.04904, 1.31134), tolerance = 1e-1)
  set.seed(123)
  out1 <- ggpredict(m3, "mined", type = "simulate", verbose = FALSE)
  out2 <- ggaverage(m3, "mined", type = "response", verbose = FALSE)
  expect_equal(out1$predicted, out2$predicted, tolerance = 1e-2)
})

test_that("ggpredict, glmmTMB", {
  p1 <- ggpredict(m4, "mined", type = "fixed", verbose = FALSE)
  p2 <- ggpredict(m4, "mined", type = "zero_inflated", verbose = FALSE)
  p3 <- ggpredict(m4, "mined", interval = "prediction", verbose = FALSE)
  p4 <- ggpredict(m4, "mined", type = "zero_inflated", interval = "prediction", verbose = FALSE)
  expect_gt(p3$conf.high[1], p1$conf.high[1])
  expect_gt(p4$conf.high[1], p2$conf.high[1])

  p1 <- ggpredict(m4, c("spp", "mined"), type = "fixed", verbose = FALSE)
  p2 <- ggpredict(m4, c("spp", "mined"), type = "zero_inflated", verbose = FALSE)
  p3 <- ggpredict(m4, c("spp", "mined"), interval = "prediction", verbose = FALSE)
  p4 <- ggpredict(m4, c("spp", "mined"), type = "zero_inflated", interval = "prediction", verbose = FALSE)
  expect_gt(p3$conf.high[1], p1$conf.high[1])
  expect_gt(p4$conf.high[1], p2$conf.high[1])
})


test_that("ggpredict, glmmTMB", {
  p <- ggpredict(m3, "spp", type = "zero_inflated", verbose = FALSE)
  expect_true(all(p$conf.low > 0))
  set.seed(100)
  p <- ggpredict(m3, "spp", type = "zero_inflated", verbose = FALSE)
  expect_true(all(p$conf.low > 0))
})


test_that("ggpredict, glmmTMB-simulate", {
  expect_s3_class(ggpredict(m3, "mined", type = "simulate"), "data.frame")
  expect_s3_class(ggpredict(m3, c("spp", "mined"), type = "simulate"), "data.frame")
  expect_s3_class(ggpredict(m4, "mined", type = "simulate"), "data.frame")
  expect_s3_class(ggpredict(m4, c("spp", "mined"), type = "simulate"), "data.frame")
})


test_that("ggpredict, glmmTMB", {
  data(Salamanders, package = "glmmTMB")
  md <- glmmTMB::glmmTMB(
    count ~ spp + mined + (1 | site),
    ziformula = ~ spp + mined,
    dispformula = ~DOY,
    family = glmmTMB::truncated_poisson(),
    data = Salamanders
  )
  p1 <- ggpredict(md, c("spp", "mined"), type = "fixed", verbose = FALSE)
  p2 <- ggpredict(md, c("spp", "mined"), type = "zero_inflated", verbose = FALSE)
  p3 <- suppressWarnings(ggpredict(md, c("spp", "mined"), interval = "prediction", verbose = FALSE))
  p4 <- suppressWarnings(ggpredict(md, c("spp", "mined"), interval = "prediction", verbose = FALSE))
  expect_gt(p3$conf.high[1], p1$conf.high[1])
  expect_gt(p4$conf.high[1], p2$conf.high[1])
})


test_that("ggpredict, glmmTMB", {
  data(efc_test)
  m5 <- glmmTMB::glmmTMB(
    negc7d ~ c12hour + e42dep + c161sex + c172code + (1 | grp),
    data = efc_test, ziformula = ~c172code,
    family = binomial(link = "logit")
  )
  expect_s3_class(ggpredict(m5, "c161sex", type = "fixed", verbose = FALSE), "data.frame")
  expect_s3_class(ggpredict(m5, "c161sex", type = "zero_inflated", verbose = FALSE), "data.frame")
  expect_s3_class(ggpredict(m5, "c161sex", type = "random", verbose = FALSE), "data.frame")
  expect_s3_class(ggpredict(m5, "c161sex", type = "zero_inflated_random", verbose = FALSE), "data.frame")
})


test_that("validate ggpredict against predict, binomial", {
  data(efc_test)
  m6 <- glmmTMB::glmmTMB(
    negc7d ~ c12hour + e42dep + c161sex + c172code + (1 | grp),
    data = efc_test,
    family = binomial(link = "logit")
  )
  expect_s3_class(ggpredict(m6, "c161sex", type = "fixed", verbose = FALSE), "data.frame")
  expect_s3_class(ggpredict(m6, "c161sex", type = "random", verbose = FALSE), "data.frame")

  nd <- data_grid(m6, "e42dep")
  pr <- predict(m6, newdata = nd, type = "link", se.fit = TRUE)
  linv <- insight::link_inverse(m6)
  dof <- insight::get_df(m6, type = "wald", verbose = FALSE)
  tcrit <- stats::qt(0.975, df = dof)
  out1 <- data.frame(
    predicted = linv(pr$fit),
    conf.low = linv(pr$fit - tcrit * pr$se.fit),
    conf.high = linv(pr$fit + tcrit * pr$se.fit)
  )
  out2 <- ggpredict(m6, "e42dep")

  expect_equal(out1$predicted, out2$predicted, tolerance = 1e-4, ignore_attr = TRUE)
  expect_equal(out1$conf.low, out2$conf.low, tolerance = 1e-4, ignore_attr = TRUE)
  expect_equal(out1$conf.high, out2$conf.high, tolerance = 1e-4, ignore_attr = TRUE)
})


test_that("ggpredict, glmmTMB", {
  data(efc_test)
  efc_test$tot_sc_e <- as.numeric(efc_test$tot_sc_e)
  efc_test$c172code <- as.factor(efc_test$c172code)
  m7 <- glmmTMB::glmmTMB(
    tot_sc_e ~ neg_c_7 * c172code + c161sex + (1 | grp),
    data = efc_test, ziformula = ~c172code,
    family = glmmTMB::nbinom1()
  )
  expect_s3_class(ggpredict(m7, "neg_c_7"), "data.frame")
  expect_s3_class(ggpredict(m7, "neg_c_7 [all]"), "data.frame")
  expect_s3_class(ggpredict(m7, "neg_c_7", type = "zero_inflated"), "data.frame")
  expect_s3_class(ggpredict(m7, "neg_c_7 [all]", type = "zero_inflated"), "data.frame")

  expect_s3_class(ggpredict(m7, c("neg_c_7", "c172code")), "data.frame")
  expect_s3_class(ggpredict(m7, c("neg_c_7 [all]", "c172code")), "data.frame")
  expect_s3_class(ggpredict(m7, c("neg_c_7", "c172code"), type = "zero_inflated"), "data.frame")
  expect_s3_class(ggpredict(m7, c("neg_c_7 [all]", "c172code"), type = "zero_inflated"), "data.frame")
})


test_that("ggpredict, glmmTMB", {
  data(efc_test)
  efc_test$tot_sc_e <- as.numeric(efc_test$tot_sc_e)
  efc_test$c172code <- as.factor(efc_test$c172code)
  m8 <- glmmTMB::glmmTMB(
    tot_sc_e ~ neg_c_7 * c172code + (1 | grp),
    data = efc_test, ziformula = ~c172code,
    family = glmmTMB::nbinom1()
  )
  expect_s3_class(ggpredict(m8, "neg_c_7"), "data.frame")
  expect_s3_class(ggpredict(m8, "neg_c_7 [all]"), "data.frame")
  expect_s3_class(ggpredict(m8, "neg_c_7", type = "zero_inflated"), "data.frame")
  expect_s3_class(ggpredict(m8, "neg_c_7 [all]", type = "zero_inflated"), "data.frame")

  expect_s3_class(ggpredict(m8, c("neg_c_7", "c172code")), "data.frame")
  expect_s3_class(ggpredict(m8, c("neg_c_7 [all]", "c172code")), "data.frame")
  expect_s3_class(ggpredict(m8, c("neg_c_7", "c172code"), type = "zero_inflated"), "data.frame")
  expect_s3_class(ggpredict(m8, c("neg_c_7 [all]", "c172code"), type = "zero_inflated"), "data.frame")

  # test predictoin intervals
  m9 <- glmmTMB::glmmTMB(
    tot_sc_e ~ neg_c_7 + c172code + (1 | grp),
    data = efc_test, ziformula = ~c172code,
    family = glmmTMB::nbinom1()
  )
  d <- data_grid(m9, "c172code")
  # count model, confidence intervals
  out <- predict_response(m9, "c172code", verbose = FALSE)
  expect_equal(out$predicted, c(0.7024, 0.98046, 1.30764), tolerance = 1e-4)
  expect_equal(out$conf.high, c(0.92549, 1.21318, 1.8271), tolerance = 1e-4)
  expect_equal(out$predicted, predict(m9, newdata = d, re.form = NA, type = "conditional"), tolerance = 1e-4)
  # count model, prediction intervals
  out <- predict_response(m9, "c172code", interval = "prediction", verbose = FALSE)
  expect_equal(out$predicted, c(0.7024, 0.98046, 1.30764), tolerance = 1e-4)
  expect_equal(out$conf.high, c(1.66211, 2.27867, 3.15855), tolerance = 1e-4)
  expect_equal(out$predicted, predict(m9, newdata = d, re.form = NA, type = "conditional"), tolerance = 1e-4)
  # zero-inflated model, CI
  set.seed(123)
  out <- predict_response(m9, "c172code", type = "zero_inflated", verbose = FALSE)
  expect_equal(out$predicted, c(0.7024, 0.98046, 1.17279), tolerance = 1e-4)
  expect_equal(out$conf.high, c(1.14341, 1.5738, 1.64859), tolerance = 1e-4)
  expect_equal(out$predicted, predict(m9, newdata = d, re.form = NA, type = "response"), tolerance = 1e-4)
  # zero-inflated model, PI
  set.seed(123)
  out <- predict_response(m9, "c172code", type = "zero_inflated", interval = "prediction")
  expect_equal(out$predicted, c(0.7024, 0.98046, 1.17279), tolerance = 1e-4)
  expect_equal(out$conf.high, c(2.58571, 3.559, 3.72815), tolerance = 1e-4)
  expect_equal(out$predicted, predict(m9, newdata = d, re.form = NA, type = "response"), tolerance = 1e-4)
})


test_that("ggpredict, glmmTMB", {
  data(Salamanders, package = "glmmTMB")
  m9 <- glmmTMB::glmmTMB(
    count ~ spp + cover + mined + (1 | site),
    ziformula = ~DOY,
    dispformula = ~spp,
    data = Salamanders,
    family = glmmTMB::nbinom2()
  )
  expect_s3_class(ggpredict(m9, c("cover", "mined", "spp"), type = "fixed"), "data.frame")
  expect_s3_class(ggpredict(m9, c("cover", "mined", "spp"), type = "zero_inflated"), "data.frame") # nolint
  expect_s3_class(suppressWarnings(ggpredict(m9, c("cover", "mined", "spp"), type = "random", verbose = FALSE)), "data.frame") # nolint
  expect_s3_class(suppressWarnings(ggpredict(m9, c("cover", "mined", "spp"), type = "zero_inflated_random", verbose = FALSE)), "data.frame") # nolint
})


test_that("validate ggpredict against predict, linear, REML-fit", {
  data(sleepstudy, package = "lme4")
  # REML-fit
  m10 <- glmmTMB::glmmTMB(
    Reaction ~ Days + (1 + Days | Subject),
    data = sleepstudy,
    REML = TRUE
  )
  nd <- data_grid(m10, "Days")
  pr <- predict(m10, newdata = nd, type = "link", se.fit = TRUE)
  dof <- insight::get_df(m10, type = "wald", verbose = FALSE)
  tcrit <- stats::qt(0.975, df = dof)
  out1 <- data.frame(
    predicted = pr$fit,
    conf.low = pr$fit - tcrit * pr$se.fit,
    conf.high = pr$fit + tcrit * pr$se.fit
  )
  out2 <- ggpredict(m10, "Days", type = "random", interval = "confidence", verbose = FALSE)

  expect_equal(out1$predicted, out2$predicted, tolerance = 1e-4, ignore_attr = TRUE)
  expect_equal(out1$conf.low, out2$conf.low, tolerance = 1e-4, ignore_attr = TRUE)
  expect_equal(out1$conf.high, out2$conf.high, tolerance = 1e-4, ignore_attr = TRUE)

  # ML-fit
  m11 <- glmmTMB::glmmTMB(
    Reaction ~ Days + (1 + Days | Subject),
    data = sleepstudy,
    REML = FALSE
  )
  nd <- data_grid(m11, "Days")
  pr <- predict(m11, newdata = nd, type = "link", se.fit = TRUE)
  dof <- insight::get_df(m11, type = "wald", verbose = FALSE)
  tcrit <- stats::qt(0.975, df = dof)
  out1 <- data.frame(
    predicted = pr$fit,
    conf.low = pr$fit - tcrit * pr$se.fit,
    conf.high = pr$fit + tcrit * pr$se.fit
  )
  out2 <- ggpredict(m11, "Days")
  out3 <- ggpredict(m11, "Days", type = "random", interval = "confidence", verbose = FALSE)

  expect_equal(out1$predicted, out2$predicted, tolerance = 1e-4, ignore_attr = TRUE)
  expect_equal(out1$predicted, out3$predicted, tolerance = 1e-4, ignore_attr = TRUE)
  expect_equal(out1$conf.low, out2$conf.low, tolerance = 1e-4, ignore_attr = TRUE)
  expect_equal(out1$conf.low, out3$conf.low, tolerance = 1e-4, ignore_attr = TRUE)
  expect_equal(out1$conf.high, out2$conf.high, tolerance = 1e-4, ignore_attr = TRUE)
  expect_equal(out1$conf.high, out3$conf.high, tolerance = 1e-4, ignore_attr = TRUE)
})


test_that("glmmTMB, validate all functions against predict", {
  data(Salamanders, package = "glmmTMB")
  m <- glmmTMB::glmmTMB(
    count ~ spp + (1 | site),
    ziformula = ~spp,
    family = glmmTMB::truncated_poisson(),
    data = Salamanders
  )
  nd <- new_data(m, "spp")

  out1 <- exp(predict(m, newdata = nd, type = "link"))
  out2 <- ggpredict(m, "spp", type = "fixed")
  out3 <- ggaverage(m, "spp", type = "conditional")
  out4 <- suppressWarnings(marginaleffects::avg_predictions(
    m,
    variables = "spp",
    type = "conditional",
    re.form = NULL
  ))

  expect_equal(out1, out2$predicted, tolerance = 1e-3, ignore_attr = TRUE)
  expect_equal(out3$predicted, out4$estimate, tolerance = 1e-3, ignore_attr = TRUE)
  expect_equal(
    out3$predicted,
    c(2.36678, 1.70466, 2.7653, 2.05614, 3.94502, 3.74413, 2.38322),
    tolerance = 1e-3,
    ignore_attr = TRUE
  )

  out1 <- predict(m, newdata = nd, type = "response")
  out2 <- ggpredict(m, "spp", type = "zero_inflated")
  out3 <- ggaverage(m, "spp", type = "zero_inflated")
  out4 <- suppressWarnings(marginaleffects::avg_predictions(m, variables = "spp", re.form = NULL))

  expect_equal(out1, out2$predicted, tolerance = 1e-3, ignore_attr = TRUE)
  expect_equal(out3$predicted, out4$estimate, tolerance = 1e-3, ignore_attr = TRUE)
})


test_that("glmmTMB, orderedbeta", {
  skip_if_not_installed("datawizard")
  data(mtcars)
  mtcars$ord <- datawizard::normalize(mtcars$mpg)
  m <- glmmTMB::glmmTMB(
    ord ~ wt + hp + as.factor(gear) + (1 | cyl),
    data = mtcars,
    family = glmmTMB::ordbeta()
  )
  out1 <- ggpredict(m, "hp [50,80,120,150,250,330]")
  out2 <- ggaverage(m, "hp [50,80,120,150,250,330]")
  expect_snapshot(print(out1))
  expect_snapshot(print(out2))
})


test_that("glmmTMB, orderedbeta", {
  skip_if_not_installed("emmeans")
  mod1 <- glmmTMB::glmmTMB(count ~ spp + mined + (1 | site),
    ziformula = ~mined,
    family = glmmTMB::nbinom2, data = Salamanders
  )
  out1 <- ggemmeans(mod1, c("mined", "spp"), type = "zero_inflated")
  out2 <- ggpredict(mod1, c("mined", "spp"), type = "zero_inflated")
  expect_equal(
    out1$predicted,
    c(
      0.2127, 0.0539, 0.2872, 0.1009, 0.3675, 0.4351, 0.2534, 1.8883,
      0.4783, 2.5505, 0.8956, 3.2636, 3.8639, 2.2505
    ),
    tolerance = 1e-3
  )
  expect_equal(out1$predicted, out2$predicted, tolerance = 1e-3)
})


test_that("glmmTMB, inverse-link", {
  data(warpbreaks)
  set.seed(123)
  warpbreaks$ID <- sample.int(5, nrow(warpbreaks), replace = TRUE)
  m <- suppressWarnings(glmmTMB::glmmTMB(
    breaks ~ wool * tension + (1 | ID),
    family = Gamma(),
    data = warpbreaks
  ))
  out <- predict_response(m, c("wool", "tension"))
  expect_equal(
    out$predicted,
    c(44.63071, 23.98565, 24.60601, 28.16438, 28.58486, 18.80825),
    tolerance = 1e-3
  )
  expect_true(all(out$predicted > out$conf.low))
})
