---
author:
- John Imperato
authors:
- John Imperato
embed-metadata: false
execute:
  engine: knitr
  eval: false
jupyter: false
title: mrmr updated
toc-title: Table of contents
---

# Overview

This notebook documents extensions to the mrmr package's Stan model for
mark-recapture analysis. Updates include:

1.  Survey-specific random effects on detection probability
    (time-varying detection)
2.  Additional generated quantities for more convenient ecological
    inference, including
    -   population-level survival probability estimates between primary
        periods

    -   survey-specific detection probabilities

    -   individual log-likelihoods (for model comparison)

## Survey-specific Random Effects on Detection Probability

The original mrmr model assumes that all variability in detection
probabilities across surveys (secondary periods) is explained by the
fixed effects of measured covariates (i.e., air and water temperature,
survey effort, surveyor identity, etc.). All surveys share an intercept
term for detection (a baseline logit scale detection value), and the
effects of measured covariates are added to that intercept at the survey
level. If no detection covariates are included in the model, detection
probability will be identical for all surveys.

In the updated model, we introduce a random effects parameter to account
for *unobserved* heterogeneity in detection probability across surveys.
This captures survey-specific factors that are not reflected by fixed
predictors. Modeling detection heterogeneity at the survey level rather
than the individual level maintains the assumption that variability is
driven by the conditions of the survey rather than inherent differences
among animals (sex, body size, age, etc.).

We justify including random detection effects because fixed effects data
are not always available or consistently measured across all surveys,
limiting our ability to explicitly model detection variability.
Additionally, on-the-ground experience suggests that survey conditions
influence detection in ways that are not entirely captured by available
covariates. We believe that some sources of variation are difficult to
quantify but still affect detection probability. By incorporating a
random effect, we acknowledge these unmeasured influences and allow the
model to absorb unexplained variability, rather than forcing all
variation to be attributed to measured predictors. In some cases,
explaining the exact sources of heterogeneity is less critical than
obtaining the most accurate parameter estimates possible, particularly
when detection variability might otherwise bias survival, recruitment,
or abundance estimates.

While adding survey-level random effects can improve model flexibility
and robustness---as was the case when testing and assessing our updated
model---it can become redundant if highly explanatory fixed effects are
already included. If most of the variability in detection is accounted
for by measured covariates, the random effect may contribute little
additional explanatory power and could lead to overfitting or
difficulties in parameter interpretation.

### Implementation

Random effects for detection probability are implemented using the same
hierarchical structure as those for survival and recruitment, where a
hyperparameter (`sigma_detect`) controls the variance of normally
distributed random effects (`eps_detect`) across survey occasions,
paralleling the approach used for temporal variation in survival and
recruitment processes.

Below are the key code changes in each relevant block of the Stan model:

#### Parameters Block

*Original*

``` stan
parameters {
  // recruitment parameters
  real alpha_lambda;
  real<lower=0> sigma_lambda;
  vector[T] eps_lambda;
  
  // survival parameters
  vector[m_surv] beta_phi;
  real<lower=0> sigma_phi;
  vector<multiplier=sigma_phi>[T] eps_phi;
  
  // detection params
  vector[m_detect] beta_detect;
}
```

*Updated*

``` stan
parameters {
  // recruitment parameters
  real alpha_lambda;
  real<lower=0> sigma_lambda;
  vector[T] eps_lambda;
  
  // survival parameters
  vector[m_surv] beta_phi;
  real<lower=0> sigma_phi;
  vector[T] eps_phi;  // random effect on survival per primary period
  
  // detection parameters
  vector[m_detect] beta_detect;
  // <<--2/10/25: added for random effects on detection probability
  real<lower=0> sigma_detect;
  vector[Jtot] eps_detect;
}
```

#### Transformed Parameters Block

*Original*

``` stan
transformed parameters {
  vector[Jtot] logit_detect;
  vector<lower=0, upper=1>[T] lambda;
  
  // probability of entering population
  lambda = any_recruitment
           * inv_logit(alpha_lambda + eps_lambda * sigma_lambda);
  
  // probability of detection
  logit_detect = X_detect * beta_detect;
}
```

*Updated*

``` stan
transformed parameters {
  vector[Jtot] logit_detect;
  vector<lower=0, upper=1>[T] lambda;
  
  // probability of entering population (recruitment)
  lambda = any_recruitment
           * inv_logit(alpha_lambda + eps_lambda * sigma_lambda);
  
  // probability of detection including the session-specific random effect:
  // For each survey j, add the associated random effect
  for (j in 1:Jtot) {
    logit_detect[j] = X_detect[j] * beta_detect + eps_detect[j];
  }
}
```

#### Model Block

*Original*

``` stan
model {
  // priors
  alpha_lambda ~ std_normal();
  sigma_lambda ~ std_normal();
  eps_lambda ~ std_normal();
  beta_detect ~ std_normal();
  beta_phi ~ std_normal();
  sigma_phi ~ std_normal();
  eps_phi ~ normal(0, sigma_phi);
  
  target += reduce_sum(partial_sum_lupmf, Mseq, grainsize, X_surv, beta_phi,
                       eps_phi, logit_detect, lambda, gam_init, introduced,
                       t_intro, removed, t_remove, prim_idx, any_surveys, J,
                       j_idx, Y, Jtot, T);
}
```

*Updated*

``` stan
model {
  // priors for recruitment
  alpha_lambda ~ std_normal();
  sigma_lambda ~ std_normal();
  eps_lambda ~ std_normal();
  
  // priors for detection fixed effects
  beta_detect ~ std_normal();
  // <<-- 2/10/25: priors for detection random effects:
  sigma_detect ~ std_normal();
  eps_detect ~ normal(0, sigma_detect);
  
  // priors for survival
  beta_phi ~ std_normal();
  sigma_phi ~ std_normal();
  eps_phi ~ normal(0, sigma_phi);
  
  target += reduce_sum(partial_sum_lpmf, Mseq, grainsize, X_surv, beta_phi,
                       eps_phi, logit_detect, lambda, gam_init, introduced,
                       t_intro, removed, t_remove, prim_idx, any_surveys, J,
                       j_idx, Y, Jtot, T);
}
```

## Generated Quantities

The original mrmr model provides some population metrics as generated
quantities (abundance, recruitment) but lacks easy access to other
parameters of interest, including survey-specific detection
probabilities, population-level survival probability estimates between
primary periods, and individual log-likelihoods, which are useful for
model comparison.

### Implementation

The code below is a sub section of the updated model's generated
quantities block, showcasing the three new derived parameters and how
they are calculated.

``` stan
// Additional derived quantities
vector[T-2] overall_phi;       // Overall survival for transitions
vector[Jtot] p;                // Detection probabilities for each survey
vector[M] log_lik;             // Individual log-likelihoods

//-----------------------------------------------------------------
// 1) Compute detection probabilities for each survey.
for (j in 1:Jtot) {
  p[j] = inv_logit(X_detect[j] * beta_detect + eps_detect[j]);
}

// [...other generated quantities code...]

//-----------------------------------------------------------------
// 4) Compute overall survival for real individuals only.
{
  // There are T-2 transitions: from period 2->3, 3->4, ..., T-1->T.
  for (t in 2:(T - 1)) {
    real sum_phi = 0;
    int real_count = 0;
    for (i in 1:M) {
      if (w[i] == 1) {  // Only include real individuals
        sum_phi += inv_logit(X_surv[i] * beta_phi + eps_phi[t]);
        real_count += 1;
      }
    }
    overall_phi[t - 1] = sum_phi / real_count;
  }
}
```

## Testing and Validation

The modified model has been tested with *Rana sierrae* mark-recapture
datasets from MLRG's site 54188 and from the California Department of
Fish and Wildlife's Mossy Pond study. We find:

1.  Improved model fit as assessed by LOO (made possible by the addition
    of `log_lik`)

2.  More realistic estimates of detection probability with appropriate
    uncertainty

3.  Survival and abundance estimates that better account for detection
    heterogeneity
