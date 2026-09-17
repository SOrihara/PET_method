# Numerical statements below are retained from the supplied polex() function.
# Only nuisance-input preparation is moved outside: ee and XX.PS are supplied
# by the wrapper so model formulas and external propensity predictions can work.
# XX.PS=NULL is the agreed external/fixed-PS path, without PS correction.
# For ordinary internally fitted logistic PS, all estimator, projection and
# standard-error operations below follow the original program.
.pet_source_core <- function(aa, BB, AA, YY, ee, XX.PS = NULL) {
  nn <- length(AA)
  KK <- length(aa)
  kk_a <- thet_1 <- thet_0 <- rep(0, KK)
  scor1 <- scor0 <- scor.PS <- matrix(0, nrow = nn, ncol = KK)
  if (!is.null(XX.PS)) {
    SS.PS <- XX.PS * (AA - ee)
    II.PS <- solve(t(SS.PS) %*% SS.PS/nn)
  }
  PB <- BB %*% solve(t(BB) %*% BB) %*% t(BB)
  alpha <- (1 - apply(PB, 2, sum))/c(t(rep(1, KK)) %*% (diag(KK) - PB) %*% rep(1, KK))
  for(ll in 1:KK){
    ww <- (ee*(1 - ee))^aa[ll]
    thet_1[ll] <- sum(AA*ww*YY/ee)/sum(AA*ww/ee)
    thet_0[ll] <- sum((1 - AA)*ww*YY/(1 - ee))/sum((1 - AA)*ww/(1 - ee))
    kk_a[ll] <- thet_1[ll] - thet_0[ll]
    scor1[, ll] <- (AA*ww/ee)*(YY - thet_1[ll])/mean(AA*ww/ee)
    scor0[, ll] <- ((1 - AA)*ww/(1 - ee))*(YY - thet_0[ll])/mean((1 - AA)*ww/(1 - ee))
    if (!is.null(XX.PS)) {
      WW.d <- XX.PS * c(ww*(aa[ll]*(1 - 2*ee) - (AA - ee))/(AA*ee + (1 - AA)*(1 - ee)))
      scor.PS1 <- c(t(WW.d) %*% (AA * YY)/nn) - thet_1[ll]*c(t(WW.d) %*% AA/nn)
      scor.PS0 <- c(t(WW.d) %*% ((1 - AA) * YY)/nn) - thet_0[ll]*c(t(WW.d) %*% (1 - AA)/nn)
      scor.PS[, ll] <- c(SS.PS %*% c((scor.PS1 - scor.PS0) %*% II.PS/mean(ww)))
    }
  }
  kk_ <- as.numeric(stats::lm(kk_a ~ BB)$coef)
  se <- sqrt(mean(c((scor1 - scor0 + scor.PS) %*% alpha)^2)/nn)
  if (any(!is.finite(c(kk_,se)))) stop('The original PET core returned non-finite values. Inspect the model and beta grid.', call. = FALSE)
  list(estimate = kk_[1], se = se, coefficients = kk_,
       component.estimates = kk_a, alpha = alpha,
       influence = c((scor1 - scor0 + scor.PS) %*% alpha))
}
