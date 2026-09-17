\name{trajectory}
\alias{trajectory}
\title{Calculate PET Sensitivity Trajectories}
\description{Calculate the beta-weight estimates, fitted polynomial trajectories, and extrapolated estimates used in the version 2 real-data figures and the supplied demo.}
\usage{
trajectory(object, degree = 1:4, beta.min = c(0.14, 0.29, 0.44, 0.69),
           beta = c(0, seq(0.04, 0.69, by = 0.05)))
}
\arguments{
\item{object}{A \code{PET} fit.}
\item{degree}{Polynomial degrees to display.}
\item{beta.min}{Lower fitting endpoints to compare; the selected endpoint per degree is also included.}
\item{beta}{Beta values on the display axis. Zero is always included. This is the display grid, not the fitting grid, which runs from beta.min to the fitted object's beta.max.}
}
\details{Nuisance predictions and design matrices from the fitted object are reused. For each displayed degree the primary fit's candidate set is used to choose the endpoint for the triangle at beta=0. This replaces the demo's FEV-specific hard-coded selections. For a primary fit with fixed beta.min, that endpoint is retained for the marker. The supplied core's beta-weight standard error at zero can differ slightly from the ordinary IPW selection comparator, as in the supplied demo.}
\value{A \code{PET_trajectory} list with \code{wate} (beta, estimate, se), \code{curves} (beta, estimate, degree, beta.min), \code{endpoints} (estimate, se, selected), and \code{selected} (per-degree beta.min and variance-target status).}
\seealso{\code{\link{PET}}, \code{\link{plot.PET}}}
