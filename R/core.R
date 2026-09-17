# PET numerical core. Equations (5), (7), (8), (10), Algorithm 1 in v2.
# The empirical-score correction matches the supplied polex() implementation.
.pet_component <- function(beta, input, corrected = input$corrected) {
  a <- input$a; y <- input$y; e <- input$e; n <- length(a)
  w <- (e * (1 - e))^beta
  if (input$augmentation) {
    pseudo <- input$m[, 2L] - input$m[, 1L] +
      a / e * (y - input$m[, 2L]) - (1 - a) / (1 - e) * (y - input$m[, 1L])
    est <- sum(w * pseudo) / sum(w)
    influence <- w / mean(w) * (pseudo - est)
  } else {
    w1 <- a * w / e; w0 <- (1 - a) * w / (1 - e)
    mu1 <- sum(w1 * y) / sum(w1); mu0 <- sum(w0 * y) / sum(w0)
    est <- mu1 - mu0
    influence <- w1 * (y - mu1) / mean(w1) - w0 * (y - mu0) / mean(w0)
    if (corrected) {
      dw <- w * (beta * (1 - 2 * e) - (a - e)) / (a * e + (1 - a) * (1 - e))
      derivative <- colMeans(input$x * (dw * (a * (y - mu1) - (1 - a) * (y - mu0)))) / mean(w)
      influence <- influence + as.vector(input$score %*% (input$information.inverse %*% derivative))
    }
  }
  if (!is.finite(est) || any(!is.finite(influence))) stop('Non-finite estimate or influence function; inspect overlap and outcomes.', call. = FALSE)
  list(estimate = est, se = sqrt(mean(influence^2) / n), influence = influence)
}

.pet_components <- function(beta, input) {
  fits <- lapply(beta, .pet_component, input = input)
  list(beta = beta, estimate = vapply(fits, `[[`, numeric(1), 'estimate'),
       influence = do.call(cbind, lapply(fits, `[[`, 'influence')), input = input)
}

.pet_projection <- function(beta, degree) {
  # Original polex() projection, deliberately retained at the owner's request.
  KK <- length(beta)
  BB <- stats::poly(beta, degree, raw = TRUE, simple = TRUE)
  PB <- BB %*% solve(t(BB) %*% BB) %*% t(BB)
  alpha <- (1 - apply(PB, 2, sum))/c(t(rep(1, KK)) %*% (diag(KK) - PB) %*% rep(1, KK))
  list(BB = BB, alpha = alpha)
}

.pet_fit_grid <- function(components, degree) {
  if (!components$input$augmentation) {
    input <- components$input
    BB <- stats::poly(components$beta, degree, raw = TRUE, simple = TRUE)
    out <- .pet_source_core(components$beta, BB, input$a, input$y, input$e,
                            if (input$corrected) input$x else NULL)
    return(list(estimate = out$estimate, se = out$se, influence = out$influence,
      alpha = out$alpha, coefficients = out$coefficients,
      center = 0, scale = 1, beta = components$beta,
      component.estimates = out$component.estimates, degree = degree))
  }
  pr <- .pet_projection(components$beta, degree)
  kk_a <- components$estimate; BB <- pr$BB
  coeff <- as.numeric(stats::lm(kk_a ~ BB)$coef)
  influence <- as.vector(components$influence %*% pr$alpha)
  list(estimate = coeff[1L],
       se = sqrt(mean(influence^2) / length(influence)), influence = influence,
       alpha = pr$alpha, coefficients = coeff, center = 0, scale = 1,
       beta = components$beta, component.estimates = components$estimate, degree = degree)
}

.pet_predict_curve <- function(fit, beta) {
  as.vector(outer((beta - fit$center) / fit$scale, 0:fit$degree, `^`) %*% fit$coefficients)
}

.pet_select <- function(table, target) {
  # Strict inequality and both fallback rules are specified by Algorithm 1.
  qs <- sort(unique(table$degree)); per.degree <- integer(length(qs))
  for (j in seq_along(qs)) {
    ix <- which(table$degree == qs[j]); ix <- ix[order(table$beta.min[ix])]
    ok <- ix[table$se[ix]^2 < target]
    per.degree[j] <- if (length(ok)) ok[1L] else tail(ix, 1L)
  }
  ok <- per.degree[table$se[per.degree]^2 < target]
  selected <- if (length(ok)) tail(ok, 1L) else per.degree[1L]
  list(selected = selected, per.degree = per.degree,
       target.met = table$se[selected]^2 < target)
}

#' Estimate the Average Treatment Effect Using PET
#' @export
PET <- function(ps.formula = NULL, ps.estimate = NULL, trtgrp = NULL,
                zname = NULL, yname = NULL, data, augmentation = FALSE,
                out.formula = NULL, out.estimate = NULL, family = 'gaussian',
                ps.method = 'glm', ps.control = list(), out.method = 'glm',
                out.control = list(), K = 50L, beta.min = NULL, beta.max = 0.99,
                degree = NULL, beta.candidates = seq(0.44, 0.69, by = 0.05),
                degree.candidates = 1:4, kappa = NULL,
                variance = c('auto', 'estimated', 'fixed'), conf.level = 0.95,
                na.action = c('fail', 'omit'), contrasts = NULL) {
  call <- match.call()
  .pet_flag(augmentation, 'augmentation')
  variance <- match.arg(variance); na.action <- match.arg(na.action)
  .pet_number(K, 'K', lower = 2, integer = TRUE)
  .pet_number(beta.max, 'beta.max', lower = 0, upper = 1, strict = TRUE)
  .pet_number(conf.level, 'conf.level', lower = 0, upper = 1, strict = TRUE)
  if (is.null(kappa)) kappa <- if (augmentation) 1 else 5/6
  .pet_number(kappa, 'kappa', lower = 0, upper = 1, left.open = TRUE)
  bs <- if (is.null(beta.min)) beta.candidates else beta.min
  qs <- if (is.null(degree)) degree.candidates else degree
  if (!is.null(beta.min) && length(beta.min) != 1L) stop('beta.min must be scalar; use beta.candidates for selection.', call. = FALSE)
  if (!is.null(degree) && length(degree) != 1L) stop('degree must be scalar; use degree.candidates for selection.', call. = FALSE)
  .pet_vector(bs, 'beta candidates', lower = 0, upper = beta.max, right.open = TRUE)
  .pet_vector(qs, 'degree candidates', lower = 1, upper = K - 1L, integer = TRUE)
  bs <- sort(unique(bs)); qs <- sort(unique(qs))
  input <- .pet_input(data, ps.formula, ps.estimate, trtgrp, zname, yname,
                      augmentation, out.formula, out.estimate, family,
                      ps.method, ps.control, out.method, out.control, na.action, contrasts)
  if (augmentation && variance == 'estimated') stop("For AIPW-PET use variance='auto' or 'fixed'; both use the paper's augmented influence function (10).", call. = FALSE)
  available <- !is.null(input$x)
  if (!augmentation && variance == 'estimated' && !available) stop("variance='estimated' requires an internally fitted logistic GLM propensity model.", call. = FALSE)
  input$corrected <- !augmentation && (variance == 'estimated' || (variance == 'auto' && available))
  input$variance.method <- if (augmentation) 'augmented influence function (v2 equation 10)' else if (input$corrected) 'estimated PS: empirical-score correction (source polex)' else 'fixed PS: nuisance estimation not corrected'
  notes <- input$notes
  if (!augmentation && !input$corrected) {
    notes <- c(notes, 'Propensity predictions are treated as fixed; their estimation uncertainty is not corrected.')
    warning(tail(notes, 1L), call. = FALSE)
  }
  if (augmentation) notes <- c(notes, 'AIPW-PET uses equation (10), with plug-in nuisance predictions. This is not a general sandwich correction for arbitrary learners or misspecified models.')
  notes <- c(notes, 'Normal intervals condition on the selected hyperparameters and do not include extrapolation bias or selection uncertainty.')
  baseline <- .pet_baseline(input)
  fits <- list(); table <- list(); i <- 0L
  for (b in bs) {
    components <- .pet_components(seq(b, beta.max, length.out = K), input)
    for (q in qs) {
      i <- i + 1L; fits[[i]] <- .pet_fit_grid(components, q)
      table[[i]] <- data.frame(beta.min = b, degree = q, estimate = fits[[i]]$estimate, se = fits[[i]]$se)
    }
  }
  table <- do.call(rbind, table)
  selected <- .pet_select(table, kappa * baseline$se^2)
  fit <- fits[[selected$selected]]
  table$target.met <- table$se^2 < kappa * baseline$se^2
  table$selected <- seq_len(nrow(table)) == selected$selected
  table$selected.within.degree <- seq_len(nrow(table)) %in% selected$per.degree
  tuned <- is.null(beta.min) || is.null(degree)
  if (tuned && !selected$target.met) {
    notes <- c(notes, 'No selected candidate meets the variance target; Algorithm 1 fallback was used.')
    warning(tail(notes, 1L), call. = FALSE)
  }
  critical <- stats::qnorm((1 + conf.level) / 2)
  structure(c(fit, list(call = call, method = if (augmentation) 'AIPW-PET' else 'PET',
    conf.int = setNames(fit$estimate + c(-1, 1) * critical * fit$se, c('lower', 'upper')),
    conf.level = conf.level, n = length(input$a), n.original = input$n.original,
    row.index = input$row.index, omitted = input$omitted, group = input$group,
    propensity = input$e, outcome.predictions = input$m, model.fits = input$models,
    variance.method = input$variance.method, baseline = baseline,
    tuning = list(K = K, beta.min = table$beta.min[selected$selected], beta.max = beta.max,
      degree = table$degree[selected$selected], kappa = kappa, target.variance = kappa * baseline$se^2,
      target.met = selected$target.met, tuned = tuned, candidates = table),
    diagnostics = list(propensity.range = range(input$e), treatment.counts = table(input$a),
      ps.aliased.columns = input$ps.aliased, notes = unique(notes)), input = input)), class = 'PET')
}

# The source uses PSweight's ordinary IPW SE as the Algorithm 1 comparator.
# Its logistic M-estimation bread uses expected information, unlike polex's OPG.
.pet_baseline <- function(input) {
  if (input$augmentation || !input$corrected) return(.pet_component(0, input))
  z <- .pet_component(0, input, corrected = FALSE)
  a <- input$a; e <- input$e; y <- input$y; x <- input$x; n <- length(a)
  w1 <- a / e; w0 <- (1 - a) / (1 - e)
  mu1 <- sum(w1*y) / sum(w1); mu0 <- sum(w0*y) / sum(w0)
  derivative <- colMeans(x * (-w1 * (1-e) * (y-mu1))) / mean(w1) -
    colMeans(x * (w0 * e * (y-mu0))) / mean(w0)
  bread <- crossprod(x, x * (e * (1-e))) / n
  z$influence <- z$influence + as.vector(input$score %*% solve(bread, derivative))
  z$se <- sqrt(mean(z$influence^2) / n)
  z
}
