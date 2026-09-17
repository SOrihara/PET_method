# Optional reproducible example from paper v2. The doBy dataset is not bundled.
library(PET)
if (!requireNamespace('doBy', quietly=TRUE)) stop('Install doBy to run this example.')
data('fev', package='doBy', envir=environment())
dat <- subset(fev, Age >= 9)
dat$A <- as.integer(dat$Smoke == 'Yes')
dat$male <- as.integer(dat$Gender == 'Boy')
fit <- PET(A ~ Age + Ht + male, yname='FEV', data=dat)
summary(fit)
# q=1, beta.min=0.44; ATE about -0.08034, SE about 0.14954.
p <- plot(fit)
print(p)
trajectory(fit)$selected
# ggplot2::ggsave('trajectory-fev.png', p, width=10.8, height=7.6, dpi=180)
