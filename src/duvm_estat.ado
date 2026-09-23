*! duvm_estat 1.0.0  2026-09-23  Abdelkrim Araar
*! estat after duvm: diagnostics, elasticities, quality
program define duvm_estat, rclass
    version 14.2
    if "`e(cmd)'" != "duvm" error 301
    gettoken sub 0 : 0, parse(" ,")
    local sub = lower("`sub'")
    if inlist("`sub'", "diag", "diagnostics", "diagnostic") {
        _duvm_estat_diag `0'
    }
    else if inlist("`sub'", "elast", "elasticities", "elasticity") {
        _duvm_estat_elast `0'
    }
    else if inlist("`sub'", "quality", "qual") {
        _duvm_estat_quality `0'
    }
    else {
        di as err "estat `sub' not allowed after duvm; use estat diagnostics, estat elasticities or estat quality"
        exit 198
    }
    return add
end

* ---------------------------------------------------------------------------
program define _duvm_estat_diag, rclass
    syntax [, DEC(integer 3)]
    local M = e(M)
    local goods `e(goods)'
    tempname T S Sf ome n1 n0 b1 el zeta B Bs w rep crep cpair
    matrix `S' = e(S)
    matrix `Sf' = e(Sf)
    matrix `ome' = e(omega)
    matrix `n1' = e(n1)
    matrix `n0' = e(n0)
    matrix `b1' = e(b1)
    matrix `el' = e(elast_exp)
    matrix `zeta' = e(zeta)
    matrix `B' = e(B)
    matrix `Bs' = e(B_sym)
    matrix `w' = e(shares_mean)
    matrix `rep' = e(N_report)
    matrix `crep' = e(N_clust_report)
    matrix `cpair' = e(N_clust_pair)
    local C = e(N_clust)
    local N = e(N)

    di as txt _n "Diagnostics for the unit-value model" _col(49) "Number of obs" _col(67) "= " as res %10.0fc `N'
    di as txt _col(49) "Number of clusters" _col(67) "= " as res %10.0fc `C'

    * ---- table 1: the data behind each good ----
    matrix `T' = J(`M', 7, .)
    local nwarn 0
    forvalues j = 1/`M' {
        local g : word `j' of `goods'
        matrix `T'[`j', 1] = `w'[1, `j'] * 100
        matrix `T'[`j', 2] = `rep'[1, `j']
        matrix `T'[`j', 3] = `rep'[1, `j'] / `N' * 100
        matrix `T'[`j', 4] = `crep'[1, `j']
        matrix `T'[`j', 5] = `n1'[1, `j']
        matrix `T'[`j', 6] = `n0'[1, `j']
        matrix `T'[`j', 7] = `cpair'[1, `j']
        if `rep'[1, `j'] / `N' < 0.25 {
            local ++nwarn
            local warn`nwarn' = "`g': only " + string(`rep'[1, `j'] / `N' * 100, "%4.1f") + "% of households report a unit value; its price signal rests on few clusters"
        }
        if `n1'[1, `j'] < 2 {
            local ++nwarn
            local warn`nwarn' = "`g': harmonic mean cluster size of reporters below 2; the measurement-error correction is large and imprecise"
        }
    }
    matrix rownames `T' = `goods'
    matrix colnames `T' = "Share_pct" "Reporters" "Rep_pct" "Clusters" "n_plus_harm" "n_harm" "Pairs_min"
    di _n as txt "Table D1: Households reporting a unit value, clusters, and the harmonic cluster sizes of (5.55)"
    matlist `T', border(rows) format(%10.2f) twidth(9) left(2)

    * ---- table 2: the second stage ----
    matrix `T' = J(`M', 6, .)
    forvalues j = 1/`M' {
        local g : word `j' of `goods'
        local sd = sqrt(`S'[`j', `j'])
        local corr = `ome'[1, `j'] / `n1'[1, `j']
        matrix `T'[`j', 1] = `sd'
        matrix `T'[`j', 2] = `corr' / `S'[`j', `j'] * 100
        matrix `T'[`j', 3] = `Sf'[`j', `j']
        matrix `T'[`j', 4] = `b1'[1, `j']
        matrix `T'[`j', 5] = `el'[1, `j']
        matrix `T'[`j', 6] = `zeta'[1, `j'] * `w'[1, `j']
        if `Sf'[`j', `j'] <= 0 {
            local ++nwarn
            local warn`nwarn' = "`g': the corrected between-cluster variance of the unit value is not positive; the price variation is swamped by measurement error"
        }
        else if `corr' / `S'[`j', `j'] > 0.5 {
            local ++nwarn
            local warn`nwarn' = "`g': the measurement-error correction removes " + string(`corr' / `S'[`j', `j'] * 100, "%4.0f") + "% of the between-cluster variance of the unit value"
        }
        if `b1'[1, `j'] < 0 {
            local ++nwarn
            local warn`nwarn' = "`g': negative quality elasticity (" + string(`b1'[1, `j'], "%6.4f") + "); the quality correction (5.92) then raises the price elasticities"
        }
        if abs(`el'[1, `j']) < 0.1 {
            local ++nwarn
            local warn`nwarn' = "`g': expenditure elasticity near zero (" + string(`el'[1, `j'], "%6.3f") + "); zeta = b1/(wbar e) is unstable"
        }
    }
    matrix rownames `T' = `goods'
    matrix colnames `T' = "SD_uv" "Corr_pct" "Sf_jj" "b1" "Exp_elast" "b1_over_e"
    di _n as txt "Table D2: Between-cluster SD of the purged log unit value, the share of it removed by the"
    di as txt "          measurement-error correction, the corrected variance, and the quality parameters"
    matlist `T', border(rows) format(%10.`dec'f) twidth(9) left(2)

    * ---- the moment matrix and the symmetry restriction ----
    mata: st_numscalar("r(cond_Sf)", cond(st_matrix("e(Sf)")))
    mata: st_numscalar("r(mineig_Sf)", min(symeigenvalues(st_matrix("e(Sf)"))))
    mata: st_numscalar("r(sym_dist)", norm(st_matrix("e(B_sym)") - st_matrix("e(B)")) / norm(st_matrix("e(B)")))
    di _n as txt "Corrected moment matrix Sf: condition number = " as res %9.1f r(cond_Sf) as txt ", smallest eigenvalue = " as res %9.5f r(mineig_Sf)
    if "`e(symmetry)'" == "approx" {
        di as txt "Symmetry restriction: relative change of B, ||B_sym - B|| / ||B|| = " as res %6.3f r(sym_dist)
        if r(sym_dist) > 0.5 {
            local ++nwarn
            local warn`nwarn' = "the symmetry restriction moves B by more than 50%; the unrestricted and restricted elasticities tell different stories"
        }
    }
    if r(mineig_Sf) <= 0 {
        local ++nwarn
        local warn`nwarn' = "Sf is not positive definite; the corrected second stage is not a valid regression"
    }
    if r(cond_Sf) > 1e4 {
        local ++nwarn
        local warn`nwarn' = "Sf is ill-conditioned (condition number above 1e4); the price elasticities are fragile"
    }

    di _n as txt "Warnings: " as res `nwarn'
    forvalues i = 1/`nwarn' {
        di as txt "  " as res `i' as txt ". `warn`i''"
    }
    if `nwarn' == 0 di as txt "  none: every good has a usable price signal and a well-behaved correction"
    return scalar N_warn = `nwarn'
    return scalar cond_Sf = r(cond_Sf)
    return scalar mineig_Sf = r(mineig_Sf)
    if "`e(symmetry)'" == "approx" return scalar sym_dist = r(sym_dist)
end

* ---------------------------------------------------------------------------
program define _duvm_estat_elast, rclass
    syntax [, UNRestricted NOQuality UNCompleted DEC(integer 3)]
    local fmt "%`=`dec'+5'.`dec'f"
    if "`noquality'" != "" {
        di as txt _n "Price elasticities of quantity, no quality correction, unrestricted B (M x M)"
        matlist e(elast_price_noqual), border(rows) format(`fmt') twidth(10) left(2)
        if "`e(vce)'" != "none" {
            di as txt _n "Standard errors (`e(vcetype)')"
            matlist e(se_elast_price_noqual), border(rows) format(`fmt') twidth(10) left(2)
            tempname _r_se
            matrix `_r_se' = e(se_elast_price_noqual)
            return matrix se = `_r_se'
        }
        tempname _r_elast
        matrix `_r_elast' = e(elast_price_noqual)
        return matrix elast = `_r_elast'
        exit
    }
    if "`unrestricted'" != "" & "`uncompleted'" != "" {
        di as txt _n "Price elasticities of quantity, quality corrected, unrestricted B (M x M)"
        matlist e(elast_price_M_ns), border(rows) format(`fmt') twidth(10) left(2)
        if "`e(vce)'" != "none" {
            di as txt _n "Standard errors (`e(vcetype)')"
            matlist e(se_elast_price_M_ns), border(rows) format(`fmt') twidth(10) left(2)
            tempname _r_se
            matrix `_r_se' = e(se_elast_price_M_ns)
            return matrix se = `_r_se'
        }
        tempname _r_elast
        matrix `_r_elast' = e(elast_price_M_ns)
        return matrix elast = `_r_elast'
        exit
    }
    if "`unrestricted'" != "" {
        di as txt _n "Price elasticities of quantity, quality corrected, unrestricted B, completed system"
        matlist e(elast_price_ns), border(rows) format(`fmt') twidth(10) left(2)
        if "`e(vce)'" != "none" {
            di as txt _n "Standard errors (`e(vcetype)')"
            matlist e(se_elast_price_ns), border(rows) format(`fmt') twidth(10) left(2)
            tempname _r_se
            matrix `_r_se' = e(se_elast_price_ns)
            return matrix se = `_r_se'
        }
        tempname _r_elast
        matrix `_r_elast' = e(elast_price_ns)
        return matrix elast = `_r_elast'
        exit
    }
    if "`uncompleted'" != "" {
        di as txt _n "Price elasticities of quantity, quality corrected, symmetry restricted (M x M)"
        matlist e(elast_price_M), border(rows) format(`fmt') twidth(10) left(2)
        if "`e(vce)'" != "none" {
            di as txt _n "Standard errors (`e(vcetype)')"
            matlist e(se_elast_price_M), border(rows) format(`fmt') twidth(10) left(2)
            tempname _r_se
            matrix `_r_se' = e(se_elast_price_M)
            return matrix se = `_r_se'
        }
        tempname _r_elast
        matrix `_r_elast' = e(elast_price_M)
        return matrix elast = `_r_elast'
        exit
    }
    di as txt _n "Price elasticities of quantity, quality corrected, symmetry restricted, completed system"
    matlist e(elast_price), border(rows) format(`fmt') twidth(10) left(2)
    if "`e(vce)'" != "none" {
        di as txt _n "Standard errors (`e(vcetype)')"
        matlist e(se_elast_price), border(rows) format(`fmt') twidth(10) left(2)
        tempname _r_se
        matrix `_r_se' = e(se_elast_price)
        return matrix se = `_r_se'
    }
    tempname _r_elast
        matrix `_r_elast' = e(elast_price)
        return matrix elast = `_r_elast'
end

* ---------------------------------------------------------------------------
program define _duvm_estat_quality, rclass
    syntax [, DEC(integer 3)]
    local fmt "%`=`dec'+5'.`dec'f"
    local goods `e(goods)'
    tempname T
    matrix `T' = e(b1) \ e(zeta) \ hadamard(e(zeta), e(shares_mean)) \ e(elast_exp)
    if "`e(vce)'" != "none" {
        matrix `T' = e(b1) \ e(se_elast_qual) \ e(zeta) \ e(se_zeta) \ hadamard(e(zeta), e(shares_mean)) \ e(elast_exp) \ e(se_elast_exp)
        matrix rownames `T' = "b1_quality" "  std_err" "zeta" "  std_err" "zeta_x_wbar" "e_expenditure" "  std_err"
    }
    else matrix rownames `T' = "b1_quality" "zeta" "zeta_x_wbar" "e_expenditure"
    matrix colnames `T' = `goods'
    di as txt _n "Quality: the expenditure elasticity of the unit value (b1), the quality parameter zeta of (5.92),"
    di as txt "and zeta x wbar = b1 / e, the share of a price change absorbed by quality shading"
    matlist `T', border(rows) format(`fmt') twidth(22) left(2)
    di as txt _n "Unit-value response to own price (diagonal of Psi):"
    tempname P
    matrix `P' = vecdiag(e(Psi))
    matrix rownames `P' = "psi_GG"
    matrix colnames `P' = `goods'
    matlist `P', border(rows) format(`fmt') twidth(22) left(2)
    return matrix quality = `T'
end
