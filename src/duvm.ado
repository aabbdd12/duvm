*! duvm 1.0.0  2026-09-23  Abdelkrim Araar
*! Deaton's unit-value model: quality-corrected price and expenditure
*! elasticities from budget shares and unit values, cluster-level prices.
*! Model: Deaton (1988, 1990, 1997 ch. 5). Mata engine, closed-form estimator.
*! License: GPL-3.0-or-later
program define duvm, eclass
    version 14.2
    if replay() {
        if "`e(cmd)'" != "duvm" error 301
        _duvm_display `0'
        exit
    }
    syntax anything(name=namelist id="goods") [if] [in] [aweight fweight pweight iweight] , ///
        HHsize(varname numeric) EXPend(varname numeric) CLuster(varname) ///
        [ REGion(varname) SUBround(varname) INDCAT(varlist) INDCON(varlist numeric) ///
          HWeight(varname numeric) CSB(integer 0) QOTHer(real 0.25) ///
          NOSYMmetry COMPAT COMPATFlags(string) VCE(string) Level(cilevel) ///
          DEC(integer 3) DREGres(integer 0) BOOT(integer 0) HGroup(varname) ///
          QUARD4(passthru) INISave(passthru) XFIL(passthru) GMODifier(passthru) noTABle ]

    * ---- goods and their variables ----
    local goods `namelist'
    local M : word count `goods'
    local wvars ""
    local uvvars ""
    foreach g of local goods {
        confirm numeric variable w`g' luv`g'
        local wvars  `wvars' w`g'
        local uvvars `uvvars' luv`g'
    }

    * ---- compat flags: 1 zeta formula, 2 completion (reciprocal zeta, syminv),
    * 3 sign of the last row of Theta_x, 4 cluster sizes = sum of weights,
    * 5 chi from the auxiliary regression, 6 mwegen denominator, 7 region = first household
    local cf "0 0 0 0 0 0 0"
    if "`compat'" != "" local cf "1 1 1 1 1 1 1"
    else if "`compatflags'" != "" {
        local cf ""
        foreach f in zeta completion sign counts chi mean region {
            local on : list f in compatflags
            local cf "`cf' `on'"
        }
        local compat "compat"
    }

    * ---- variance estimator ----
    if `boot' > 0 & "`vce'" == "" {
        local vce "bootstrap, reps(`boot')"
        if "`compat'" != "" local vce "`vce' shortcut"
    }
    _duvm_vceparse `vce'
    local vtype   "`s(vtype)'"
    local reps    "`s(reps)'"
    local seed    "`s(seed)'"
    local bstrata "`s(strata)'"
    local bpsu    "`s(psu)'"
    local shortcut "`s(shortcut)'"
    local bsvy    "`s(svy)'"
    local fpcvar ""
    if "`bsvy'" != "" | "`vtype'" == "svy" {
        qui svyset
        if "`r(settings)'" == ", clear" | "`r(su1)'" == "" {
            di as err "vce(svy) requires the survey design to be declared with svyset"
            exit 119
        }
        if "`r(su1)'" != "." local bpsu "`r(su1)'"
        if "`r(strata1)'" != "." & "`r(strata1)'" != "" local bstrata "`r(strata1)'"
        if "`r(fpc1)'" != "." & "`r(fpc1)'" != "" local fpcvar "`r(fpc1)'"
        if "`weight'" == "" & "`hweight'" == "" & "`r(wvar)'" != "" {
            local weight "pweight"
            local exp "= `r(wvar)'"
        }
    }
    if "`vtype'" == "cluster" & "`compat'" != "" {
        di as txt "(compat: the analytic variance is not available; use vce(bootstrap) or vce(none))"
        local vtype "none"
    }
    local vnum = cond("`vtype'" == "none", 0, cond("`vtype'" == "cluster", 1, cond("`vtype'" == "svy", 2, 3)))

    * ---- weights: [w=] or hweight() ----
    if "`weight'" != "" & "`hweight'" != "" {
        di as err "specify either [weight=] or hweight(), not both"
        exit 198
    }
    tempvar wt
    if "`weight'" != "" {
        local wexp : subinstr local exp "=" "", all
        qui gen double `wt' = `wexp'
        local wtype "`weight'"
    }
    else if "`hweight'" != "" {
        qui gen double `wt' = `hweight'
        local wtype "aweight"
    }
    else {
        qui gen double `wt' = 1
        local wtype ""
    }

    * ---- regressors of the first stage ----
    tempvar lnexp lhhs
    qui gen double `lnexp' = ln(`expend')
    qui gen double `lhhs'  = ln(`hhsize')
    local X `lnexp' `lhhs' `indcon'
    local Xnames "lnexp lnhhsize `indcon'"
    foreach v of local indcat {
        tempvar cd
        qui tab `v' `if' `in', gen(`cd')
        local nl = r(r)
        qui levelsof `v' `if' `in', local(levs)
        forvalues l = 2/`nl' {
            local X `X' `cd'`l'
            local val : word `l' of `levs'
            local Xnames "`Xnames' `v'==`val'"
        }
    }
    local k : word count `X'

    * ---- estimation sample: shares and regressors non-missing, weight > 0 ----
    marksample touse
    markout `touse' `wvars' `X' `wt' `cluster' `bstrata' `bpsu'
    qui replace `touse' = 0 if `wt' <= 0 | `wt' >= .
    qui count if `touse'
    local N = r(N)
    if `N' == 0 error 2000

    * ---- selection correction: inverse Mills ratio per good ----
    local lamvars ""
    if `csb' == 1 {
        foreach g of local goods {
            tempvar d xb lam`g'
            qui gen byte `d' = (w`g' != 0) if `touse'
            capture qui probit `d' `X' [pw=`wt'] if `touse'
            if _rc {
                qui gen double `lam`g'' = 0 if `touse'
            }
            else {
                qui predict double `xb' if `touse', xb
                qui gen double `lam`g'' = normalden(`xb')/normal(`xb') if `touse'
                if `dregres' == 1 {
                    di as txt _n "Probit for reporting a positive expenditure on `g'"
                    probit, coeflegend
                }
            }
            local lamvars `lamvars' `lam`g''
        }
    }

    * ---- cluster-level design for the purge: region and subround dummies ----
    tempvar reg1 sub1
    if "`region'" != ""   qui gen double `reg1' = `region'
    else                  qui gen double `reg1' = 1
    if "`subround'" != "" qui gen double `sub1' = `subround'
    else                  qui gen double `sub1' = 1
    tempvar st1 ps1 fp1
    if "`bstrata'" != "" qui gen double `st1' = `bstrata'
    else                 qui gen double `st1' = 1
    if "`bpsu'" != ""    qui gen double `ps1' = `bpsu'
    else                 qui gen double `ps1' = `cluster'
    if "`fpcvar'" != ""  qui gen double `fp1' = `fpcvar'
    else                 qui gen double `fp1' = 0

    * ---- first-stage regressions echoed if requested ----
    if `dregres' == 1 {
        di as txt _n "The cluster fixed-effect regressions (unit values)"
        foreach g of local goods {
            areg luv`g' `X' [aw=`wt'] if `touse', absorb(`cluster')
        }
        di as txt _n "The budget-share regressions"
        foreach g of local goods {
            local lg ""
            if `csb' == 1 local lg `lam`g''
            areg w`g' `X' `lg' [aw=`wt'] if `touse', absorb(`cluster')
        }
    }

    * ---- the engine ----
    tempname R
    mata: _duvm_run("`R'", "`wvars'", "`uvvars'", "`X'", "`lamvars'", "`wt'", ///
                    "`cluster'", "`reg1'", "`sub1'", "`st1'", "`ps1'", "`fp1'", "`touse'", ///
                    "`cf'", "`nosymmetry'" == "", `qother', ///
                    `vnum', `reps', `seed', "`shortcut'" != "")

    * ---- own-price elasticities by group (re-estimation on each subsample) ----
    if "`hgroup'" != "" {
        tempname G
        qui levelsof `hgroup' if `touse', local(glevs)
        local ng : word count `glevs'
        local gopts hhsize(`hhsize') expend(`expend') cluster(`cluster') csb(`csb') qother(`qother') `nosymmetry'
        if "`compatflags'" != "" local gopts `gopts' compatflags(`compatflags')
        else if "`compat'" != "" local gopts `gopts' compat
        foreach o in region subround indcat indcon hweight {
            if "``o''" != "" local gopts `gopts' `o'(``o'')
        }
        if "`vtype'" == "bootstrap" {
            local bv "reps(`reps')"
            if `seed' >= 0 local bv "`bv' seed(`seed')"
            if "`bstrata'" != "" local bv "`bv' strata(`bstrata')"
            if "`bpsu'" != "" local bv "`bv' psu(`bpsu')"
            local gopts `gopts' vce(bootstrap, `bv' `shortcut')
        }
        else local gopts `gopts' vce(`vtype')
        local gw ""
        if "`weight'" != "" local gw "[`weight'`exp']"
        local gse = ("`vtype'" != "none")
        local ncol = cond(`gse', 2*`M', `M')
        matrix `G' = J(`ng', `ncol', .)
        local gi 0
        local gnames ""
        local gcols ""
        foreach g of local goods {
            local gcols `gcols' `g'
            if `gse' local gcols `gcols' se_`g'
        }
        foreach gv of local glevs {
            local ++gi
            local gl : label (`hgroup') `gv'
            local gnames `"`gnames' "`gl'""'
            capture {
                preserve
                qui keep if `touse' & `hgroup' == `gv'
                qui duvm `goods' `gw', `gopts' notable
                forvalues j = 1/`M' {
                    if `gse' {
                        matrix `G'[`gi', 2*`j'-1] = el(e(elast_price), `j', `j')
                        matrix `G'[`gi', 2*`j']   = el(e(se_elast_price), `j', `j')
                    }
                    else matrix `G'[`gi', `j'] = el(e(elast_price), `j', `j')
                }
                restore
            }
            if _rc {
                capture restore
                di as txt "  (group `gl': estimation failed, rc=`_rc')"
            }
        }
        matrix rownames `G' = `gnames'
        matrix colnames `G' = `gcols'
    }

    * ---- post ----
    tempname b V
    mata: _duvm_b("`R'", "`goods'", "`b'", "`V'")
    if `duvm_hasV' ereturn post `b' `V', obs(`duvm_N') esample(`touse')
    else           ereturn post `b', obs(`duvm_N') esample(`touse')
    mata: _duvm_post("`R'", "`goods'", "`Xnames'")
    ereturn local cmd "duvm"
    ereturn local cmdline `"duvm `0'"'
    ereturn local estat_cmd "duvm_estat"
    ereturn local goods "`goods'"
    ereturn local depvar "`wvars'"
    ereturn local clustvar "`cluster'"
    ereturn local wtype "`wtype'"
    if "`weight'" != "" ereturn local wexp "`exp'"
    else if "`hweight'" != "" ereturn local wexp "= `hweight'"
    ereturn local region "`region'"
    ereturn local subround "`subround'"
    if "`compat'" != "" ereturn local compat "compat"
    if "`compatflags'" != "" ereturn local compatflags "`compatflags'"
    if "`nosymmetry'" != "" ereturn local symmetry "none"
    else ereturn local symmetry "approx"
    if `csb' == 1 ereturn local csb "imr"
    if "`vtype'" == "bootstrap" {
        ereturn local vce "bootstrap"
        ereturn local vcetype "Bootstrap"
        if "`shortcut'" != "" ereturn local bootstrap "second stage only (Deaton's shortcut)"
        else                  ereturn local bootstrap "both stages"
        ereturn local bstrata "`bstrata'"
        ereturn local bpsu "`bpsu'"
        ereturn scalar N_reps = `reps'
        if `seed' >= 0 ereturn scalar seed = `seed'
    }
    else if "`vtype'" == "cluster" {
        ereturn local vce "cluster"
        ereturn local vcetype "Linearized"
    }
    else if "`vtype'" == "svy" {
        ereturn local vce "svy"
        ereturn local vcetype "Linearized"
        ereturn local bstrata "`bstrata'"
        ereturn local bpsu "`bpsu'"
        ereturn local fpc "`fpcvar'"
    }
    else ereturn local vce "none"
    ereturn scalar qother = `qother'
    ereturn scalar M = `M'
    ereturn scalar k = `k'
    ereturn scalar dec = `dec'
    ereturn scalar level = `level'
    if "`hgroup'" != "" {
        ereturn matrix elast_price_own_group = `G'
        ereturn local hgroup "`hgroup'"
    }
    if "`table'" == "" _duvm_display, dec(`dec')
end

* ============================================================================
program define _duvm_vceparse, sclass
    sreturn clear
    if `"`0'"' == "" {
        sreturn local vtype "cluster"
        sreturn local reps 0
        sreturn local seed -1
        exit
    }
    gettoken vtype 0 : 0, parse(",")
    local vtype = lower(trim("`vtype'"))
    if inlist("`vtype'", "boot", "bootstrap", "bs") local vtype "bootstrap"
    else if inlist("`vtype'", "none") local vtype "none"
    else if inlist("`vtype'", "cluster", "linearized", "robust", "") local vtype "cluster"
    else if inlist("`vtype'", "svy", "survey") local vtype "svy"
    else {
        di as err "vce(`vtype') not allowed; use vce(cluster), vce(svy) or vce(bootstrap [, reps() seed() strata() psu() shortcut svy])"
        exit 198
    }
    gettoken comma 0 : 0, parse(",")
    local 0 ", `0'"
    syntax [, Reps(integer 200) SEED(integer -1) STRata(varname) PSU(varname) SHORTcut SVY]
    if `reps' < 2 {
        di as err "reps() must be at least 2"
        exit 198
    }
    sreturn local vtype "`vtype'"
    sreturn local reps `reps'
    sreturn local seed `seed'
    sreturn local strata "`strata'"
    sreturn local psu "`psu'"
    sreturn local shortcut "`shortcut'"
    sreturn local svy "`svy'"
end

* ============================================================================
program define _duvm_display
    syntax [, DEC(integer 3)]
    if `dec' < 0 local dec = e(dec)
    local M = e(M)
    local cw = `dec' + 5
    local fmt "%`cw'.`dec'f"
    local goods `e(goods)'
    local wtxt = cond("`e(wtype)'" == "", "none", "`e(wtype)' `e(wexp)'")
    local hasV = inlist("`e(vce)'", "bootstrap", "cluster", "svy")
    di as txt _n "Deaton's unit-value model" _col(49) "Number of obs" _col(67) "= " as res %10.0fc e(N)
    di as txt "Goods: " as res "`goods'" as txt _col(49) "Number of clusters" _col(67) "= " as res %10.0fc e(N_clust)
    di as txt "Cluster variable: " as res "`e(clustvar)'" as txt _col(49) "Weights" _col(67) "= " as res "`wtxt'"
    local sy = cond("`e(symmetry)'" == "approx", "imposed (Deaton's approximation)", "not imposed")
    di as txt "Symmetry: " as res "`sy'" as txt _col(49) "Quality elast., other goods = " as res %5.3f e(qother)
    if "`e(compat)'" != "" di as txt "Mode: " as res "compat" as txt " (reproduces the WELCOM duvm formulas)"
    if "`e(csb)'" != ""    di as txt "Selection correction: inverse Mills ratio in the share equations"
    if "`e(vce)'" == "bootstrap" {
        local bs = "bootstrap, `e(bootstrap)', " + strofreal(e(N_reps)) + " replications"
        if "`e(bpsu)'" != "" & "`e(bpsu)'" != "`e(clustvar)'" local bs "`bs', resampling `e(bpsu)'"
        if "`e(bstrata)'" != "" local bs "`bs' within `e(bstrata)'"
        di as txt "Std. err.: " as res "`bs'"
        if e(N_reps_ok) < e(N_reps) di as txt "  (" as res e(N_reps) - e(N_reps_ok) as txt " replications failed and were dropped)"
    }
    else if "`e(vce)'" == "cluster" di as txt "Std. err.: " as res "linearized, clustered by `e(clustvar)'"
    else if "`e(vce)'" == "svy" {
        local bs "linearized, survey design (PSU `e(bpsu)'"
        if "`e(bstrata)'" != "" local bs "`bs', strata `e(bstrata)'"
        if "`e(fpc)'" != "" local bs "`bs', FPC `e(fpc)'"
        di as txt "Std. err.: " as res "`bs')"
    }

    tempname T
    if `hasV' {
        matrix `T' = e(shares_mean) * 100 \ e(elast_exp) \ e(se_elast_exp) \ e(elast_qual) \ e(se_elast_qual)
        matrix rownames `T' = "Budget share (%)" "Expenditure elast." "  std. err." "Quality elast." "  std. err."
    }
    else {
        matrix `T' = e(shares_mean) * 100 \ e(elast_exp) \ e(elast_qual)
        matrix rownames `T' = "Budget share (%)" "Expenditure elast." "Quality elast."
    }
    matrix colnames `T' = `goods'
    matlist `T', border(rows) format(`fmt') twidth(20) left(2) title("Table 1: Average budget shares, expenditure and quality elasticities")

    di _n as txt "Table 2: Price elasticities of quantity, no quality correction (E = D(w)^-1 B' - I)"
    matlist e(elast_price_noqual), border(rows) format(`fmt') twidth(10) left(2)
    di _n as txt "Table 3: Price elasticities of quantity, quality corrected, unrestricted B"
    matlist e(elast_price_ns), border(rows) format(`fmt') twidth(10) left(2)
    if "`e(symmetry)'" == "approx" {
        di _n as txt "Table 4: Price elasticities of quantity, quality corrected, symmetry restricted (completed system)"
        matlist e(elast_price), border(rows) format(`fmt') twidth(10) left(2)
    }
    if `hasV' {
        di _n as txt "Table 5: Standard errors of the price elasticities of Table " cond("`e(symmetry)'" == "approx", "4", "3")
        matlist e(se_elast_price), border(rows) format(`fmt') twidth(10) left(2)
    }
    if "`e(hgroup)'" != "" {
        di _n as txt "Table 6: Own-price elasticities by `e(hgroup)' (model re-estimated within each group)"
        matlist e(elast_price_own_group), border(rows) format(`fmt') twidth(14) left(2)
    }
    di as txt _n "Rows: quantity of the good; columns: price of the good. The last row/column is the composite of all other goods."
end

* ============================================================================
version 14.2
mata:
mata set matastrict on

struct duvm_d {                         // the data
    real matrix    W, UV, X, LAM
    real colvector w, cid, reg, sub, strat, psu, fpc
    real scalar    hasl, N, C
}

struct duvm_c {                         // first stage + cluster-level series
    real scalar    N, C, M, k
    real matrix    beta0, beta1
    real colvector wbar, b0, b1, ome, sig, chi
    real matrix    y0c, y1c, n0c, n1c, D
    // kept for the influence functions (data sorted by cluster)
    real matrix    Xs, Ws, info, MU, M0, E0, E1, XX0, XX1, xb0c, xb1c
    real colvector ws, cl, psu_c, strat_c, fpc_c
    real colvector norm0, norm1, norm01, df0, df1, df01, N0, N1, N01
}

struct duvm_r {                         // second stage and elasticities
    real scalar    N, C, M, k, sym, qother
    real rowvector cf                       // compat flags (7), all zero = the book
    real matrix    beta0, beta1
    real colvector wbar, b0, b1, ome, sig, chi, n0, n1, zeta, el
    real matrix    S, R, Sf, Rf, Bols, B, Bsym
    real matrix    Enq, Ens, Esy
    real matrix    Exns, Exsy
    real colvector ex, zx, wx
    real matrix    Psi, Theta, Psix, Thx
    real matrix    y0t, y1t                 // purged cluster-level series
    real colvector Nrep, Crep, Cpair        // reporters, clusters with reporters, min clusters per pair
    // variance
    real scalar    boot, reps, reps_ok, shortcut, seed, hasV, P
    real matrix    V, bootb, G, Veta
}

// ---------------------------------------------------------------- data
struct duvm_d scalar _duvm_load(string scalar wvars, string scalar uvvars, string scalar Xvars,
                                string scalar lamvars, string scalar wtvar, string scalar clvar,
                                string scalar regvar, string scalar subvar, string scalar stvar,
                                string scalar psvar, string scalar fpcvar, string scalar touse)
{
    struct duvm_d scalar d
    real colvector raw
    d.W   = st_data(., tokens(wvars), touse)
    d.UV  = st_data(., tokens(uvvars), touse)
    d.X   = st_data(., tokens(Xvars), touse)
    d.hasl = (lamvars != "")
    if (d.hasl) d.LAM = st_data(., tokens(lamvars), touse)
    else        d.LAM = J(rows(d.W), 0, .)
    d.w   = st_data(., wtvar, touse)
    d.reg = st_data(., regvar, touse)
    d.sub = st_data(., subvar, touse)
    d.N   = rows(d.W)
    raw   = st_data(., clvar, touse)
    d.cid = _duvm_dense(raw)
    d.C   = max(d.cid)
    d.strat = _duvm_dense(st_data(., stvar, touse))
    d.psu   = _duvm_dense(st_data(., psvar, touse))
    if (fpcvar != "") d.fpc = st_data(., fpcvar, touse)
    else              d.fpc = J(d.N, 1, 0)
    return(d)
}

// dense 1..K codes of a categorical vector (original row order kept)
real colvector _duvm_dense(real colvector v)
{
    real colvector ord, s, code
    real scalar n
    n = rows(v)
    if (n == 0) return(v)
    ord = order(v, 1)
    s = v[ord]
    code = J(n, 1, .)
    code[ord] = runningsum(1 \ (s[|2 \ n|] :!= s[|1 \ n-1|]))
    return(code)
}

// ---------------------------------------------------------------- stage 1
// weighted within-cluster regression of Y (N x q) on X (N x k) on the rows
// with m==1; clusters contiguous, info = panelsetup, cl = cluster index.
real matrix _duvm_fe(real matrix Y, real matrix X, real colvector w, real colvector m,
                     real matrix info, real colvector cl,
                     real matrix e, real matrix yp, real scalar df, real scalar Cused,
                     real scalar norm, real matrix XXi)
{
    real colvector wm, sw
    real matrix Z, Zs, mu, Zd, b, Yc
    real scalar k, q

    k = cols(X); q = cols(Y)
    Yc = editmissing(Y, 0) :* m
    wm = w :* m
    sw = panelsum(wm, info)
    Z  = (Yc, X)
    Zs = panelsum(Z :* wm, info)
    mu = Zs :/ (sw :+ (sw :== 0))
    Zd = (Z - mu[cl, .]) :* m
    XXi = invsym(quadcross(Zd[., q+1..q+k], wm, Zd[., q+1..q+k]))
    b  = XXi * quadcross(Zd[., q+1..q+k], wm, Zd[., 1..q])
    e  = (Zd[., 1..q] - Zd[., q+1..q+k] * b) :* m
    yp = (Yc - X * b) :* m
    Cused = sum(sw :> 0)
    df = sum(m) - k - Cused
    norm = sum(m) / sum(wm)
    return(b)
}

struct duvm_c scalar _duvm_stage1(struct duvm_d scalar d, real rowvector cf)
{
    struct duvm_c scalar c
    real matrix W, UV, X, LAM, info, e0, e1, e2, yp0, yp1, b, Zd, XXi
    real colvector w, cid, cl, ord, mS, mU, m0, m01, sw, sw0, swsq, sw2, ee, y2, cnt, cnt0, nc
    real scalar M, k, N, C, j, df, Cu, norm, i

    // sort by cluster, stable, so that clusters are contiguous
    ord = order((d.cid, (1::rows(d.cid))), (1, 2))
    W = d.W[ord, .]; UV = d.UV[ord, .]; X = d.X[ord, .]; w = d.w[ord]; cid = d.cid[ord]
    if (d.hasl) LAM = d.LAM[ord, .]
    N = rows(W); k = cols(X); M = cols(W)
    info = panelsetup(cid, 1)
    C = rows(info)
    cl = J(N, 1, .)
    for (i = 1; i <= C; i++) cl[|info[i,1] \ info[i,2]|] = J(info[i,2]-info[i,1]+1, 1, i)

    c.N = N; c.C = C; c.M = M; c.k = k
    c.beta0 = J(k, M, .); c.beta1 = J(k, M, .)
    c.b0 = J(M, 1, .); c.b1 = J(M, 1, .); c.ome = J(M, 1, .); c.sig = J(M, 1, .); c.chi = J(M, 1, .)
    c.wbar = (quadcross(w, W) / sum(w))'
    // kept for the influence functions
    c.Xs = X; c.Ws = W; c.ws = w; c.info = info; c.cl = cl
    c.MU = J(N, M, .); c.M0 = J(N, M, .); c.E0 = J(N, M, .); c.E1 = J(N, M, .)
    c.XX0 = J(k, k*M, .); c.XX1 = J(k, k*M, .); c.xb0c = J(C, k*M, .); c.xb1c = J(C, k*M, .)
    c.norm0 = J(M, 1, .); c.norm1 = J(M, 1, .); c.norm01 = J(M, 1, .)
    c.df0 = J(M, 1, .); c.df1 = J(M, 1, .); c.df01 = J(M, 1, .)
    c.N0 = J(M, 1, .); c.N1 = J(M, 1, .); c.N01 = J(M, 1, .)
    c.psu_c = d.psu[ord][info[., 1]]; c.strat_c = d.strat[ord][info[., 1]]; c.fpc_c = d.fpc[ord][info[., 1]]

    yp0 = J(N, M, .); yp1 = J(N, M, .)
    c.n0c = J(C, M, .); c.n1c = J(C, M, .)
    c.y0c = J(C, M, .); c.y1c = J(C, M, .)
    mS = J(N, 1, 1)
    sw = panelsum(w, info)
    nc = info[., 2] - info[., 1] :+ 1
    for (j = 1; j <= M; j++) {
        // unit value equation on the reporters
        mU = (UV[., j] :< .)
        b = _duvm_fe(UV[., j], X, w, mU, info, cl, e1, ee, df, Cu, norm, XXi)
        c.beta1[., j] = b
        c.b1[j] = b[1]
        c.ome[j] = norm * quadcross(e1, w :* mU, e1) / df
        yp1[., j] = ee
        c.MU[., j] = mU; c.E1[., j] = e1; c.XX1[., (j-1)*k+1..j*k] = XXi
        c.norm1[j] = norm; c.df1[j] = df; c.N1[j] = sum(mU)
        sw2 = panelsum(w :* mU, info)
        c.xb1c[., (j-1)*k+1..j*k] = panelsum(X :* (w :* mU), info) :/ (sw2 :+ (sw2 :== 0))
        // budget share equation (+ inverse Mills ratio if requested)
        if (d.hasl) {
            m0 = mS :* (LAM[., j] :< .)
            b = _duvm_fe(W[., j], (X, editmissing(LAM[., j], 0)), w, m0, info, cl, e0, ee, df, Cu, norm, XXi)
            XXi = XXi[1..k, 1..k]
        }
        else {
            m0 = mS
            b = _duvm_fe(W[., j], X, w, m0, info, cl, e0, ee, df, Cu, norm, XXi)
        }
        c.beta0[., j] = b[1..k]
        c.b0[j] = b[1]
        c.sig[j] = norm * quadcross(e0, w :* m0, e0) / df
        yp0[., j] = ee
        c.M0[., j] = m0; c.E0[., j] = e0; c.XX0[., (j-1)*k+1..j*k] = XXi
        c.norm0[j] = norm; c.df0[j] = df; c.N0[j] = sum(m0)
        sw0 = panelsum(w :* m0, info)
        c.xb0c[., (j-1)*k+1..j*k] = panelsum(X :* (w :* m0), info) :/ (sw0 :+ (sw0 :== 0))
        // covariance of the two residuals on the households in both equations
        m01 = mU :* m0
        if (cf[5]) {
            Zd = (e0, X)
            b = _duvm_fe(e1, Zd, w, m01, info, cl, e2, y2, df, Cu, norm, XXi)
            c.chi[j] = b[1] * c.sig[j]
            c.norm01[j] = norm; c.df01[j] = df; c.N01[j] = sum(m01)
        }
        else {
            df = sum(m01) - k - sum(panelsum(w :* m01, info) :> 0)
            c.chi[j] = (sum(m01) / sum(w :* m01)) * quadcross(e1, w :* m01, e0) / df
            c.norm01[j] = sum(m01) / sum(w :* m01); c.df01[j] = df; c.N01[j] = sum(m01)
        }
        // cluster averages of the purged series and cluster sizes
        cnt  = panelsum(mU, info)
        cnt0 = panelsum(m0, info)
        sw0 = panelsum(w :* m0, info)
        sw2 = panelsum(w :* mU, info)
        if (cf[6]) {
            // WELCOM mwegen: numerator averaged over the observed, denominator over all
            c.y0c[., j] = (panelsum(yp0[., j] :* w, info) :/ (cnt0 :+ (cnt0 :== 0))) :/ (sw :/ nc)
            c.y1c[., j] = (panelsum(yp1[., j] :* w, info) :/ (cnt :+ (cnt :== 0))) :/ (sw :/ nc)
        }
        else {
            c.y0c[., j] = panelsum(yp0[., j] :* w, info) :/ (sw0 :+ (sw0 :== 0))
            c.y1c[., j] = panelsum(yp1[., j] :* w, info) :/ (sw2 :+ (sw2 :== 0))
        }
        if (cf[4]) {
            // WELCOM: the size of a cluster is the sum of its weights
            c.n0c[., j] = sw0
            c.n1c[., j] = sw2
        }
        else {
            // Kish effective sizes (5.55): (sum w)^2 / sum w^2
            swsq = panelsum((w:^2) :* m0, info)
            c.n0c[., j] = sw0:^2 :/ (swsq :+ (swsq :== 0))
            swsq = panelsum((w:^2) :* mU, info)
            c.n1c[., j] = sw2:^2 :/ (swsq :+ (swsq :== 0))
        }
        if (any(cnt0 :== 0)) c.y0c[selectindex(cnt0 :== 0), j] = J(sum(cnt0 :== 0), 1, .)
        if (any(cnt :== 0))  c.y1c[selectindex(cnt :== 0), j]  = J(sum(cnt :== 0), 1, .)
    }
    // cluster-level design of the purge: constant, region and subround dummies
    c.D = (J(C, 1, 1), _duvm_dummies(_duvm_clval(d.reg[ord], info, cf[7])),
                       _duvm_dummies(_duvm_clval(d.sub[ord], info, cf[7])))
    return(c)
}

// value of a household-level variable at the cluster level: the first
// non-missing value in the cluster (compat: the first household, as WELCOM)
real colvector _duvm_clval(real colvector v, real matrix info, real scalar compat)
{
    real colvector out, x
    real scalar i
    out = v[info[., 1]]
    if (compat) return(out)
    for (i = 1; i <= rows(info); i++) {
        if (out[i] < .) continue
        x = select(v[|info[i, 1] \ info[i, 2]|], v[|info[i, 1] \ info[i, 2]|] :< .)
        if (rows(x)) out[i] = x[1]
    }
    return(out)
}

// pairwise covariance across clusters, divisor n-1, missing-aware
real scalar _duvm_cov(real colvector a, real colvector b)
{
    real colvector ok, x, y
    real scalar n
    ok = (a :< .) :& (b :< .)
    n = sum(ok)
    if (n < 2) return(.)
    x = select(a, ok); y = select(b, ok)
    return(quadcross(x :- mean(x), y :- mean(y)) / (n - 1))
}

real colvector _duvm_purge(real colvector y, real matrix D)
{
    real colvector ok, r, ys
    real matrix Ds
    ok = (y :< .) :& (rowsum(D :>= .) :== 0)
    if (sum(ok) < 2) return(y)
    Ds = select(D, ok); ys = select(y, ok)
    r = J(rows(y), 1, .)
    r[selectindex(ok)] = ys - Ds * (invsym(quadcross(Ds, Ds)) * quadcross(Ds, ys))
    return(r)
}

real matrix _duvm_dummies(real colvector v)
{
    real colvector u
    real scalar j
    real matrix D
    u = uniqrows(select(v, v :< .))
    if (rows(u) <= 1) return(J(rows(v), 0, .))
    D = J(rows(v), rows(u), 0)
    for (j = 1; j <= rows(u); j++) D[., j] = (v :== u[j])
    if (any(v :>= .)) D[selectindex(v :>= .), .] = J(sum(v :>= .), rows(u), .)
    return(D)
}

// ---------------------------------------------------------------- elasticities
void _duvm_elast(real matrix B, real colvector b0, real colvector b1, real colvector wbar,
                 real rowvector cf, real matrix Psi, real matrix Theta, real matrix E,
                 real colvector zeta)
{
    real scalar M
    M = rows(B)
    if (cf[1])  zeta = b1 :/ (b0 :+ (1 :- b1 :* wbar))          // the posted code
    else        zeta = b1 :/ (b0 :+ wbar :* (1 :- b1))          // Deaton (1997, 5.92)
    Psi   = luinv(I(M) - diag(zeta) * B' + diag(zeta) * diag(wbar))
    Theta = B' * Psi
    E     = (diag(1 :/ wbar) * B' - I(M)) * Psi
}

void _duvm_complete(real matrix Theta, real colvector b0, real colvector b1, real colvector wbar,
                    real scalar qother, real rowvector cf,
                    real matrix Thx, real matrix Psix, real matrix Ex, real colvector ex,
                    real colvector zx, real colvector wx)
{
    real scalar M
    real colvector b0x, b1x
    real matrix Bx
    M = rows(Theta)
    Thx = (Theta, -rowsum(Theta) - b0)                        // (5.93)
    if (cf[3])  Thx = Thx \ colsum(Thx)                         // the posted code (sign error)
    else        Thx = Thx \ -colsum(Thx)                        // (5.94): columns add to zero
    wx  = wbar \ (1 - sum(wbar))
    b1x = b1 \ qother
    b0x = b0 \ -sum(b0)
    ex  = 1 :- b1x + b0x :/ wx
    if (cf[2]) {
        // the posted code: the reciprocal of zeta through syminv(diag(b1)), which
        // zeroes the rows whose pivot is not positive
        zx = (wx :* (1 :- b1x) + b0x) :/ b1x
        zx = zx :* (b1x :> 0)
    }
    else zx = b1x :/ (wx :* (1 :- b1x) + b0x)                  // (5.92) on the extended vectors
    Psix = luinv(I(M+1) + diag(zx) * diag(wx)) * (I(M+1) + diag(zx) * Thx)
    Bx   = Thx * luinv(Psix)
    Ex   = (diag(1 :/ wx) * Bx - I(M+1)) * Psix
}

// restriction matrix R of (5.100)-(5.101): R vec(B) = r
real matrix _duvm_Rm(real scalar M)
{
    real scalar i, j, r, M2
    real matrix K, L
    M2 = M * M
    K = J(M2, M2, 0)
    for (i = 1; i <= M; i++) for (j = 1; j <= M; j++) K[(i-1)*M + j, (j-1)*M + i] = 1
    L = J(M*(M-1)/2, M2, 0)
    r = 0
    for (j = 1; j < M; j++) {
        for (i = j+1; i <= M; i++) {
            r = r + 1
            L[r, (j-1)*M + i] = 1
        }
    }
    return(L * (I(M2) - K))
}

real matrix _duvm_symmetry(real matrix B, real matrix A, real colvector b0, real colvector wbar)
{
    real scalar M
    real matrix Rm, iss, inn
    real colvector vb, rh
    M = rows(B)
    Rm = _duvm_Rm(M)
    rh = -Rm * (b0 # wbar)
    vb = vec(B)
    iss = (I(M) # invsym(A)) * Rm'
    inn = iss * invsym(Rm * iss)
    return(rowshape(vb + inn * (rh - Rm * vb), M)')
}

// ---------------------------------------------------------------- analytic variance
// Forward differential of the chain (S, R, ome, chi, b0, b1, wbar) -> theta,
// theta = (vec by row of E_x, e_x, b1). Exact derivatives, no finite difference.
real rowvector _duvm_dtheta(struct duvm_r scalar r, real matrix dS, real matrix dR,
                            real colvector dome, real colvector dchi, real colvector db0,
                            real colvector db1, real colvector dw)
{
    real scalar M
    real matrix Sf, Sfi, B, dSf, dRf, dB, Rm, Kr, Q, Qi, P, dAi, dKr, dQ, dP
    real matrix Q2, Psi, dQ2, dPsi, Theta, dTheta, Thx, dThx, A1, A2, A1i, Psix, dA1, dA2, dPsix
    real matrix Psixi, Bx, dBx, Dwi, dEx
    real colvector b0, b1, w, g, dg, z, dz, vb, dvb, rh, drh, dvbR
    real colvector wx, dwx, b1x, db1x, b0x, db0x, ex, dex, gx, dgx, zx, dzx

    M = r.M
    b0 = r.b0; b1 = r.b1; w = r.wbar
    Sf = r.Sf; Sfi = invsym(Sf); B = r.B
    // S is a covariance matrix: a perturbation is read symmetrically (as invsym does)
    dSf = (dS + dS') / 2 - diag(dome :/ r.n1)
    dRf = dR - diag(dchi :/ r.n0)
    dB  = Sfi * (dRf - dSf * B)
    if (r.sym) {
        Rm = _duvm_Rm(M)
        Kr = I(M) # Sfi
        Q  = Rm * Kr * Rm'; Qi = invsym(Q)
        P  = Kr * Rm' * Qi
        rh = -Rm * (b0 # w)
        vb = vec(B)
        dAi = -Sfi * dSf * Sfi
        dKr = I(M) # dAi
        dQ  = Rm * dKr * Rm'
        dP  = dKr * Rm' * Qi - P * dQ * Qi
        drh = -Rm * (db0 # w + b0 # dw)
        dvb = vec(dB)
        dvbR = dvb + dP * (rh - Rm * vb) + P * (drh - Rm * dvb)
        B  = r.Bsym
        dB = rowshape(dvbR, M)'
    }
    // zeta (5.92)
    g  = b0 + w :* (1 :- b1)
    dg = db0 + dw :* (1 :- b1) - w :* db1
    z  = b1 :/ g
    dz = db1 :/ g - b1 :* dg :/ (g:^2)
    // Psi, Theta (5.90)
    Q2  = I(M) - diag(z) * B' + diag(z) * diag(w)
    Psi = luinv(Q2)
    dQ2 = -diag(dz) * B' - diag(z) * dB' + diag(dz) * diag(w) + diag(z) * diag(dw)
    dPsi = -Psi * dQ2 * Psi
    Theta  = B' * Psi
    dTheta = dB' * Psi + B' * dPsi
    // completion (5.93)-(5.97)
    Thx  = (Theta, -rowsum(Theta) - b0)
    Thx  = Thx \ -colsum(Thx)
    dThx = (dTheta, -rowsum(dTheta) - db0)
    dThx = dThx \ -colsum(dThx)
    wx  = w \ (1 - sum(w));       dwx  = dw \ -sum(dw)
    b1x = b1 \ r.qother;          db1x = db1 \ 0
    b0x = b0 \ -sum(b0);          db0x = db0 \ -sum(db0)
    ex  = 1 :- b1x + b0x :/ wx
    dex = -db1x + db0x :/ wx - b0x :* dwx :/ (wx:^2)
    gx  = b0x + wx :* (1 :- b1x)
    dgx = db0x + dwx :* (1 :- b1x) - wx :* db1x
    zx  = b1x :/ gx
    dzx = db1x :/ gx - b1x :* dgx :/ (gx:^2)
    A1 = I(M+1) + diag(zx) * diag(wx)
    A2 = I(M+1) + diag(zx) * Thx
    A1i = luinv(A1)
    Psix = A1i * A2
    dA1 = diag(dzx) * diag(wx) + diag(zx) * diag(dwx)
    dA2 = diag(dzx) * Thx + diag(zx) * dThx
    dPsix = A1i * (dA2 - dA1 * Psix)
    Psixi = luinv(Psix)
    Bx  = Thx * Psixi
    dBx = (dThx - Bx * dPsix) * Psixi
    Dwi = diag(1 :/ wx)
    dEx = (-Dwi * Dwi * diag(dwx) * Bx + Dwi * dBx) * Psix + (Dwi * Bx - I(M+1)) * dPsix
    return((vec(dEx')', dex', db1'))
}

// Jacobian of theta with respect to eta = (vec S, vec R, ome, chi, b0, b1, wbar)
real matrix _duvm_jac(struct duvm_r scalar r)
{
    real scalar M, q, i, j, s, K
    real matrix G, Z, U
    real colvector z, u
    M = r.M
    q = 2*M*M + 5*M
    K = (M+1)^2 + (M+1) + M
    G = J(K, q, .)
    Z = J(M, M, 0); z = J(M, 1, 0)
    for (j = 1; j <= M; j++) for (i = 1; i <= M; i++) {
        s = (j-1)*M + i
        U = Z; U[i, j] = 1
        G[., s]       = _duvm_dtheta(r, U, Z, z, z, z, z, z)'
        G[., M*M + s] = _duvm_dtheta(r, Z, U, z, z, z, z, z)'
    }
    for (j = 1; j <= M; j++) {
        u = z; u[j] = 1
        G[., 2*M*M + j]       = _duvm_dtheta(r, Z, Z, u, z, z, z, z)'
        G[., 2*M*M + M + j]   = _duvm_dtheta(r, Z, Z, z, u, z, z, z)'
        G[., 2*M*M + 2*M + j] = _duvm_dtheta(r, Z, Z, z, z, u, z, z)'
        G[., 2*M*M + 3*M + j] = _duvm_dtheta(r, Z, Z, z, z, z, u, z)'
        G[., 2*M*M + 4*M + j] = _duvm_dtheta(r, Z, Z, z, z, z, z, u)'
    }
    return(G)
}

// theta recomputed from a perturbed eta (used only to check the Jacobian)
real rowvector _duvm_theta_of(struct duvm_r scalar r0, real matrix S, real matrix R,
                              real colvector ome, real colvector chi, real colvector b0,
                              real colvector b1, real colvector wbar)
{
    struct duvm_r scalar r
    r = r0
    r.S = S; r.R = R; r.ome = ome; r.chi = chi; r.b0 = b0; r.b1 = b1; r.wbar = wbar
    _duvm_chain(r)
    return(_duvm_bvec(r))
}

// influence functions of eta, summed within price clusters: C x q
real matrix _duvm_if(struct duvm_c scalar c, struct duvm_r scalar r)
{
    real scalar M, k, C, N, q, i, j, s, n, mi, mj, jj
    real matrix Phi, IF, Cb0, Cb1, xt0, xt1, Xd, mu
    real colvector w, ok, yi, yj, Ji, Jj, m, sw, wm

    M = c.M; k = c.k; C = c.C; N = c.N
    q = 2*M*M + 5*M
    Phi = J(C, q, 0)
    w = c.ws

    // household-level influence functions, summed by cluster
    Cb0 = J(C, k*M, .); Cb1 = J(C, k*M, .)
    for (j = 1; j <= M; j++) {
        // beta1_j: (X~'WX~)^-1 x~_h w_h e1_h on the reporters
        m = c.MU[., j]; wm = w :* m
        sw = panelsum(wm, c.info)
        mu = panelsum(c.Xs :* wm, c.info) :/ (sw :+ (sw :== 0))
        Xd = (c.Xs - mu[c.cl, .]) :* m
        IF = (Xd :* (wm :* c.E1[., j])) * c.XX1[., (j-1)*k+1..j*k]
        Cb1[., (j-1)*k+1..j*k] = panelsum(IF, c.info)
        // beta0_j on the share sample
        m = c.M0[., j]; wm = w :* m
        sw = panelsum(wm, c.info)
        mu = panelsum(c.Xs :* wm, c.info) :/ (sw :+ (sw :== 0))
        Xd = (c.Xs - mu[c.cl, .]) :* m
        IF = (Xd :* (wm :* c.E0[., j])) * c.XX0[., (j-1)*k+1..j*k]
        Cb0[., (j-1)*k+1..j*k] = panelsum(IF, c.info)
        // omega_j, chi_j, wbar_j, b0_j, b1_j
        m = c.MU[., j]
        Phi[., 2*M*M + j] = panelsum(c.norm1[j] :* w :* (c.E1[., j]:^2) :* m :/ c.df1[j] - (r.ome[j] / c.N1[j]) :* m, c.info)
        m = c.MU[., j] :* c.M0[., j]
        Phi[., 2*M*M + M + j] = panelsum(c.norm01[j] :* w :* c.E0[., j] :* c.E1[., j] :* m :/ c.df01[j] - (r.chi[j] / c.N01[j]) :* m, c.info)
        Phi[., 2*M*M + 4*M + j] = panelsum(w :* (c.Ws[., j] :- r.wbar[j]), c.info) / sum(w)
        Phi[., 2*M*M + 2*M + j] = Cb0[., (j-1)*k+1]
        Phi[., 2*M*M + 3*M + j] = Cb1[., (j-1)*k+1]
    }

    // cluster-level means of x, purged like the y's (generated-regressor terms)
    xt0 = c.xb0c; xt1 = c.xb1c
    for (j = 1; j <= M; j++) {
        for (jj = 1; jj <= k; jj++) {
            xt0[., (j-1)*k+jj] = _duvm_purge(_duvm_setmiss(c.xb0c[., (j-1)*k+jj], r.y0t[., j] :< .), c.D)
            xt1[., (j-1)*k+jj] = _duvm_purge(_duvm_setmiss(c.xb1c[., (j-1)*k+jj], r.y1t[., j] :< .), c.D)
        }
    }
    xt0 = editmissing(xt0, 0); xt1 = editmissing(xt1, 0)

    // second-stage moments: own term + generated-regressor terms
    for (i = 1; i <= M; i++) for (j = 1; j <= M; j++) {
        s = (j-1)*M + i
        // S_ij = cov(y1_i, y1_j)
        ok = (r.y1t[., i] :< .) :& (r.y1t[., j] :< .)
        n = sum(ok)
        yi = editmissing(r.y1t[., i], 0) :* ok; yj = editmissing(r.y1t[., j], 0) :* ok
        mi = sum(yi) / n; mj = sum(yj) / n
        yi = (yi :- mi) :* ok; yj = (yj :- mj) :* ok
        Phi[., s] = Phi[., s] + (yi :* yj - r.S[i, j] :* ok) / (n - 1)
        Ji = -quadcross(xt1[., (i-1)*k+1..i*k] :* ok, yj) / (n - 1)
        Jj = -quadcross(xt1[., (j-1)*k+1..j*k] :* ok, yi) / (n - 1)
        Phi[., s] = Phi[., s] + Cb1[., (i-1)*k+1..i*k] * Ji + Cb1[., (j-1)*k+1..j*k] * Jj
        // R_ij = cov(y1_i, y0_j)
        ok = (r.y1t[., i] :< .) :& (r.y0t[., j] :< .)
        n = sum(ok)
        yi = editmissing(r.y1t[., i], 0) :* ok; yj = editmissing(r.y0t[., j], 0) :* ok
        mi = sum(yi) / n; mj = sum(yj) / n
        yi = (yi :- mi) :* ok; yj = (yj :- mj) :* ok
        Phi[., M*M + s] = Phi[., M*M + s] + (yi :* yj - r.R[i, j] :* ok) / (n - 1)
        Ji = -quadcross(xt1[., (i-1)*k+1..i*k] :* ok, yj) / (n - 1)
        Jj = -quadcross(xt0[., (j-1)*k+1..j*k] :* ok, yi) / (n - 1)
        Phi[., M*M + s] = Phi[., M*M + s] + Cb1[., (i-1)*k+1..i*k] * Ji + Cb0[., (j-1)*k+1..j*k] * Jj
    }
    return(Phi)
}

real colvector _duvm_setmiss(real colvector v, real colvector ok)
{
    real colvector out
    out = v
    if (any(!ok)) out[selectindex(!ok)] = J(sum(!ok), 1, .)
    return(out)
}

// design aggregation: rows of Phi are price clusters; each belongs to a PSU
// and a stratum; fpc = population count of PSUs (>= 1) or sampling rate (< 1)
real matrix _duvm_vagg(real matrix Phi, real colvector psu, real colvector strat,
                       real colvector fpc, real scalar P)
{
    real matrix Php, V, D
    real colvector ord, ps, st, fp, u, sel
    real scalar h, nh, f, q
    ord = order(psu, 1)
    Php = panelsum(Phi[ord, .], panelsetup(psu[ord], 1))
    ps  = psu[ord][panelsetup(psu[ord], 1)[., 1]]
    st  = strat[ord][panelsetup(psu[ord], 1)[., 1]]
    fp  = fpc[ord][panelsetup(psu[ord], 1)[., 1]]
    P = rows(Php)
    q = cols(Phi)
    V = J(q, q, 0)
    u = uniqrows(st)
    for (h = 1; h <= rows(u); h++) {
        sel = selectindex(st :== u[h])
        nh = rows(sel)
        if (nh < 2) continue
        f = fp[sel[1]]
        if (f >= .) f = 0
        else if (f >= 1) f = nh / f
        D = Php[sel, .] :- mean(Php[sel, .])
        V = V + (1 - f) * nh / (nh - 1) * quadcross(D, D)
    }
    return(V)
}

void _duvm_analytic(struct duvm_c scalar c, struct duvm_r scalar r, real scalar svy)
{
    real matrix Phi
    real scalar P
    Phi = _duvm_if(c, r)
    r.G = _duvm_jac(r)
    if (svy) r.Veta = _duvm_vagg(Phi, c.psu_c, c.strat_c, c.fpc_c, P)
    else     r.Veta = _duvm_vagg(Phi, (1::c.C), J(c.C, 1, 1), J(c.C, 1, 0), P)
    r.P = P
    r.V = r.G * r.Veta * r.G'
    r.V = (r.V + r.V') / 2
    r.hasV = 1
}

// ---------------------------------------------------------------- stage 2
// sel: the clusters used (rows of the cluster-level arrays, repetition allowed)
struct duvm_r scalar _duvm_stage2(struct duvm_c scalar c, real colvector sel,
                                  real rowvector cf, real scalar sym, real scalar qother)
{
    struct duvm_r scalar r
    real matrix y0c, y1c, n0c, n1c, D
    real colvector ok
    real scalar M, i, j

    M = c.M
    r.N = c.N; r.C = rows(sel); r.M = M; r.k = c.k; r.cf = cf; r.sym = sym; r.qother = qother
    r.beta0 = c.beta0; r.beta1 = c.beta1
    r.wbar = c.wbar; r.b0 = c.b0; r.b1 = c.b1; r.ome = c.ome; r.sig = c.sig; r.chi = c.chi
    y0c = c.y0c[sel, .]; y1c = c.y1c[sel, .]; n0c = c.n0c[sel, .]; n1c = c.n1c[sel, .]; D = c.D[sel, .]

    // harmonic means of the cluster sizes (5.55)
    r.n0 = J(M, 1, .); r.n1 = J(M, 1, .)
    for (j = 1; j <= M; j++) {
        ok = n0c[., j] :> 0
        r.n0[j] = 1 / mean(1 :/ select(n0c[., j], ok))
        ok = n1c[., j] :> 0
        r.n1[j] = 1 / mean(1 :/ select(n1c[., j], ok))
    }
    // purge region and subround effects
    for (j = 1; j <= M; j++) {
        y0c[., j] = _duvm_purge(y0c[., j], D)
        y1c[., j] = _duvm_purge(y1c[., j], D)
    }
    // between-cluster moments, pairwise
    r.S = J(M, M, .); r.R = J(M, M, .)
    for (i = 1; i <= M; i++) for (j = 1; j <= M; j++) {
        r.S[i, j] = _duvm_cov(y1c[., i], y1c[., j])
        r.R[i, j] = _duvm_cov(y1c[., i], y0c[., j])
    }
    r.y0t = y0c; r.y1t = y1c
    r.Bols = invsym(r.S) * r.R
    _duvm_chain(r)
    r.boot = 0; r.hasV = 0
    // counts for the diagnostics
    r.Nrep = c.N1; r.Crep = colsum(n1c :> 0)'
    r.Cpair = J(M, 1, .)
    for (i = 1; i <= M; i++) {
        r.Cpair[i] = rows(y1c)
        for (j = 1; j <= M; j++) r.Cpair[i] = min((r.Cpair[i], sum((y1c[., i] :< .) :& (y1c[., j] :< .))))
    }
    return(r)
}

// from (S, R, ome, chi, b0, b1, wbar, n0, n1) to the elasticities
void _duvm_chain(struct duvm_r scalar r)
{
    real scalar M
    M = r.M
    r.Sf = r.S - diag(r.ome :/ r.n1)
    r.Rf = r.R - diag(r.chi :/ r.n0)
    r.B  = invsym(r.Sf) * r.Rf
    r.el  = 1 :- r.b1 + r.b0 :/ r.wbar
    r.Enq = diag(1 :/ r.wbar) * r.B' - I(M)
    _duvm_elast(r.B, r.b0, r.b1, r.wbar, r.cf, r.Psi, r.Theta, r.Ens, r.zeta)
    _duvm_complete(r.Theta, r.b0, r.b1, r.wbar, r.qother, r.cf, r.Thx, r.Psix, r.Exns, r.ex, r.zx, r.wx)
    if (r.sym) {
        r.Bsym = _duvm_symmetry(r.B, r.Sf, r.b0, r.wbar)
        _duvm_elast(r.Bsym, r.b0, r.b1, r.wbar, r.cf, r.Psi, r.Theta, r.Esy, r.zeta)
        _duvm_complete(r.Theta, r.b0, r.b1, r.wbar, r.qother, r.cf, r.Thx, r.Psix, r.Exsy, r.ex, r.zx, r.wx)
    }
    else {
        r.Bsym = r.B; r.Esy = r.Ens; r.Exsy = r.Exns
    }
}

struct duvm_r scalar _duvm_estimate(struct duvm_d scalar d, real rowvector cf,
                                    real scalar sym, real scalar qother)
{
    struct duvm_c scalar c
    c = _duvm_stage1(d, cf)
    return(_duvm_stage2(c, (1::c.C), cf, sym, qother))
}

// the parameter vector reported in e(b): vec by row of E_x, then e_x, then b1
real rowvector _duvm_bvec(struct duvm_r scalar r)
{
    return((vec(r.Exsy')', r.ex', r.b1'))
}

// ---------------------------------------------------------------- bootstrap
// draw PSUs with replacement within strata; returns the list of drawn PSU codes
real colvector _duvm_draw(real colvector pstrat, real colvector plist)
{
    real colvector u, out, ids
    real scalar h, nh
    u = uniqrows(pstrat)
    out = J(0, 1, .)
    for (h = 1; h <= rows(u); h++) {
        ids = select(plist, pstrat :== u[h])
        nh = rows(ids)
        out = out \ ids[ceil(nh :* runiform(nh, 1))]
    }
    return(out)
}

void _duvm_boot(struct duvm_d scalar d, struct duvm_r scalar r, real scalar reps,
                real scalar seed, real scalar shortcut, real rowvector cf,
                real scalar sym, real scalar qother)
{
    struct duvm_c scalar c
    struct duvm_d scalar db
    struct duvm_r scalar rb
    real matrix pinfo, B
    real colvector porder, psu_s, pstrat, plist, draws, idx, cidb, cstrat, ok, sel
    real scalar P, t, p, K, i, n, pos

    if (seed >= 0) rseed(seed)
    K = cols(_duvm_bvec(r))
    B = J(reps, K, .)
    if (shortcut) {
        // Deaton's shortcut: stage 1 once, resample the cluster-level file
        c = _duvm_stage1(d, cf)
        // stratum of a cluster = stratum of its first household
        porder = order(d.cid, 1)
        pinfo  = panelsetup(d.cid[porder], 1)
        cstrat = d.strat[porder][pinfo[., 1]]
        plist  = (1::c.C)
        for (t = 1; t <= reps; t++) {
            sel = _duvm_draw(cstrat, plist)
            rb = _duvm_stage2(c, sel, cf, sym, qother)
            B[t, .] = _duvm_bvec(rb)
            _duvm_dots(t, reps)
        }
    }
    else {
        // both stages: resample PSUs within strata, households travel with them
        porder = order(d.psu, 1)
        pinfo  = panelsetup(d.psu[porder], 1)
        P = rows(pinfo)
        pstrat = d.strat[porder][pinfo[., 1]]
        plist  = (1::P)
        for (t = 1; t <= reps; t++) {
            draws = _duvm_draw(pstrat, plist)
            n = sum(pinfo[draws, 2] - pinfo[draws, 1] :+ 1)
            idx = J(n, 1, .); cidb = J(n, 1, .)
            pos = 0
            for (i = 1; i <= rows(draws); i++) {
                p = draws[i]
                n = pinfo[p, 2] - pinfo[p, 1] + 1
                idx[|pos+1 \ pos+n|]  = porder[|pinfo[p, 1] \ pinfo[p, 2]|]
                // a PSU drawn twice is two distinct clusters
                cidb[|pos+1 \ pos+n|] = d.cid[porder[|pinfo[p, 1] \ pinfo[p, 2]|]] :+ (i - 1) * d.C
                pos = pos + n
            }
            db.W = d.W[idx, .]; db.UV = d.UV[idx, .]; db.X = d.X[idx, .]
            db.LAM = d.LAM[idx, .]; db.hasl = d.hasl
            db.w = d.w[idx]; db.reg = d.reg[idx]; db.sub = d.sub[idx]
            db.cid = _duvm_dense(cidb); db.N = rows(idx); db.C = max(db.cid)
            db.strat = d.strat[idx]; db.psu = d.psu[idx]; db.fpc = d.fpc[idx]
            rb = _duvm_estimate(db, cf, sym, qother)
            B[t, .] = _duvm_bvec(rb)
            _duvm_dots(t, reps)
        }
    }
    ok = (rowsum(B :>= .) :== 0)
    r.reps = reps; r.reps_ok = sum(ok); r.boot = 1; r.shortcut = shortcut; r.seed = seed
    r.bootb = B
    if (r.reps_ok >= 2) {
        B = select(B, ok)
        r.V = quadvariance(B)
    }
    else r.V = J(K, K, .)
}

void _duvm_dots(real scalar t, real scalar reps)
{
    if (t == 1) printf("{txt}Bootstrap replications ({res}%g{txt})\n", reps)
    if (mod(t, 50) == 0) printf(".%g\n", t)
    else printf(".")
    if (t == reps & mod(t, 50) != 0) printf("\n")
    displayflush()
}

// ---------------------------------------------------------------- driver
// vtype: 0 none, 1 linearized clustered by the price cluster, 2 linearized
// survey design, 3 bootstrap
void _duvm_run(string scalar Rname, string scalar wvars, string scalar uvvars,
               string scalar Xvars, string scalar lamvars, string scalar wtvar,
               string scalar clvar, string scalar regvar, string scalar subvar,
               string scalar stvar, string scalar psvar, string scalar fpcvar,
               string scalar touse, string scalar cfstr, real scalar sym, real scalar qother,
               real scalar vtype, real scalar reps, real scalar seed, real scalar shortcut)
{
    struct duvm_d scalar d
    struct duvm_c scalar c
    struct duvm_r scalar r
    real rowvector cf
    pointer(struct duvm_r scalar) scalar p

    cf = strtoreal(tokens(cfstr))
    d = _duvm_load(wvars, uvvars, Xvars, lamvars, wtvar, clvar, regvar, subvar, stvar, psvar, fpcvar, touse)
    c = _duvm_stage1(d, cf)
    r = _duvm_stage2(c, (1::c.C), cf, sym, qother)
    if (vtype == 3) {
        _duvm_boot(d, r, reps, seed, shortcut, cf, sym, qother)
        r.hasV = (r.reps_ok >= 2)
    }
    else if (vtype == 1 | vtype == 2) _duvm_analytic(c, r, vtype == 2)
    p = crexternal(Rname)
    *p = r
}

void _duvm_b(string scalar Rname, string scalar goods, string scalar bname, string scalar Vname)
{
    struct duvm_r scalar r
    string rowvector g, gx
    string matrix cs
    real scalar M, j
    pointer(struct duvm_r scalar) scalar p

    p = findexternal(Rname); r = *p
    M = r.M
    g = tokens(goods); gx = (g, "other")
    cs = J(0, 2, "")
    for (j = 1; j <= M+1; j++) cs = cs \ (J(M+1, 1, gx[j]), gx')
    cs = cs \ (J(M+1, 1, "exp"), gx') \ (J(M, 1, "qual"), g')
    st_matrix(bname, _duvm_bvec(r))
    st_matrixcolstripe(bname, cs)
    if (r.hasV) {
        st_matrix(Vname, r.V)
        st_matrixcolstripe(Vname, cs)
        st_matrixrowstripe(Vname, cs)
    }
    st_local("duvm_N", strofreal(r.N))
    st_local("duvm_hasV", strofreal(r.hasV))
}

void _duvm_post(string scalar Rname, string scalar goods, string scalar Xnames)
{
    struct duvm_r scalar r
    string rowvector g, gx, xn
    real scalar M, K
    real colvector se
    pointer(struct duvm_r scalar) scalar p

    p = findexternal(Rname); r = *p
    M = r.M
    g = tokens(goods); gx = (g, "other")
    xn = tokens(Xnames)

    st_numscalar("e(N_clust)", r.C)
    _duvm_mat("e(elast_price)",        r.Exsy, gx, gx)
    _duvm_mat("e(elast_price_ns)",     r.Exns, gx, gx)
    _duvm_mat("e(elast_price_noqual)", r.Enq,  g,  g)
    _duvm_mat("e(elast_price_M)",      r.Esy,  g,  g)
    _duvm_mat("e(elast_price_M_ns)",   r.Ens,  g,  g)
    _duvm_mat("e(elast_exp)",  r.el', "Elasticity", g)
    _duvm_mat("e(elast_exp_x)", r.ex', "Elasticity", gx)
    _duvm_mat("e(elast_qual)", r.b1', "Elasticity", g)
    _duvm_mat("e(shares_mean)", r.wbar', "Share", g)
    _duvm_mat("e(zeta)",  r.zeta', "zeta", g)
    _duvm_mat("e(zeta_x)", r.zx', "zeta", gx)
    _duvm_mat("e(b0)", r.b0', "b0", g)
    _duvm_mat("e(b1)", r.b1', "b1", g)
    _duvm_mat("e(omega)", r.ome', "omega", g)
    _duvm_mat("e(sigma)", r.sig', "sigma", g)
    _duvm_mat("e(chi)",   r.chi', "chi", g)
    _duvm_mat("e(n0)", r.n0', "n", g)
    _duvm_mat("e(n1)", r.n1', "n_plus", g)
    _duvm_mat("e(S)",  r.S,  g, g)
    _duvm_mat("e(R)",  r.R,  g, g)
    _duvm_mat("e(Sf)", r.Sf, g, g)
    _duvm_mat("e(Rf)", r.Rf, g, g)
    _duvm_mat("e(B_ols)", r.Bols, g, g)
    _duvm_mat("e(B)",     r.B,    g, g)
    _duvm_mat("e(B_sym)", r.Bsym, g, g)
    _duvm_mat("e(Psi)",   r.Psi,  g, g)
    _duvm_mat("e(Theta)", r.Theta, g, g)
    _duvm_mat("e(Psi_x)",   r.Psix, gx, gx)
    _duvm_mat("e(Theta_x)", r.Thx,  gx, gx)
    _duvm_mat("e(beta0)", r.beta0, xn, g)
    _duvm_mat("e(beta1)", r.beta1, xn, g)
    // legacy names of the WELCOM version
    _duvm_mat("e(elprice)",  r.Exsy[1..M, 1..M], g, g)
    _duvm_mat("e(elincome)", r.el', "Elasticity", g)
    _duvm_mat("e(N_report)",       r.Nrep', "N", g)
    _duvm_mat("e(N_clust_report)", r.Crep', "N", g)
    _duvm_mat("e(N_clust_pair)",   r.Cpair', "N", g)
    if (r.hasV) {
        K = (M+1)^2
        se = sqrt(diagonal(r.V))
        _duvm_mat("e(se_elast_price)", rowshape(se[1..K], M+1), gx, gx)
        _duvm_mat("e(se_elast_exp_x)", se[K+1..K+M+1]', "Std. err.", gx)
        _duvm_mat("e(se_elast_exp)",   se[K+1..K+M]', "Std. err.", g)
        _duvm_mat("e(se_elast_qual)",  se[K+M+2..K+2*M+1]', "Std. err.", g)
        if (r.boot) {
            st_matrix("e(boot_b)", r.bootb)
            st_numscalar("e(N_reps_ok)", r.reps_ok)
        }
        else {
            st_matrix("e(G)", r.G)
            st_matrix("e(V_eta)", r.Veta)
            st_numscalar("e(N_psu)", r.P)
        }
    }
    rmexternal(Rname)
}

void _duvm_mat(string scalar name, real matrix A, string rowvector rn, string rowvector cn)
{
    st_matrix(name, A)
    st_matrixrowstripe(name, (J(rows(A), 1, ""), rn'))
    st_matrixcolstripe(name, (J(cols(A), 1, ""), cn'))
}
end
