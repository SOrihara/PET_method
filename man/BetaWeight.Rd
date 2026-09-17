\name{BetaWeight}
\alias{BetaWeight}
\alias{print.BetaWeight}
\alias{summary.BetaWeight}
\alias{print.summary.BetaWeight}
\alias{coef.BetaWeight}
\alias{vcov.BetaWeight}
\alias{confint.BetaWeight}
\title{Two-Parameter Beta Weighting for a Weighted Average Treatment Effect}
\description{Estimates a normalized beta-weighted treatment contrast separately from PET extrapolation. The two parameters use the beta-family shape convention of Matsouaka and Zhou.}
\usage{
BetaWeight(ps.formula = NULL, ps.estimate = NULL, trtgrp = NULL,
    zname = NULL, yname = NULL, data,
    beta1 = 2, beta2 = 2, family = "gaussian",
    ps.method = "glm", ps.control = list(),
    variance = c("auto", "estimated", "fixed"), conf.level = 0.95,
    na.action = c("fail", "omit"), contrasts = NULL)

\method{print}{BetaWeight}(x, digits = 4L, ...)
\method{summary}{BetaWeight}(object, ...)
\method{print}{summary.BetaWeight}(x, digits = 4L, ...)
\method{coef}{BetaWeight}(object, ...)
\method{vcov}{BetaWeight}(object, ...)
\method{confint}{BetaWeight}(object, parm, level = object$conf.level, ...)
}
\arguments{
\item{ps.formula}{Treatment model formula for an internal logistic GLM.}
\item{ps.estimate}{External propensity vector for the treated group, or a two-column matrix named by treatment levels. Overrides the formula. Other learners are supported only via externally computed predictions.}
\item{trtgrp}{Treated level. Defaults to the last observed label in alphabetical order. The contrast is always treated minus control.}
\item{zname, yname}{Treatment and outcome column names. Treatment name can be inferred from the propensity formula.}
\item{data}{Data frame of independent observations with a binary treatment.}
\item{beta1, beta2}{Finite, strictly positive beta-family shape parameters. Defaults are 2 and 2 (overlap weights). They are not PET's fitting-grid endpoints.}
\item{family}{\code{"gaussian"} for continuous outcomes or \code{"binomial"} for 0/1 outcomes. A corresponding family object is accepted. No outcome regression is fitted. Binary effects are risk differences.}
\item{ps.method}{Only \code{"glm"} is supported internally.}
\item{ps.control}{Named GLM controls: \code{epsilon}, \code{maxit}, \code{trace}.}
\item{variance}{\code{"auto"} uses a generalized version of the supplied demo's empirical-score correction for an internal logistic GLM and treats external PS predictions as fixed. \code{"estimated"} requires internal GLM. \code{"fixed"} omits PS estimation correction.}
\item{conf.level, level}{Normal confidence level, strictly between 0 and 1.}
\item{na.action}{Reject missing inputs by default; \code{"omit"} applies a common row mask. Infinite values fail.}
\item{contrasts}{Optional factor contrasts passed to \code{model.matrix}. Explicit dummy columns are also accepted.}
\item{x, object}{A fitted \code{BetaWeight} object or its summary.}
\item{digits}{Printing precision.}
\item{parm}{The estimand name returned by \code{coef}, or coefficient index 1.}
\item{...}{Reserved for S3 compatibility.}
}
\details{
Common inputs use the same argument names and first-six-argument order as
\code{PSweight::PSweight}. Supply them by name. The weighting family is always
beta, so its two shapes replace a weight-family selector. Model matrices are
prepared automatically. This binary-treatment, unaugmented interface is not a
complete replacement for PSweight.

The tilting function is
\deqn{h(e) = e^{\beta_1-1}(1-e)^{\beta_2-1}.}
Treatment and control weights are \eqn{h(e)/e} and \eqn{h(e)/(1-e)}, respectively.
The estimate is the difference between the separately normalized weighted outcome
means. The original paper's optional scaling constant \eqn{2^{\beta_1+\beta_2-2}}
is omitted because it cancels from the normalized estimates and their influence functions.

Shapes (1,1), (2,1), (1,2), and (2,2) correspond to ATE/IPW, ATT, ATC, and ATO/overlap.
Other values target a WATE defined by \eqn{h}. The PET trajectory with exponent
\eqn{b} corresponds to \code{beta1 = beta2 = 1 + b}. Shapes below 1 can emphasize
the propensity-score tails. Both shapes are chosen by the analyst; there is no
automatic selection. Reversing treatment labels while preserving the same target
population requires swapping the shapes as well.

Let \eqn{r_1=Ah/e}, \eqn{r_0=(1-A)h/(1-e)}, and let \eqn{\mu_1,\mu_0}
denote the two weighted means. The fixed-PS influence function is
\deqn{r_1(Y-\mu_1)/\bar r_1-r_0(Y-\mu_0)/\bar r_0.}
For internally estimated PS, the implementation generalizes the supplied
\code{beta.w()} demo's empirical-score correction. With design vector \eqn{X},
score \eqn{S=X(A-e)}, information \eqn{I=\operatorname{mean}(SS^T)}, and
\eqn{L=(\beta_1-1)(1-e)-(\beta_2-1)e}, the additional term is \eqn{S^TI^{-1}D}, where
\deqn{D=\operatorname{mean}\{Xh[L-(A-e)][A(Y-\mu_1)-(1-A)(Y-\mu_0)]/[Ae+(1-A)(1-e)]\}/\bar h.}
The standard error is the square root of the mean squared influence divided by n.
For equal shapes this agrees with the author's demo, including its finite-sample
variance convention. It is not asserted to equal another implementation's
observed-bread or expected-information sandwich in finite samples.

This function performs weighting only: no polynomial extrapolation, outcome
augmentation, cross-fitting, trimming, clipping, or bootstrap. External predictions
are not refitted, and their estimation uncertainty is not recovered. Intervals
condition on the specified shapes. Identification of the intended nonconstant
tilted target requires a correctly specified propensity score. All PS values
must be strictly between 0 and 1. Numerically underflowed or overflowed weights
raise an error instead of silently changing the target.

Normal intervals can undercover in finite samples with limited overlap,
particularly for IPW-like weights or shapes below one. Agreement of point
estimates with an independent implementation does not validate interval coverage.
Inspect the propensity distribution and effective sample sizes. Bootstrap remains
a future package feature; validation-only bootstrap experiments do not add that
capability to this function.
}
\value{An object of class \code{BetaWeight} with estimate, standard error,
confidence interval, \code{estimand}, shapes, influence values, propensity predictions,
\code{tilting} (h), \code{weights} (the observed-arm raw weights),
\code{normalized.weights} (summing to 1 within each arm), \code{weighted.means},
\code{effective.sample.size} by arm, model fits, diagnostics, and row indices.
Weight vectors correspond to \code{row.index} in the original data after any omission.}
\references{
Matsouaka, R. A. and Zhou, Y. (2024). Causal inference in the absence of positivity:
The role of overlap weights. Biometrical Journal, 66(4), e2300156.
\doi{10.1002/bimj.202300156}. Author preprint, section 4.2:
\url{https://arxiv.org/abs/2011.01388}.
}
\seealso{\code{\link{PET}}, \code{\link{trajectory}}}
\examples{
set.seed(17)
d <- data.frame(x = rnorm(250))
d$A <- rbinom(250, 1, plogis(-0.3 + 0.4*d$x))
d$Y <- 0.7*d$A + d$x + rnorm(250)
bw <- BetaWeight(A ~ x, yname = "Y", data = d, beta1 = 2, beta2 = 2)
summary(bw)
confint(bw)
head(bw$weights)
asymmetric <- BetaWeight(A ~ x, yname = "Y", data = d,
                         beta1 = 1.5, beta2 = 2.5)
coef(asymmetric)
}
