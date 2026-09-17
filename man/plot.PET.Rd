\name{plot.PET}
\alias{plot.PET}
\alias{plot.PET_trajectory}
\title{Draw PET Trajectory Diagnostics}
\description{Draw the version 2 style faceted trajectory plot using ggplot2. Default error bars are plus/minus one standard error, not 95 percent confidence intervals.}
\usage{
\method{plot}{PET}(x, degree = 1:4,
  beta.min = c(0.14, 0.29, 0.44, 0.69),
  beta = c(0, seq(0.04, 0.69, by = 0.05)),
  error = c("se", "ci", "none"), ncol = 2L, ...)
\method{plot}{PET_trajectory}(x, error = c("se", "ci", "none"),
  ncol = 2L, conf.level = x$conf.level, ...)
}
\arguments{
\item{x}{A \code{PET} fit or \code{PET_trajectory} object.}
\item{degree, beta.min, beta}{Passed to \code{trajectory}; specify comparison settings and the display grid.}
\item{error}{\code{"se"} shows one SE; \code{"ci"} shows normal confidence limits; \code{"none"} omits error bars.}
\item{ncol}{Number of facet columns.}
\item{conf.level}{Level for \code{error="ci"}.}
\item{...}{Additional arguments passed from the PET method to the trajectory method; otherwise reserved.}
}
\value{A ggplot object. Print it to draw, add ggplot layers to customize, or pass it to \code{ggplot2::ggsave}.}
\details{Black points and lines are beta-weight estimates. Colored lines are PET polynomial fits. Triangles at zero use the beta.min selected for each degree, with a small horizontal offset to separate them from ordinary IPW/AIPW. The y-axis is shared across facets. This plot assesses sensitivity, not whether the extrapolation condition is true. Requires the optional ggplot2 package.}
