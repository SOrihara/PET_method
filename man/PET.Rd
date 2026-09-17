\name{PET}
\alias{PET}
\title{Estimate the Average Treatment Effect Using PET}
\description{Polynomial approximation and extrapolation to the target average treatment effect (PET) and its augmented version (AIPW-PET), following version 2 of Orihara, Komukai and Li (2026). The supplied PET numerical core is retained.}
\usage{
PET(ps.formula = NULL, ps.estimate = NULL, trtgrp = NULL,
    zname = NULL, yname = NULL, data, augmentation = FALSE,
    out.formula = NULL, out.estimate = NULL, family = "gaussian",
    ps.method = "glm", ps.control = list(), out.method = "glm",
    out.control = list(), K = 50L, beta.min = NULL, beta.max = 0.99,
    degree = NULL, beta.candidates = seq(0.44, 0.69, by = 0.05),
    degree.candidates = 1:4, kappa = NULL,
    variance = c("auto", "estimated", "fixed"), conf.level = 0.95,
    na.action = c("fail", "omit"), contrasts = NULL)
}
\arguments{
\item{ps.formula}{Treatment model formula, e.g. \code{A ~ age + sex}. Used when \code{ps.estimate} is absent.}
\item{ps.estimate}{External propensity vector for \code{trtgrp}, or a numeric two-column probability matrix with columns named by treatment levels. Named columns are reordered to match labels. Unnamed columns are interpreted in alphabetical label order, with a warning.}
\item{trtgrp}{Treated level; defaults to the last level in alphabetical order. The ATE is treated minus control.}
\item{zname, yname}{Treatment and outcome column names in \code{data}. They may be inferred from the respective formula responses.}
\item{data}{Data frame containing the analysis variables. Observations must be independent.}
\item{augmentation}{Use AIPW-PET when \code{TRUE}; default \code{FALSE} uses PET.}
\item{out.formula}{Outcome formula containing covariates only, e.g. \code{Y ~ age + sex}. Separate models are fitted in each treatment group, as in PSweight. Do not put treatment on the right-hand side.}
\item{out.estimate}{Numeric matrix of potential outcome predictions for every observation under both treatment levels. Two columns, named by treatment levels. Not just predictions under the observed treatment. Overrides \code{out.formula}.}
\item{family}{Outcome family: \code{"gaussian"} (default, identity link) or \code{"binomial"} (logit link). A corresponding R family object is also accepted. Binary responses must be coded 0/1; the effect is a risk difference.}
\item{ps.method, out.method}{Only \code{"glm"} is supported internally. Fit GBM, SuperLearner, or other learners externally and pass predictions through \code{ps.estimate} or \code{out.estimate}. Other method values are rejected, including when predictions are supplied.}
\item{ps.control, out.control}{Named GLM controls: \code{epsilon}, \code{maxit}, and \code{trace}. Model data, response, weights, and offsets cannot be replaced through these lists.}
\item{K}{Number of equally spaced fitting beta values; at least 2.}
\item{beta.min}{Fixed lower fitting endpoint. \code{NULL} selects it from \code{beta.candidates}. Must be nonnegative and strictly below \code{beta.max}.}
\item{beta.max}{Upper fitting endpoint, strictly between 0 and 1.}
\item{degree}{Fixed polynomial degree. \code{NULL} selects it from \code{degree.candidates}. Must be an integer from 1 to \code{K-1}.}
\item{beta.candidates, degree.candidates}{Candidate sets for Algorithm 1. A fixed endpoint or degree overrides only its corresponding candidate set.}
\item{kappa}{Variance target relative to ordinary IPW or AIPW. Default \code{5/6} for PET and \code{1} for AIPW-PET. Must be in (0,1].}
\item{variance}{For PET, \code{"auto"} uses the original estimated-PS correction for internal logistic GLM and fixed-PS variance otherwise. \code{"estimated"} requires that GLM; \code{"fixed"} omits PS estimation correction. For AIPW-PET, \code{"auto"} and \code{"fixed"} both use the augmented influence function in equation (10); \code{"estimated"} is not supported.}
\item{conf.level}{Normal confidence level, between 0 and 1.}
\item{na.action}{\code{"fail"} rejects missing analysis inputs; \code{"omit"} removes the same rows from outcomes, models, and predictions and records the row indices. Infinite inputs always fail.}
\item{contrasts}{Optional named contrast matrices passed to \code{model.matrix}. Use \code{relevel} to specify a reference factor level. Explicit dummy columns are accepted.}
}
\details{
Prepublication validation found that the retained high-degree projection can
produce runtime-dependent standard errors and hence different automatically
selected fits. In the FEV example, Windows R 4.3.1 selected degree 1 whereas
R 4.6.1 selected degree 4. Agreement with the supplied source within a runtime
does not establish numerical reproducibility across runtimes. The original
numerical core has not been changed; resolve this issue before relying on
automatic selection for a public release.

For each beta, PET estimates normalized weighted outcome means with weights
\eqn{\{e(X)(1-e(X))\}^{\beta}}. It regresses the resulting differences on raw beta
powers, using the intercept as the ATE estimate. The projection matrix and empirical
score correction are retained from the supplied \code{polex()} code; the normal-equation
inverse has not been replaced with an alternative solver. Very narrow intervals and high
degrees can therefore inherit the source program's numerical sensitivity.

Algorithm 1 uses strict inequalities: for each degree choose the smallest beta.min
meeting the variance target, or the largest candidate if none qualifies. Among those
choices select the highest qualifying degree, or the smallest degree if none qualifies.
The full search table and target status are retained. Failure to meet the target is reported.
The ordinary IPW comparator uses the PSweight-style logistic sandwich; PET itself uses
the empirical-score correction in the supplied core, which is not identical in finite samples.

AIPW-PET forms the beta-weighted means of the ordinary AIPW pseudo-outcome before
the same extrapolation. Its standard error uses equation (10), including covariances
between the beta estimates. It is not the regression intercept standard error from
\code{summary(lm(...))}. Intervals condition on chosen hyperparameters and do not include
selection uncertainty or extrapolation bias. Double robustness is conditional on the
paper's extrapolation condition. General nuisance estimation corrections for arbitrary
learners or misspecified models are not claimed. External predictions are not refitted;
cross-fitting is not performed automatically. Bootstrap is deferred.

This interface is inspired by PSweight but supports only binary treatment and the ATE
difference, continuous or binary responses. It does not implement ATT, ratios, clustered
data, trimming, sample weights, offsets, or PSweight's complete interface. No propensity
clipping, outcome clipping, or outcome-family autodetection is performed.
}
\value{An object of class \code{PET}, containing \code{estimate}, \code{se}, \code{conf.int}, \code{influence}, raw polynomial \code{coefficients}, \code{alpha}, component beta estimates, \code{baseline}, \code{tuning} (including the search table), \code{propensity}, \code{outcome.predictions}, \code{model.fits}, \code{row.index}, \code{omitted}, \code{group}, and \code{diagnostics}. The retained prepared inputs support trajectory calculations without refitting nuisance models.}
\references{Orihara, S., Komukai, S., and Li, F. (2026). Estimating the average treatment effect under limited overlap via Polynomial Approximation and Extrapolation. arXiv:2608.09329v2. \doi{10.48550/arXiv.2608.09329}.}
\seealso{\code{\link{BetaWeight}}, \code{\link{trajectory}}, \code{\link{plot.PET}}, \code{\link{summary.PET}}}
\examples{
set.seed(123)
d <- data.frame(x = rnorm(300), sex = factor(rep(c("F", "M"), 150)))
d$A <- rbinom(300, 1, plogis(-0.4 + 0.5 * d$x))
d$Y <- 1 + 0.75 * d$A + 0.4 * d$x + rnorm(300)
fit <- PET(A ~ x + sex, yname = "Y", data = d,
           beta.min = 0.44, degree = 2)
summary(fit)
confint(fit)
aug <- PET(A ~ x + sex, yname = "Y", data = d,
           augmentation = TRUE, out.formula = Y ~ x + sex,
           beta.min = 0.44, degree = 2)
coef(aug)
}
