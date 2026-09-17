library(PET)
set.seed(20260914)
n <- 600
dat <- data.frame(age = rnorm(n, 55, 10), sex = factor(sample(c('F','M'), n, TRUE)))
dat$A <- rbinom(n, 1, plogis(-.7 + .035*(dat$age-55)))
dat$Y <- 2 + .75*dat$A + .04*(dat$age-55) + rnorm(n)
dat$event <- rbinom(n, 1, plogis(-1 + .45*dat$A + .025*(dat$age-55)))

# Continuous outcome, automatic paper-v2 tuning.
fit <- PET(A ~ age + sex, yname='Y', data=dat)
summary(fit)
confint(fit)
fit$tuning$candidates

# Binary outcome; the ATE is a risk difference.
fit.binary <- PET(A ~ age + sex, yname='event', data=dat,
  augmentation=TRUE, out.formula=event ~ age + sex, family='binomial')
summary(fit.binary)

# Fix either or both of the selectable hyperparameters.
fit.manual <- PET(A ~ age + sex, yname='Y', data=dat,
  K=50, beta.min=.29, beta.max=.99, degree=2)

# Supply external predictions. Columns specify both potential outcomes.
fit.external <- PET(ps.estimate=fit.binary$propensity,
  out.estimate=fit.binary$outcome.predictions,
  zname='A', yname='event', data=dat, augmentation=TRUE, family='binomial')

# Same plot structure as paper v2 and the supplied demo.
if (requireNamespace('ggplot2',quietly=TRUE)) {
  p <- plot(fit)
  print(p)
  # ggplot2::ggsave('trajectory.png', p, width=10.8, height=7.6, dpi=180)
}
curves <- trajectory(fit)
head(curves$wate)
curves$selected

# Standalone beta weighting: shape parameters (2,2) give overlap weights.
bw <- BetaWeight(A ~ age + sex, yname='Y', data=dat, beta1=2, beta2=2)
summary(bw)
confint(bw)
head(bw$weights)
bw$effective.sample.size
