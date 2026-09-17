# Two-parameter beta weighting, separate from the retained PET numerical core.
# The parameters are beta-family shapes, not PET's fitting-grid endpoints.
BetaWeight <- function(ps.formula = NULL, ps.estimate = NULL, trtgrp = NULL,
                       zname = NULL, yname = NULL, data,
                       beta1 = 2, beta2 = 2, family = 'gaussian',
                       ps.method = 'glm', ps.control = list(),
                       variance = c('auto', 'estimated', 'fixed'), conf.level = 0.95,
                       na.action = c('fail', 'omit'), contrasts = NULL) {
  call <- match.call()
  .pet_number(beta1, 'beta1', lower = 0, left.open = TRUE)
  .pet_number(beta2, 'beta2', lower = 0, left.open = TRUE)
  .pet_number(conf.level, 'conf.level', 0, 1, strict = TRUE)
  variance <- match.arg(variance); na.action <- match.arg(na.action)
  input <- .pet_input(data, ps.formula, ps.estimate, trtgrp, zname, yname,
    FALSE, NULL, NULL, family, ps.method, ps.control, 'glm', list(), na.action, contrasts)
  available <- !is.null(input$x)
  if (variance == 'estimated' && !available)
    stop("variance='estimated' requires an internally fitted logistic GLM propensity model.", call. = FALSE)
  corrected <- variance == 'estimated' || (variance == 'auto' && available)
  a <- input$a; y <- input$y; e <- input$e; n <- length(a)
  b1 <- beta1 - 1; b2 <- beta2 - 1
  # Symmetric arithmetic matches beta.w() in the supplied demonstration exactly.
  h <- if (beta1 == beta2) (e * (1 - e))^b1 else e^b1 * (1 - e)^b2
  w1 <- a * h / e; w0 <- (1 - a) * h / (1 - e)
  if (any(!is.finite(c(h,w1,w0))) || any(h == 0) || sum(w1) <= 0 || sum(w0) <= 0)
    stop('Beta weights underflowed or overflowed; inspect overlap and choose less extreme shape parameters.', call. = FALSE)
  mu1 <- sum(w1 * y) / sum(w1); mu0 <- sum(w0 * y) / sum(w0)
  estimate <- mu1 - mu0
  influence <- w1 * (y - mu1) / mean(w1) - w0 * (y - mu0) / mean(w0)
  if (corrected) {
    # d log(h)/d linear predictor = b1*(1-e) - b2*e.
    # Generalizes the demo's empirical-score correction, retaining mean(h).
    slope <- if (beta1 == beta2) b1 * (1 - 2 * e) else b1 * (1 - e) - b2 * e
    dw <- h * (slope - (a - e)) / (a * e + (1 - a) * (1 - e))
    derivative <- colMeans(input$x * (dw * (a * (y - mu1) - (1 - a) * (y - mu0)))) / mean(h)
    influence <- influence + as.vector(input$score %*% (input$information.inverse %*% derivative))
  }
  se <- sqrt(mean(influence^2) / n)
  if (!is.finite(estimate) || !is.finite(se)) stop('Non-finite beta-weight estimate or standard error.', call. = FALSE)
  estimand <- if (beta1 == 1 && beta2 == 1) 'ATE' else
    if (beta1 == 2 && beta2 == 1) 'ATT' else
    if (beta1 == 1 && beta2 == 2) 'ATC' else
    if (beta1 == 2 && beta2 == 2) 'ATO' else 'WATE'
  variance.method <- if (corrected) 'estimated PS: generalized demo empirical-score correction' else
    'fixed PS: nuisance estimation not corrected'
  notes <- input$notes
  if (!corrected) {
    note <- 'Propensity predictions are treated as fixed; their estimation uncertainty is not corrected.'
    notes <- c(notes,note); warning(note, call. = FALSE)
  }
  notes <- c(notes, 'The beta-weight target depends on the two shape parameters; no PET extrapolation is performed.',
    'Normal intervals condition on the specified shapes. Nonconstant tilting requires a correctly specified propensity model to identify the intended target.')
  if (min(beta1,beta2) < 1) notes <- c(notes, 'Shapes below 1 can emphasize extreme propensity scores.')
  normalized <- w1 / sum(w1) + w0 / sum(w0)
  ess <- c(1 / sum((w0 / sum(w0))^2), 1 / sum((w1 / sum(w1))^2))
  structure(list(call = call, method = 'Beta weighting', estimand = estimand,
    estimate = estimate, se = se, conf.level = conf.level,
    conf.int = setNames(estimate + c(-1,1) * stats::qnorm((1+conf.level)/2) * se, c('lower','upper')),
    beta1 = beta1, beta2 = beta2, influence = influence, n = n,
    n.original = input$n.original, row.index = input$row.index, omitted = input$omitted,
    group = input$group, propensity = e, tilting = h, weights = w1 + w0,
    normalized.weights = normalized, weighted.means = setNames(c(mu0,mu1),input$group),
    effective.sample.size = setNames(ess,input$group), model.fits = input$models,
    variance.method = variance.method,
    diagnostics = list(propensity.range = range(e), treatment.counts = table(a),
      ps.aliased.columns = input$ps.aliased, notes = unique(notes))), class = 'BetaWeight')
}

print.BetaWeight <- function(x, digits = 4L, ...) {
  cat('Beta weighting: ', x$estimand, ' (', x$group[2L], ' - ', x$group[1L], ')\n', sep = '')
  print(data.frame(estimate = x$estimate, SE = x$se, lower = x$conf.int[1L], upper = x$conf.int[2L]),
    row.names = FALSE, digits = digits)
  cat('n =',x$n,'| beta1 =',x$beta1,'| beta2 =',x$beta2,'\n')
  cat('Variance:',x$variance.method,'\n')
  invisible(x)
}
summary.BetaWeight <- function(object, ...) {
  z <- object$estimate / object$se
  structure(list(estimand = object$estimand, group = object$group, n = object$n,
    beta1 = object$beta1, beta2 = object$beta2,
    coefficients = data.frame(estimate = object$estimate, std.error = object$se,
      statistic = z, p.value = 2*stats::pnorm(-abs(z)),
      conf.low = object$conf.int[1L], conf.high = object$conf.int[2L], row.names = object$estimand),
    effective.sample.size = object$effective.sample.size, variance.method = object$variance.method,
    diagnostics = object$diagnostics), class = 'summary.BetaWeight')
}
print.summary.BetaWeight <- function(x, digits = 4L, ...) {
  cat('Beta weighting: ',x$estimand,' (',x$group[2L],' - ',x$group[1L],')\n',sep='')
  print(x$coefficients,digits=digits)
  cat('n =',x$n,'| beta1 =',x$beta1,'| beta2 =',x$beta2,'\n')
  cat('Effective sample sizes by treatment:\n'); print(x$effective.sample.size,digits=digits)
  cat('Variance:',x$variance.method,'\n')
  for (note in x$diagnostics$notes) cat('*',note,'\n')
  invisible(x)
}
coef.BetaWeight <- function(object, ...) setNames(object$estimate,object$estimand)
vcov.BetaWeight <- function(object, ...) matrix(object$se^2,1L,1L,dimnames=list(object$estimand,object$estimand))
confint.BetaWeight <- function(object, parm, level = object$conf.level, ...) {
  if (!missing(parm) && !identical(parm,object$estimand) && !identical(parm,1) && !identical(parm,1L))
    stop('Only the ',object$estimand,' coefficient is available.',call.=FALSE)
  .pet_number(level,'level',0,1,strict=TRUE)
  ci <- object$estimate + c(-1,1)*stats::qnorm((1+level)/2)*object$se
  matrix(ci,1L,2L,dimnames=list(object$estimand,paste0(format(100*c((1-level)/2,(1+level)/2)),'%')))
}
