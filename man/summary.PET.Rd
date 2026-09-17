\name{summary.PET}
\alias{summary.PET}
\alias{print.PET}
\alias{print.summary.PET}
\alias{coef.PET}
\alias{vcov.PET}
\alias{confint.PET}
\title{Summaries and Inference for PET Fits}
\usage{
\method{print}{PET}(x, digits = 4L, ...)
\method{summary}{PET}(object, ...)
\method{print}{summary.PET}(x, digits = 4L, ...)
\method{coef}{PET}(object, ...)
\method{vcov}{PET}(object, ...)
\method{confint}{PET}(object, parm, level = object$conf.level, ...)
}
\arguments{
\item{x, object}{A fitted PET object, or its summary for \code{print.summary.PET}.}
\item{digits}{Printing precision.}
\item{parm}{Omit or supply \code{"ATE"} (or 1).}
\item{level}{Normal confidence level.}
\item{...}{Reserved for S3 compatibility.}
}
\description{Extract or print the ATE, standard error, normal confidence interval, chosen tuning parameters, and variance assumptions.}
\value{\code{summary} returns a \code{summary.PET} list including a coefficient table and diagnostics. \code{coef} returns a named ATE vector; \code{vcov} a 1 by 1 variance matrix; \code{confint} a 1 by 2 matrix. Print methods invisibly return their input.}
