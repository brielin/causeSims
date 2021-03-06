
#'@title Estimate CAUSE parameters for simulated data
#'@param dat  A simulated data frame created with sum_stats
#'@param null_wt Null weight in dirichlet prior on mixing parameters
#'@param no_ld Run with the nold data (T/F)
#'@return
#'@export
cause_params_sims <- function(dat, null_wt = 10, no_ld=FALSE, max_candidates=Inf){


   if(no_ld) dat <- process_dat_nold(dat)

    X <- dat  %>%
         select(snp, beta_hat_1, seb1, beta_hat_2, seb2) %>%
         new_cause_data(.)

    params <- est_cause_params(X, X$snp, null_wt = null_wt, max_candidates = max_candidates)
    return(params)
}

