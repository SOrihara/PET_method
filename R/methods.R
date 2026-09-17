#' @export
print.PET <- function(x, digits = 4L, ...) {
  cat(x$method, ': ATE (', x$group[2L], ' - ', x$group[1L], ')\n', sep = '')
  result <- data.frame(estimate = x$estimate, SE = x$se, lower = x$conf.int[1L], upper = x$conf.int[2L])
  rownames(result) <- NULL
  print(result, digits = digits, row.names = FALSE)
  cat('n =', x$n, '| degree =', x$tuning$degree, '| beta.min =', x$tuning$beta.min,
      '| beta.max =', x$tuning$beta.max, '| K =', x$tuning$K, '\n')
  cat('Variance:', x$variance.method, '\n')
  invisible(x)
}
#' @export
summary.PET <- function(object, ...) {
  z <- object$estimate / object$se
  ans <- list(method = object$method, group = object$group, n = object$n,
    coefficients = data.frame(estimate = object$estimate, std.error = object$se,
      statistic = z, p.value = 2 * stats::pnorm(-abs(z)),
      conf.low = object$conf.int[1L], conf.high = object$conf.int[2L], row.names = 'ATE'),
    tuning = object$tuning, variance.method = object$variance.method,
    conf.level = object$conf.level, diagnostics = object$diagnostics)
  structure(ans, class = 'summary.PET')
}
#' @export
print.summary.PET <- function(x, digits = 4L, ...) {
  cat(x$method, ': ', x$group[2L], ' - ', x$group[1L], ' (n = ', x$n, ')\n', sep = '')
  print(x$coefficients, digits = digits)
  cat('\nSelected: degree =', x$tuning$degree, ', beta.min =', x$tuning$beta.min,
      ', K =', x$tuning$K, ', beta.max =', x$tuning$beta.max, '\n')
  cat('Variance target met:', x$tuning$target.met, '(kappa =', x$tuning$kappa, ')\n')
  cat('Variance:', x$variance.method, '\n')
  for (note in x$diagnostics$notes) cat('*', note, '\n')
  invisible(x)
}
#' @export
coef.PET <- function(object, ...) setNames(object$estimate, 'ATE')
#' @export
vcov.PET <- function(object, ...) matrix(object$se^2, 1L, 1L, dimnames = list('ATE', 'ATE'))
#' @export
confint.PET <- function(object, parm, level = object$conf.level, ...) {
  if (!missing(parm) && !identical(parm, 'ATE') && !identical(parm, 1) && !identical(parm, 1L)) stop('Only the ATE coefficient is available.', call. = FALSE)
  .pet_number(level, 'level', 0, 1, strict = TRUE)
  ci <- object$estimate + c(-1,1) * stats::qnorm((1+level)/2) * object$se
  matrix(ci, 1L, 2L, dimnames = list('ATE', paste0(format(100*c((1-level)/2,(1+level)/2)), '%')))
}

#' Calculate Sensitivity Trajectories
#' @export
trajectory <- function(object, degree = 1:4, beta.min = c(0.14, 0.29, 0.44, 0.69),
                       beta = c(0, seq(0.04, 0.69, by = 0.05))) {
  if (!inherits(object, 'PET')) stop('object must be a PET fit.', call. = FALSE)
  K <- object$tuning$K; bmax <- object$tuning$beta.max
  .pet_vector(degree, 'degree', 1, K-1, integer = TRUE)
  .pet_vector(beta.min, 'beta.min', 0, bmax, right.open = TRUE)
  .pet_vector(beta, 'beta', 0, 1, right.open = TRUE)
  degree <- sort(unique(degree)); beta <- sort(unique(c(0,beta))); beta.min <- sort(unique(beta.min))
  input <- object$input
  wate <- lapply(beta, function(b) {
    x <- .pet_component(b, input)
    data.frame(beta = b, estimate = x$estimate, se = x$se)
  })
  wate <- do.call(rbind, wate)
  candidates <- sort(unique(object$tuning$candidates$beta.min))
  all.bs <- sort(unique(c(candidates, beta.min)))
  cache <- lapply(all.bs, function(b) .pet_components(seq(b, bmax, length.out = K), input))
  curves <- endpoints <- selected <- list(); idx <- 0L
  for (q in degree) {
    fits <- lapply(cache, .pet_fit_grid, degree = q)
    tab <- data.frame(beta.min = all.bs, degree = q, se = vapply(fits, `[[`, numeric(1), 'se'))
    eligible <- tab[tab$beta.min %in% candidates, , drop = FALSE]
    pick <- .pet_select(eligible, object$tuning$target.variance)
    selected.b <- eligible$beta.min[pick$selected]
    selected[[length(selected)+1L]] <- data.frame(degree = q, beta.min = selected.b, target.met = pick$target.met)
    # Include the selected curve even if it is outside the requested display set.
    display <- sort(unique(c(beta.min, selected.b)))
    for (b in display) {
      f <- fits[[match(b,all.bs)]]; idx <- idx + 1L
      curves[[idx]] <- data.frame(beta = beta, estimate = .pet_predict_curve(f,beta), degree = q, beta.min = b)
      endpoints[[idx]] <- data.frame(beta = 0, estimate = f$estimate, se = f$se,
        degree = q, beta.min = b, selected = b == selected.b)
    }
  }
  structure(list(wate = wate, curves = do.call(rbind,curves),
    endpoints = do.call(rbind,endpoints), selected = do.call(rbind,selected),
    degree = degree, method = object$method, conf.level = object$conf.level,
    fit.range = c(min(all.bs),bmax), variance.method = object$variance.method), class = 'PET_trajectory')
}

#' @export
plot.PET <- function(x, degree = 1:4, beta.min = c(0.14,0.29,0.44,0.69),
                     beta = c(0,seq(0.04,0.69,by=0.05)), error = c('se','ci','none'),
                     ncol = 2L, ...) {
  plot(trajectory(x, degree, beta.min, beta), error = error, ncol = ncol, ...)
}
#' @export
plot.PET_trajectory <- function(x, error = c('se','ci','none'), ncol = 2L,
                                conf.level = x$conf.level, ...) {
  if (!requireNamespace('ggplot2', quietly = TRUE)) stop('Install ggplot2 to draw trajectory plots. trajectory() returns plotting data without ggplot2.', call. = FALSE)
  error <- match.arg(error); .pet_number(ncol, 'ncol', 1, integer = TRUE)
  .pet_number(conf.level, 'conf.level',0,1,strict=TRUE)
  multiplier <- switch(error, se=1, ci=stats::qnorm((1+conf.level)/2), none=0)
  bvalues <- sort(unique(x$curves$beta.min))
  labels <- paste0(x$method, ': beta1 = ', format(bvalues, trim=TRUE))
  series <- c('Beta weight',labels)
  colors <- c('black', rep(c('#F8766D','#7CAE00','#00BFC4','#C77CFF','#E69F00','#0072B2'),length.out=length(bvalues)))
  ltys <- c('solid',rep(c('solid','dashed','dotdash','twodash','longdash','dotted'),length.out=length(bvalues)))
  names(colors) <- names(ltys) <- series
  w <- do.call(rbind,lapply(x$degree, function(q) transform(x$wate,degree=q)))
  cdata <- x$curves; ep <- x$endpoints[x$endpoints$selected,,drop=FALSE]
  w$series <- factor('Beta weight',levels=series)
  cdata$series <- factor(labels[match(cdata$beta.min,bvalues)],levels=series)
  ep$series <- factor(labels[match(ep$beta.min,bvalues)],levels=series)
  for (nm in c('w','cdata','ep')) {
    d <- get(nm); d$panel <- factor(paste('q =',d$degree),levels=paste('q =',x$degree)); assign(nm,d)
  }
  shift <- 0.008 * max(w$beta) / 0.69
  w$point.beta <- ifelse(w$beta==0,-shift,w$beta)
  ep$point.beta <- shift
  caption <- switch(error,se='Error bars: +/- 1 standard error',ci=paste0('Error bars: ',100*conf.level,'% normal confidence intervals'),none='No error bars')
  p <- ggplot2::ggplot() +
    ggplot2::geom_line(data=w,ggplot2::aes(x=beta,y=estimate,color=series,linetype=series),linewidth=0.7) +
    ggplot2::geom_point(data=w,ggplot2::aes(x=point.beta,y=estimate),size=1.7)
  if (error!='none') p <- p +
    ggplot2::geom_errorbar(data=w,ggplot2::aes(x=point.beta,ymin=estimate-multiplier*se,ymax=estimate+multiplier*se),width=0.005,linewidth=0.35) +
    ggplot2::geom_errorbar(data=ep,ggplot2::aes(x=point.beta,ymin=estimate-multiplier*se,ymax=estimate+multiplier*se,color=series),width=0.005,linewidth=0.6)
  p + ggplot2::geom_line(data=cdata,ggplot2::aes(x=beta,y=estimate,color=series,linetype=series),linewidth=0.8) +
    ggplot2::geom_point(data=ep,ggplot2::aes(x=point.beta,y=estimate,color=series),shape=17,size=2.5) +
    ggplot2::facet_wrap(~panel,ncol=ncol) +
    ggplot2::scale_color_manual(values=colors,breaks=series,drop=FALSE) +
    ggplot2::scale_linetype_manual(values=ltys,breaks=series,drop=FALSE) +
    ggplot2::labs(x=expression(beta),y='Estimates',color=NULL,linetype=NULL,
      caption=paste(caption,'\nTriangles: PET estimate at beta=0 using the selected beta1 for each degree.')) +
    ggplot2::theme_classic(base_size=12) +
    ggplot2::theme(legend.position='right',strip.background=ggplot2::element_blank(),
      strip.text=ggplot2::element_text(size=12),plot.caption=ggplot2::element_text(hjust=0,size=9))
}

# Symbols used inside ggplot2's data masks.
utils::globalVariables(c('beta','estimate','series','point.beta','se','panel'))
