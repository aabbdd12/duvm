* Section3_4_selection.do — the numbers of Section 3.4 of the note (Selection
* of the buyers, option selection of duvm 1.1), written to out/sec34_*.csv:
*   sec34_oracle        the probit, the Mills ratio and the unit-value equation
*                       rebuilt with Stata's probit and areg: largest gaps; and
*                       rho, the within-cluster correlation of lambda and ln x
*   sec34_constructed   the constructed case: quality elasticity with and without
*                       the correction, against the truth (0.10)
*   sec34_constructed_se  on that case, linearized against bootstrap std. err.
*                       (500 replications of the whole procedure)
*   sec34_engel         the Engel curves under selection: their variance of the
*                       unit-value slope against that of the estimates
*   sec34_mexico_diag   the Mexican data: Table D3 (unweighted and weighted),
*                       the quality elasticity with and without the correction
*   sec34_mexico_se     the Mexican data: bootstrap / linearized std. err.
*                       (100 replications)
* global BOOT 0 reduces the bootstraps to 50 and 40 replications.
do _setup.do
if "$BOOT" == "" global BOOT 1
local rc = cond($BOOT, 500, 50)
local rm = cond($BOOT, 100, 40)

* ---------------------------------------------------------------- oracle
use "$DATA", clear
qui duvm $GOODS, $OPTS selection vce(none) notable
tempname B1 TH O
matrix `B1' = e(beta1)
matrix `TH' = e(sel_theta)
matrix `O' = J(4, 3, .)
qui gen byte es = e(sample)
qui keep if es
qui gen double lnexp = ln(hh_current_inc)
qui gen double lnhhs = ln(hhsize)
qui tab sex, gen(sx)
qui tab educ, gen(ed)
* the order of duvm: ln x, ln household size, indcon(), then the indicators of indcat()
local X "lnexp lnhhs age sx2"
qui levelsof educ, local(el)
local ne : word count `el'
forvalues l = 2/`ne' {
    local X "`X' ed`l'"
}
local MX ""
foreach v of local X {
    qui bysort psu: egen double m_`v' = mean(`v')
    local MX "`MX' m_`v'"
}
qui xtset psu
local lx "lnexp"
local Xo : list X - lx
local j 0
foreach g of global GOODS {
    local ++j
    qui gen byte d_`g' = (w`g' > 0 & w`g' < .)
    qui probit d_`g' `X' `MX', tolerance(1e-13) ltolerance(1e-14) nrtolerance(1e-13)
    qui predict double xb_`g', xb
    qui gen double lam_`g' = normalden(xb_`g') / normal(xb_`g')
    qui areg luv`g' `X' lam_`g' if d_`g' & luv`g' < ., absorb(psu)
    matrix `O'[`j', 1] = abs(_b[lnexp] - el(`B1', 1, `j'))
    matrix `O'[`j', 2] = abs(_b[lam_`g'] - el(`TH', 1, `j'))
    * within-cluster correlation of lambda and ln x given the other
    * regressors, on the reporters (Table D3 gives 1/(1-rho^2))
    qui xtreg lam_`g' `Xo' if d_`g' & luv`g' < ., fe
    qui predict double rl_`g', e
    qui xtreg lnexp `Xo' if d_`g' & luv`g' < ., fe
    qui predict double rx_`g', e
    qui corr rl_`g' rx_`g' if d_`g' & luv`g' < .
    matrix `O'[`j', 3] = r(rho)
}
matrix rownames `O' = $GOODS
matrix colnames `O' = gap_beta1 gap_theta rho_lambda_lnx
wcsv sec34_oracle `O'
matlist `O', format(%9.2e) title("Oracle: duvm against probit + areg")

* ---------------------------------------------------------------- constructed case
* two goods; the errors of purchase and of the unit value correlated at 0.7;
* the probit of the model (x, its cluster mean, an exclusion variable zdist);
* quality elasticity 0.10
capture program drop _mkcase
program define _mkcase
    clear
    set seed 20260926
    qui set obs 6000
    qui gen int psu = ceil(_n / 15)
    qui gen double x  = 5 + rnormal()
    qui bysort psu: egen double xm = mean(x)
    qui gen double hhsize = ceil(8 * runiform())
    qui gen double hh_current_inc = exp(x)
    qui gen double zdist = rnormal()
    foreach g in a b {
        qui bysort psu: gen double p`g' = rnormal(0, 0.3) if _n == 1
        qui bysort psu: replace p`g' = p`g'[1]
        qui gen double v`g' = rnormal()
        qui gen double u`g' = 0.7 * v`g' + sqrt(1 - 0.49) * rnormal()
        qui gen byte buy`g' = (0.2 + 0.8 * (x - 5) - 0.4 * (xm - 5) + 0.6 * zdist + v`g' > 0)
        qui gen double w`g'   = cond(buy`g', 0.10 + 0.02 * (x - 5) - 0.05 * p`g' + 0.02 * rnormal(), 0)
        qui gen double luv`g' = cond(buy`g', p`g' + 0.10 * (x - 5) + 0.3 * u`g', .)
    }
end
local cbase "a b, hhsize(hhsize) expend(hh_current_inc) cluster(psu) notable"
_mkcase
tempname C A Bt S
matrix `C' = J(2, 3, .)
qui duvm `cbase' selection selvars(zdist) vce(cluster)
matrix `C'[1, 1] = el(e(elast_qual), 1, 1)
matrix `C'[1, 2] = el(e(se_elast_qual), 1, 1)
matrix `A' = e(se_elast_exp), e(se_elast_qual), e(se_sel_theta), ///
    el(e(se_elast_price), 1, 1), el(e(se_elast_price), 2, 2)
qui duvm `cbase' vce(cluster)
matrix `C'[2, 1] = el(e(elast_qual), 1, 1)
matrix `C'[2, 2] = el(e(se_elast_qual), 1, 1)
forvalues r = 1/2 {
    matrix `C'[`r', 3] = (`C'[`r', 1] - 0.10) / `C'[`r', 2]
}
matrix rownames `C' = with_selection without_selection
matrix colnames `C' = b1_good_a se z_vs_truth
wcsv sec34_constructed `C'
matlist `C', format(%9.4f) title("Constructed case: quality elasticity of good a (truth 0.10)")

qui duvm `cbase' selection selvars(zdist) vce(bootstrap, reps(`rc') seed(7))
matrix `Bt' = e(se_elast_exp), e(se_elast_qual), e(se_sel_theta), ///
    el(e(se_elast_price), 1, 1), el(e(se_elast_price), 2, 2)
matrix `S' = `A' \ `Bt' \ J(1, 8, .)
forvalues c = 1/8 {
    matrix `S'[3, `c'] = `Bt'[1, `c'] / `A'[1, `c']
}
matrix rownames `S' = linearized bootstrap boot_over_lin
matrix colnames `S' = exp_a exp_b qual_a qual_b theta_a theta_b own_price_a own_price_b
wcsv sec34_constructed_se `S'
matlist `S', format(%9.4f) title("Constructed case: std. err., `rc' replications")

* ---------------------------------------------------------------- Engel curves
use "$DATA", clear
qui duvm $GOODS, $OPTS selection vce(cluster) notable
tempname E
matrix `E' = J(4, 2, .)
forvalues j = 1/4 {
    qui _duvm_engel, good(`j')
    matrix Vs = r(Vs)
    matrix `E'[`j', 1] = r(dev_b1)
    matrix `E'[`j', 2] = abs(sqrt(Vs[6, 6]) - el(e(se_elast_qual), 1, `j')) / el(e(se_elast_qual), 1, `j')
}
matrix rownames `E' = $GOODS
matrix colnames `E' = gap_slope rel_gap_se
wcsv sec34_engel `E'
matlist `E', format(%9.2e) title("Engel curves under selection")

* ---------------------------------------------------------------- Mexican data
* unweighted, no exclusion variable: Table D3 and the quality elasticity with
* and without the correction; then with the sampling weights (the example)
use "$DATA", clear
tempname q0 s0 q1 s1 SD SW M
qui duvm $GOODS, $OPTS vce(cluster) notable
matrix `q0' = e(elast_qual)
matrix `s0' = e(se_elast_qual)
qui duvm $GOODS, $OPTS selection vce(cluster) notable
matrix `q1' = e(elast_qual)
matrix `s1' = e(se_elast_qual)
matrix `SD' = e(sel_diag)
qui duvm $GOODS [aw=sweight], $OPTS selection vce(none) notable
matrix `SW' = e(sel_diag)
matrix `M' = J(4, 11, .)
forvalues j = 1/4 {
    matrix `M'[`j', 1] = `SD'[`j', 2]
    matrix `M'[`j', 2] = `SD'[`j', 3]
    matrix `M'[`j', 3] = `SD'[`j', 4]
    matrix `M'[`j', 4] = `SD'[`j', 5]
    matrix `M'[`j', 5] = `O'[`j', 3]
    matrix `M'[`j', 6] = `q0'[1, `j']
    matrix `M'[`j', 7] = `s0'[1, `j']
    matrix `M'[`j', 8] = `q1'[1, `j']
    matrix `M'[`j', 9] = `s1'[1, `j']
    matrix `M'[`j', 10] = `s1'[1, `j'] / `s0'[1, `j']
    matrix `M'[`j', 11] = `SW'[`j', 5]
}
matrix rownames `M' = $GOODS
matrix colnames `M' = buy_pct pseudo_r2 perfect vif_b1 rho_lambda_lnx b1_nosel se_nosel b1_sel se_sel se_ratio vif_b1_weighted
wcsv sec34_mexico_diag `M'
matlist `M', format(%9.3f) title("Mexican data: Table D3 and the quality elasticity")

* bootstrap / linearized std. err. on the Mexican data (unweighted)
tempname A2 B2 R
qui duvm $GOODS, $OPTS selection vce(cluster) notable
matrix `A2' = e(se_elast_exp), e(se_elast_qual), e(se_sel_theta), vecdiag(e(se_elast_price))
qui duvm $GOODS, $OPTS selection vce(bootstrap, reps(`rm') seed(20260926)) notable
matrix `B2' = e(se_elast_exp), e(se_elast_qual), e(se_sel_theta), vecdiag(e(se_elast_price))
matrix `R' = J(4, 4, .)
forvalues j = 1/4 {
    matrix `R'[`j', 1] = `B2'[1, `j'] / `A2'[1, `j']
    matrix `R'[`j', 2] = `B2'[1, 4 + `j'] / `A2'[1, 4 + `j']
    matrix `R'[`j', 3] = `B2'[1, 8 + `j'] / `A2'[1, 8 + `j']
    matrix `R'[`j', 4] = `B2'[1, 12 + `j'] / `A2'[1, 12 + `j']
}
matrix rownames `R' = $GOODS
matrix colnames `R' = exp_elast qual_elast theta own_price
wcsv sec34_mexico_se `R'
matlist `R', format(%9.3f) title("Mexican data: bootstrap / linearized std. err., `rm' replications")
