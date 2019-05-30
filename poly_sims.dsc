#nohup dsc --replicate 100 --host config.yml -c 4 poly_sims.dsc > dsc.out &

DSC:
    define:
        mr: ivw, egger, mrp, wm, twas, wm, gsmr
        cause_analysis: cause, cause_sigma_g
    run: simulate*gw_sig,
         simulate*LCV,
         simulate*mr,
         simulate*cause_params*cause_analysis
    replicate: 5
    output: res1
    exec_path: R

####### Simulate Data ##########
simulate: R(library(causeSims);
            snps <- readRDS("data/chr19_snpdata_hm3only.RDS");
            evd_list <- readRDS("data/evd_list_chr19_hm3.RDS");
            dat <- sum_stats(snps, evd_list,
                  n_copies = 30,
                  n1 = n1, n2=n2,
                  h1=h1, h2=h2,
                  neffect1 = neffect1, neffect2 = neffect2,
                  tau = qot["tau"], omega = qot["omega"], q = qot["q"],
                  cores = 4, ld_prune_pval_thresh = 0.01,
                  r2_thresh = 0.1))

    qot: c(q = 0, omega = 0, tau = 0),
        #c(q = 0, omega=0, tau = 0.09),
        #c(q = 0.3, omega = 0.04, tau = 0),
        #c(q = 0.3, omega = 0.07, tau = 0),
        #c(q = 0.3, omega = 0.09, tau = 0)
    n1: 10000
    n2: 10000
    h1:  0.3
    h2:  0.3
    neffect1: 1000
    neffect2: 1000
    $sim_params: c(qot, h1 = h1, h2 = h2, n1 =n1, n2 =n2, neffect1 = neffect1, neffect2 = neffect2)
    $dat: dat

# Count how many variants are genome-wide significant for M. Also collect parameters,
# it will be faster to get them from this module than from simulate because the objects are smaller
gw_sig: R(if(no_ld){
            m_sig <- with($(dat), sum(p_value_nold < thresh ));
            y_sig <- with($(dat), sum(2*pnorm(-abs(beta_hat_2_nold/seb2)) < thresh ));
          }else{
            m_sig <- with($(dat), sum(p_value < thresh & ld_prune==TRUE));
            y_sig <- with($(dat), sum(2*pnorm(-abs(beta_hat_2/seb2)) < thresh & ld_prune==TRUE));
          };

          params <- $(sim_params);
          tau <- params["tau"];
          omega <- params["omega"];
          q <- params["q"];
          h1 <- params["h1"];
          h2 <- params["h2"];
          neffect1 <- params["neffect1"];
          neffect2 <- params["neffect2"];
          gamma <- sqrt(tau*sum(h2)/sum(h1));
          eta <- sqrt(abs(omega)*sum(h2)/sum(h1))*sign(omega);

          #LCV parameters
          q.1 <- sqrt(q);
          q.2 <- eta * sqrt(q) * sqrt(h1) / sqrt(h2);
          gcp = (log(q.2^2) - log(q.1^2)) / (log(q.2^2) + log(q.1^2));
          )
    thresh: 5e-8
    no_ld: TRUE, FALSE
    $m_sig: m_sig
    $y_sig: y_sig
    $q: params["q"]
    $omega: params["omega"]
    $tau: params["tau"]
    $h1: params["h1"]
    $h2: params["h1"]
    $n1: params["n1"]
    $n2: params["n2"]
    $neffect1: params["neffect1"]
    $neffect2: params["neffect2"]
    $lcv_q1: q.1
    $lcv_q2: q.2
    $lcv_gcp: gcp


######### CAUSE #############
# Parameter estimation is separate from analysis for flexibility

cause_params: R(library(causeSims);
                params <- cause_params_sims($(dat), null_wt = null_wt, no_ld=no_ld))
    null_wt: 10
    no_ld: TRUE, FALSE
    $cause_params: params

cause: R(library(causeSims);
         library(cause);
         cause_res <- cause_sims($(dat), $(cause_params), no_ld = no_ld);
         z <- -1*summary(cause_res)$z;
         p <- pnorm(-z);
         quants <- summary(cause_res)$quants)
    no_ld: TRUE, FALSE
    $cause_res: cause_res
    $sigma_g: cause_res$sigma_g
    $eta_med_2: quants[[1]][1,2]
    $q_med_2: quants[[1]][1,3]
    $eta_med_3: quants[[2]][1,2]
    $gamma_med_3: quants[[2]][1,1]
    $q_med_3: quants[[2]][1,3]
    $z: z
    $p: p

cause_sigma_g: R(library(causeSims);
                 library(cause);
                 tau <- $(sim_params)["tau"];
                 omega <- $(sim_params)["omega"];
                 q <- $(sim_params)["q"];
                 if(!((q == 0 & tau == 0 & omega == 0) |
                     (q == q_ex & tau == 0 & omega == eff) |
                     (q == 0 & tau  == eff & omega == 0))){
                   cause_res <- sigma_g <- eta_med_2 <- q_med_2 <- NA;
                   eta_med_3 <- gamma_med_3 <- q_med_3 <- z <- p <- NA;
                 }else{
                   h1 <- $(sim_params)["h1"];
                   h2 <- $(sim_params)["h2"];
                   effect <- as.numeric(sqrt(eff*h1/h2));
                   sigma_g <- get_sigma(effect, quant);
                   cause_res <- cause_sims($(dat), $(cause_params), sigma_g = sigma_g,
                                          no_ld = no_ld);
                   z <- -1*summary(cause_res)$z;
                   p <- pnorm(-z);
                   sigma_g <- cause_res$sigma_g;
                   quants <- summary(cause_res)$quants;
                   eta_med_2 <-  quants[[1]][1,2];
                   q_med_2 <- quants[[1]][1,3];
                   eta_med_3 <- quants[[2]][1,2];
                   gamma_med_3 <- quants[[2]][1,1];
                   q_med_3 <- quants[[2]][1,3];
              }
          )
    no_ld: TRUE, FALSE
    quant: 0.51, 0.65, 0.8
    eff: 0.04
    q_ex: 0.3
    $cause_res: cause_res
    $sigma_g: sigma_g
    $eta_med_2: eta_med_2
    $q_med_2: q_med_2
    $eta_med_3: eta_med_3
    $gamma_med_3: gamma_med_3
    $q_med_3: q_med_3
    $z: z




## Other MR methods
ivw: R(library(causeSims);
       res <- ivw($(dat), p_val_thresh=thresh, no_ld = no_ld);
       )
    thresh: 5e-8
    no_ld: TRUE, FALSE
    $z: res$z
    $p: res$p

egger: R(library(causeSims);
       res <- egger($(dat), p_val_thresh=thresh, no_ld = no_ld);
       )
    thresh: 5e-8
    no_ld: TRUE, FALSE
    $z: res$z
    $p: res$p

mrp: R(library(causeSims);
       res <- mrpresso($(dat), p_val_thresh=thresh, no_ld = no_ld);
       )
    thresh: 5e-8
    no_ld: TRUE, FALSE
    $z: res$z
    $p: res$p

twas: R(library(causeSims);
       res <- twas($(dat), p_val_thresh=thresh, no_ld = no_ld);
       )
    thresh: 5e-8
    no_ld: TRUE, FALSE
    $z: res$z
    $p: res$p

wm: R(library(causeSims);
       res <- weighted_median($(dat), p_val_thresh=thresh, no_ld = no_ld);
       )
    thresh: 5e-8
    no_ld: TRUE, FALSE
    $z: res$z
    $p: res$p

gsmr: R(library(causeSims);
        evd_list <- readRDS("data/evd_list_chr19_hm3.RDS");
        res <- gsmr_sims($(dat), evd_list, p_val_thresh  = 5e-8, no_ld = FALSE);
        if(!is.null(res)){
           z <- res$bxy/res$bxy_se;
           est <- res$bxy;
           p <- res$bxy_pval;
        }else{
           z <- est <- p <-  NA;
        }
      )
    thresh: 5e-8
    $z: z
    $p: p
    $est_gsmr: est
    $gsmr: res


##LCV
LCV: R(library(causeSims);
       res <- lcv_sims($(dat),no_ld = no_ld, sig.thresh = thresh);
       )
    thresh: 30
    no_ld: TRUE, FALSE
    $p: res$pval.gcpzero.2tailed
    $gcp_med: res$gcp.pm
    $gcp_pse: res$gcp.pse
    $gcp_obj: res


