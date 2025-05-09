.ggemmeans_add_confint <- function(model, tmp, ci_level, pmode = NULL, interval = NULL) {
  # compute ci, two-ways
  if (!is.null(ci_level) && !is.na(ci_level)) {
    ci <- (1 + ci_level) / 2
  } else {
    ci <- 0.975
  }

  # degrees of freedom
  dof <- .get_df(model)
  tcrit <- stats::qt(ci, df = dof)

  if (identical(interval, "prediction")) {

    fitfram <- suppressWarnings(
      .var_rename(
        as.data.frame(tmp),
        SE = "std.error",
        emmean = "predicted",
        lower.CL = "conf.low",
        upper.CL = "conf.high",
        prob = "predicted",
        asymp.LCL = "conf.low",
        asymp.UCL = "conf.high",
        lower.HPD = "conf.low",
        upper.HPD = "conf.high"
      )
    )

    revar <- .get_residual_variance(model)
    # get link-function and back-transform fitted values
    # to original scale, so we compute proper CI
    if (!is.null(revar)) {
      if (!is.null(pmode) && pmode %in% c("prob", "count")) {
        lf <- insight::link_function(model)
        fitfram$conf.low <- exp(lf(fitfram$conf.low) - tcrit * sqrt(revar))
        fitfram$conf.high <- exp(lf(fitfram$conf.high) + tcrit * sqrt(revar))
      } else {
        fitfram$conf.low <- fitfram$conf.low - tcrit * sqrt(revar)
        fitfram$conf.high <- fitfram$conf.high + tcrit * sqrt(revar)
      }
      fitfram$std.error <- sqrt(fitfram$std.error^2 + revar)
    }
    fitfram
  } else if (inherits(model, "multinom")) {
    fitfram <- suppressWarnings(
      .var_rename(
        as.data.frame(tmp),
        SE = "std.error",
        emmean = "predicted",
        lower.CL = "conf.low",
        upper.CL = "conf.high",
        prob = "predicted",
        asymp.LCL = "conf.low",
        asymp.UCL = "conf.high",
        lower.HPD = "conf.low",
        upper.HPD = "conf.high"
      )
    )
    lf <- insight::link_function(model)
    fitfram$conf.low <- stats::plogis(lf(fitfram$predicted) - tcrit * fitfram$std.error)
    fitfram$conf.high <- stats::plogis(lf(fitfram$predicted) + tcrit * fitfram$std.error)
    fitfram
  } else {
    fitfram <- suppressWarnings(
      .var_rename(
        as.data.frame(stats::confint(tmp, level = ci_level)),
        SE = "std.error",
        emmean = "predicted",
        lower.CL = "conf.low",
        upper.CL = "conf.high",
        prob = "predicted",
        asymp.LCL = "conf.low",
        asymp.UCL = "conf.high",
        lower.HPD = "conf.low",
        upper.HPD = "conf.high"
      )
    )
    fitfram
  }
}
