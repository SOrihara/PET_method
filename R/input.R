.pet_flag <- function(x, name) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) stop(name, ' must be TRUE or FALSE.', call. = FALSE)
}
.pet_number <- function(x, name, lower = -Inf, upper = Inf, integer = FALSE,
                        strict = FALSE, left.open = FALSE) {
  if (length(x) != 1L) stop(name, ' must be scalar.', call. = FALSE)
  .pet_vector(x, name, lower, upper, integer, strict || left.open, strict)
}
.pet_vector <- function(x, name, lower = -Inf, upper = Inf, integer = FALSE,
                        left.open = FALSE, right.open = FALSE) {
  bad <- !is.numeric(x) || !length(x) || any(!is.finite(x))
  if (!bad) bad <- any(if (left.open) x <= lower else x < lower) ||
    any(if (right.open) x >= upper else x > upper) || (integer && any(x != floor(x)))
  if (bad) stop(name, ' contains invalid values or lies outside its allowed range.', call. = FALSE)
}
.pet_frame <- function(formula, data, response, name) {
  if (!inherits(formula, 'formula') || length(formula) != 3L || !is.symbol(formula[[2L]]))
    stop(name, ' must be a two-sided formula with a simple response column.', call. = FALSE)
  if (as.character(formula[[2L]]) != response) stop(name, ' response disagrees with the supplied variable name.', call. = FALSE)
  mf <- stats::model.frame(formula, data = data, na.action = stats::na.pass, drop.unused.levels = FALSE)
  if (nrow(mf) != nrow(data)) stop(name, ' must have one row per data row.', call. = FALSE)
  if (!is.null(stats::model.offset(mf))) stop('Offsets are not supported in this version.', call. = FALSE)
  mf
}
.pet_matrix <- function(frame, contrasts) {
  stats::model.matrix(stats::delete.response(stats::terms(frame)), frame, contrasts.arg = contrasts)
}
.pet_finite_rows <- function(x) {
  if (is.numeric(x) || is.logical(x)) {
    if (is.null(dim(x))) return(is.finite(x))
    return(rowSums(!is.finite(x)) == 0L)
  }
  stats::complete.cases(x)
}
.pet_external <- function(value, n, groups, name, vector = FALSE) {
  if (vector && is.numeric(value) && is.null(dim(value))) {
    if (length(value) != n) stop(name, ' length must equal nrow(data).', call. = FALSE)
    return(as.numeric(value))
  }
  value <- as.matrix(value)
  if (!is.numeric(value) || !identical(dim(value), c(as.integer(n), 2L)))
    stop(name, ' must be a numeric n by 2 matrix with one column per treatment.', call. = FALSE)
  if (is.null(colnames(value))) {
    warning(name, ' has no column names; columns are interpreted in alphabetical treatment-label order.', call. = FALSE)
    colnames(value) <- sort(groups)
  }
  if (anyDuplicated(colnames(value)) || !setequal(colnames(value), groups))
    stop(name, ' column names must exactly match the two treatment labels.', call. = FALSE)
  value <- value[, groups, drop = FALSE]
  if (vector) {
    complete <- stats::complete.cases(value)
    if (any(abs(rowSums(value[complete, , drop = FALSE]) - 1) > 1e-6))
      stop('The two propensity columns must sum to one in every complete row.', call. = FALSE)
    if (any(value < 0 | value > 1, na.rm = TRUE)) stop('Propensity probabilities must lie in [0,1].', call. = FALSE)
    return(as.numeric(value[, 2L]))
  }
  value
}
.pet_fullrank <- function(x) {
  decomp <- qr(x)
  if (decomp$rank == 0L) stop('Model design contains no estimable columns.', call. = FALSE)
  keep <- sort(decomp$pivot[seq_len(decomp$rank)])
  list(x = x[, keep, drop = FALSE], aliased = setdiff(colnames(x), colnames(x)[keep]))
}
.pet_control <- function(control, reserved) {
  if (!is.list(control) || (length(control) && (is.null(names(control)) || any(names(control) == '') || anyDuplicated(names(control)))))
    stop('Model controls must be a list with unique nonempty names.', call. = FALSE)
  if (length(intersect(names(control), reserved))) stop('Model controls cannot override: ', paste(intersect(names(control), reserved), collapse = ', '), call. = FALSE)
  control
}
.pet_glm_method <- function(method, name) {
  if (!is.character(method) || length(method) != 1L || is.na(method) || method != 'glm')
    stop(name, " supports only 'glm'. Fit other learners externally and supply ps.estimate or out.estimate.", call. = FALSE)
}
.pet_learner <- function(x, y, newx, method, family, control) {
    .pet_glm_method(method, 'Internal method')
    control <- .pet_control(control, c('x','y','family','weights','offset','intercept','singular.ok'))
    allowed <- c('epsilon','maxit','trace')
    if (length(setdiff(names(control), allowed))) stop('GLM controls are epsilon, maxit, and trace.', call. = FALSE)
    fit <- stats::glm.fit(x, y, family = family, control = do.call(stats::glm.control, control))
    if (!isTRUE(fit$converged)) stop('GLM did not converge; inspect separation or adjust the model.', call. = FALSE)
    if (fit$rank < ncol(x)) stop('Model is not identifiable within a treatment arm; collapse sparse factor levels or supply external predictions.', call. = FALSE)
    pred <- family$linkinv(as.vector(newx %*% fit$coefficients))
    return(list(pred = pred, fit = fit))
}

.pet_input <- function(data, ps.formula, ps.estimate, trtgrp, zname, yname,
                       augmentation, out.formula, out.estimate, family,
                       ps.method, ps.control, out.method, out.control, na.action, contrasts) {
  .pet_glm_method(ps.method, 'ps.method')
  .pet_glm_method(out.method, 'out.method')
  if (!is.data.frame(data) || nrow(data) < 4L) stop('data must be a data frame with at least four observations.', call. = FALSE)
  if (anyDuplicated(names(data))) stop('data column names must be unique.', call. = FALSE)
  if (is.null(zname) && inherits(ps.formula, 'formula')) zname <- as.character(ps.formula[[2L]])
  if (is.null(yname) && inherits(out.formula, 'formula')) yname <- as.character(out.formula[[2L]])
  for (nm in list(zname, yname)) if (!is.character(nm) || length(nm) != 1L || !nm %in% names(data))
    stop('Specify existing treatment/outcome columns using zname and yname (or formula responses).', call. = FALSE)
  if (identical(zname, yname)) stop('Treatment and outcome columns must differ.', call. = FALSE)
  n <- nrow(data); raw.a <- data[[zname]]; y <- data[[yname]]
  if (!(is.numeric(y) || is.logical(y))) stop('Outcome must be numeric; code binary outcomes as 0/1.', call. = FALSE)
  labs <- sort(unique(as.character(raw.a[!is.na(raw.a)])))
  if (length(labs) != 2L) stop('Exactly two observed treatment levels are required.', call. = FALSE)
  if (is.null(trtgrp)) trtgrp <- labs[2L]
  trtgrp <- as.character(trtgrp)
  if (length(trtgrp) != 1L || !trtgrp %in% labs) stop('trtgrp must name one observed treatment level.', call. = FALSE)
  groups <- c(setdiff(labs, trtgrp), trtgrp)
  a <- as.numeric(as.character(raw.a) == trtgrp)
  if (is.character(family)) family <- switch(family, gaussian = stats::gaussian(), binomial = stats::binomial(), stop('family must be gaussian or binomial.', call. = FALSE))
  if (is.function(family)) family <- family()
  if (!inherits(family, 'family') || !family$family %in% c('gaussian','binomial')) stop('Supported outcome families are gaussian and binomial.', call. = FALSE)
  if (family$family == 'gaussian' && family$link != 'identity') stop('Gaussian outcomes require the identity link.', call. = FALSE)
  notes <- character(); models <- list(); e <- NULL; m <- NULL; x <- NULL; ox <- NULL
  if (!is.null(ps.estimate)) {
    e <- .pet_external(ps.estimate, n, groups, 'ps.estimate', vector = TRUE)
    if (!is.null(ps.formula)) notes <- c(notes, 'ps.estimate supplied: propensity formula was not fitted.')
  } else {
    if (is.null(ps.formula)) stop('Supply ps.formula or ps.estimate.', call. = FALSE)
    ps.frame <- .pet_frame(ps.formula, data, zname, 'ps.formula')
    if (yname %in% all.vars(stats::delete.response(stats::terms(ps.frame)))) stop('The outcome cannot be a predictor in ps.formula.', call. = FALSE)
    x <- .pet_matrix(ps.frame, contrasts)
  }
  if (augmentation) {
    if (!is.null(out.estimate)) {
      m <- .pet_external(out.estimate, n, groups, 'out.estimate')
      if (!is.null(out.formula)) notes <- c(notes, 'out.estimate supplied: outcome formula was not fitted.')
    } else {
      if (is.null(out.formula)) stop('AIPW-PET requires out.formula or out.estimate.', call. = FALSE)
      out.frame <- .pet_frame(out.formula, data, yname, 'out.formula')
      if (zname %in% all.vars(stats::delete.response(stats::terms(out.frame))))
        stop('out.formula should contain covariates only: separate models are fitted in the two treatment groups, as in PSweight.', call. = FALSE)
      ox <- .pet_matrix(out.frame, contrasts)
    }
  } else if (!is.null(out.estimate) || !is.null(out.formula)) {
    notes <- c(notes, 'Outcome model inputs were not used because augmentation=FALSE.')
  }
  used <- list(a, y, e, m, x, ox); used <- used[!vapply(used, is.null, logical(1))]
  # Infinite values indicate invalid transformations and are never silently omitted.
  if (any(vapply(used, function(v) any(is.infinite(v)), logical(1)))) stop('Inputs contain infinite values; inspect transformations and predictions.', call. = FALSE)
  keep <- Reduce(`&`, lapply(used, .pet_finite_rows))
  if (any(!keep) && na.action == 'fail') stop('Missing values in analysis inputs; use na.action="omit" explicitly or supply complete data.', call. = FALSE)
  if (any(!keep)) notes <- c(notes, paste(sum(!keep), 'rows omitted consistently from all analysis inputs.'))
  a <- a[keep]; y <- as.numeric(y[keep]); n.used <- length(a)
  if (n.used < 4L || length(unique(a)) != 2L || any(tabulate(a+1L, 2L) < 2L)) stop('At least two complete observations per treatment group are required.', call. = FALSE)
  if (family$family == 'binomial' && any(!y %in% c(0,1))) stop('Binary outcomes must be coded 0/1.', call. = FALSE)
  aliased <- character()
  if (is.null(e)) {
    rank <- .pet_fullrank(x[keep, , drop = FALSE]); x <- rank$x; aliased <- rank$aliased
    ps <- .pet_learner(x, a, x, ps.method, stats::binomial(), ps.control)
    e <- ps$pred; models$propensity <- ps$fit
  } else e <- e[keep]
  if (any(!is.finite(e)) || any(e <= 0 | e >= 1)) stop('All propensity scores must be strictly between 0 and 1. No automatic clipping or trimming is performed.', call. = FALSE)
  if (augmentation && is.null(m)) {
    ox <- .pet_fullrank(ox[keep, , drop = FALSE])$x
    m <- matrix(NA_real_, n.used, 2L, dimnames = list(NULL, groups))
    models$outcome <- vector('list',2L); names(models$outcome) <- groups
    for (j in 1:2) {
      select <- a == (j-1L)
      fit <- .pet_learner(ox[select, , drop = FALSE], y[select], ox, out.method, family, out.control)
      m[, j] <- fit$pred; models$outcome[[j]] <- fit$fit
    }
  } else if (!is.null(m)) m <- m[keep, , drop = FALSE]
  if (!is.null(m) && (any(!is.finite(m)) || (family$family == 'binomial' && any(m < 0 | m > 1))))
    stop('Outcome predictions must be finite, and binary-outcome probabilities must lie in [0,1].', call. = FALSE)
  score <- inverse <- NULL
  if (!is.null(x)) {
    score <- x * (a-e)
    info <- crossprod(score)/n.used
    if (rcond(info) < 1e-12) stop('Propensity score information is numerically singular; simplify or rescale the model.', call. = FALSE)
    inverse <- solve(info)
  }
  list(a = a, y = y, e = e, m = m, x = x, score = score, information.inverse = inverse,
       augmentation = augmentation, group = groups, family = family$family,
       models = models, ps.aliased = aliased, notes = notes,
       n.original = n, row.index = unname(which(keep)), omitted = unname(which(!keep)))
}
