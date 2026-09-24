* deaton_1997_ch5.do — the Stata code published with Deaton (1997, ch. 5),
* programs allindia.do and mkmats.do of the World Bank LSMS site, transcribed
* step by step for the Mexican cereal data. It is the independent reference
* that duvm, compat must reproduce (Table A2).
*
* Every formula is kept as Deaton wrote it, including the three departures
* from the book's equations (the zeta formula of mormat, the reciprocal zeta
* through syminv(diag(b1)) in complet, the sign of the last row of the
* extended Theta) and its conventions (lambda from the auxiliary regression,
* region of the first household of the cluster). Only the syntax is modern:
*     $S_E_sse/$S_E_tdf  -> e(rss)/e(df_r)
*     _result(3)         -> r(mean) (summarize)
*     _result(4)         -> el(r(C), 1, 2) (correlate, covariance)
*     areg's regressor list is given explicitly; the purged series subtract
*     x'b without the constant, as Deaton's gen y1... lines do.
* The code is unweighted, as Deaton's is.
*
* usage (data in memory):
*     do deaton_1997_ch5.do "corn wheat rice other" "i.sex i.educ age" rururb
* leaves in memory: bk_wbar bk_b0 bk_b1 bk_xi bk_el bk_bhat bk_btild
*     bk_ep_ns bk_xep_ns bk_ep_sym bk_xep_sym bk_xe
args goods xvars region
version 14.2

tempfile hh
quietly {
    gen double lnexp = ln(hh_current_inc)
    gen double lhhs = ln(hhsize)
    gen long cluster = psu
    local X "lnexp lhhs `xvars'"
    * the sample of the regressions (duvm drops households with a missing regressor)
    tempvar touse
    gen byte `touse' = 1
    markout `touse' hh_current_inc hhsize `=subinstr("`xvars'", "i.", "", .)'
    keep if `touse'
    local ngds : word count `goods'
    global ngds `ngds'

    matrix define sig  = J(`ngds', 1, 0)
    matrix define ome  = J(`ngds', 1, 0)
    matrix define lam  = J(`ngds', 1, 0)
    matrix define wbar = J(`ngds', 1, 0)
    matrix define b1   = J(`ngds', 1, 0)
    matrix define b0   = J(`ngds', 1, 0)

    * mkwbar: average budget shares (unweighted)
    local ig 1
    foreach g of local goods {
        summarize w`g'
        matrix wbar[`ig', 1] = r(mean)
        local ++ig
    }

    * st1reg: first stage, within cluster
    local ig 1
    foreach g of local goods {
        areg luv`g' `X', absorb(cluster)
        matrix ome[`ig', 1] = e(rss) / e(df_r)
        matrix b1[`ig', 1] = _b[lnexp]
        predict double ruv`g' if e(sample), resid
        predict double xb1 if e(sample), xb
        gen double y1`g' = luv`g' - (xb1 - _b[_cons])
        drop xb1
        areg w`g' `X', absorb(cluster)
        predict double rw`g' if e(sample), resid
        matrix sig[`ig', 1] = e(rss) / e(df_r)
        matrix b0[`ig', 1] = _b[lnexp]
        predict double xb0 if e(sample), xb
        gen double y0`g' = w`g' - (xb0 - _b[_cons])
        drop xb0
        * the regression that gives the covariance of the residuals
        areg ruv`g' rw`g' `X', absorb(cluster)
        matrix lam[`ig', 1] = _b[rw`g'] * sig[`ig', 1]
        drop rw`g' ruv`g'
        local ++ig
    }

    * clustit: cluster means and counts
    local ig 1
    foreach g of local goods {
        egen double y0c`ig' = mean(y0`g'), by(cluster)
        egen n0c`ig' = count(y0`g'), by(cluster)
        egen double y1c`ig' = mean(y1`g'), by(cluster)
        egen n1c`ig' = count(y1`g'), by(cluster)
        local ++ig
    }
    * one observation per cluster: the first household (data order kept)
    sort cluster, stable
    by cluster: keep if _n == 1

    * purge: remove the region effects
    if "`region'" != "" {
        tab `region', gen(regiond)
        drop regiond1
    }
    forvalues ig = 1/`ngds' {
        foreach p in 0 1 {
            if "`region'" != "" regress y`p'c`ig' regiond*
            else regress y`p'c`ig'
            predict double tm if e(sample), resid
            replace y`p'c`ig' = tm
            drop tm
        }
    }

    * mkns: harmonic means of the cluster sizes
    matrix define n0 = J(`ngds', 1, 0)
    matrix define n1 = J(`ngds', 1, 0)
    forvalues ig = 1/`ngds' {
        replace n0c`ig' = 1 / n0c`ig'
        replace n1c`ig' = 1 / n1c`ig'
        summarize n0c`ig'
        matrix n0[`ig', 1] = (r(mean))^(-1)
        summarize n1c`ig'
        matrix n1[`ig', 1] = (r(mean))^(-1)
    }

    * mkcov: between-cluster covariances, pair by pair
    matrix s = J(`ngds', `ngds', 0)
    matrix r = J(`ngds', `ngds', 0)
    forvalues ir = 1/`ngds' {
        forvalues ic = 1/`ngds' {
            correlate y1c`ir' y1c`ic', covariance
            matrix s[`ir', `ic'] = el(r(C), 1, 2)
            correlate y1c`ir' y0c`ic', covariance
            matrix r[`ir', `ic'] = el(r(C), 1, 2)
        }
    }
}

* fixmat: measurement-error corrections
matrix sf = s
matrix rf = r
forvalues ig = 1/$ngds {
    matrix sf[`ig', `ig'] = sf[`ig', `ig'] - ome[`ig', 1] / n1[`ig', 1]
    matrix rf[`ig', `ig'] = rf[`ig', `ig'] - lam[`ig', 1] / n0[`ig', 1]
}
matrix invs = syminv(sf)
matrix bhat = invs * rf

* mormat
matrix xi = J($ngds, 1, 0)
matrix el = J($ngds, 1, 0)
forvalues ig = 1/$ngds {
    matrix xi[`ig', 1] = b1[`ig', 1] / (b0[`ig', 1] + (1 - b1[`ig', 1] * wbar[`ig', 1]))
    matrix el[`ig', 1] = 1 - b1[`ig', 1] + b0[`ig', 1] / wbar[`ig', 1]
}
global ng1 = $ngds + 1
matrix iden = I($ngds)
matrix iden1 = I($ng1)
matrix itm = J($ngds, 1, 1)
matrix itm1 = J($ng1, 1, 1)
matrix dxi = diag(xi)
matrix dwbar = diag(wbar)
matrix idwbar = syminv(dwbar)

capture program drop bk_mkels
program define bk_mkels
    matrix cmx = bhat'
    matrix cmx = dxi * cmx
    matrix cmx1 = dxi * dwbar
    matrix cmx = iden - cmx
    matrix cmx = cmx + cmx1
    matrix psi = inv(cmx)
    matrix theta = bhat' * psi
    matrix ep = bhat'
    matrix ep = idwbar * ep
    matrix ep = ep - iden
    matrix ep = ep * psi
end

capture program drop bk_complet
program define bk_complet
    matrix atm = theta * itm
    matrix atm = -1 * atm
    matrix atm = atm - b0
    matrix xtheta = theta, atm
    matrix atm = xtheta'
    matrix atm = atm * itm
    matrix atm = atm'
    matrix xtheta = xtheta \ atm
    matrix wlast = wbar' * itm
    matrix won = (1)
    matrix wlast = won - wlast
    matrix xwbar = wbar \ wlast
    matrix dxwbar = diag(xwbar)
    matrix idxwbar = syminv(dxwbar)
    matrix b1last = (0.25)
    matrix xb1 = b1 \ b1last
    matrix b0last = b0' * itm
    matrix b0last = -1 * b0last
    matrix xb0 = b0 \ b0last
    matrix xe = itm1 - xb1
    matrix tm = idxwbar * xb0
    matrix xe = xe + tm
    matrix xxi = itm1 - xb1
    matrix xxi = dxwbar * xxi
    matrix xxi = xxi + xb0
    matrix tm = diag(xb1)
    matrix tm = syminv(tm)
    matrix xxi = tm * xxi
    matrix dxxi = diag(xxi)
    matrix xpsi = dxxi * xtheta
    matrix xpsi = xpsi + iden1
    matrix atm = dxxi * dxwbar
    matrix atm = atm + iden1
    matrix atm = syminv(atm)
    matrix xpsi = atm * xpsi
    matrix ixpsi = inv(xpsi)
    matrix xbhatp = xtheta * ixpsi
    matrix xep = idxwbar * xbhatp
    matrix xep = xep - iden1
    matrix xep = xep * xpsi
end

* mkmats: commutation matrix, lower-triangle selection, vec and unvec
capture program drop bk_commx
program define bk_commx
    local n2 = `1'^2
    matrix `2' = J(`n2', `n2', 0)
    local i 1
    local ik 0
    while `i' <= `1' {
        local j 1
        local ij = `i'
        while `j' <= `1' {
            local ir = `j' + `ik'
            matrix `2'[`ir', `ij'] = 1
            local ij = `ij' + `1'
            local j = `j' + 1
        }
        local i = `i' + 1
        local ik = `ik' + `1'
    }
end
capture program drop bk_vecmx
program define bk_vecmx
    local n = rowsof(`1')
    local n2 = `n'^2
    matrix `2' = J(`n2', 1, 0)
    forvalues j = 1/`n' {
        forvalues i = 1/`n' {
            matrix `2'[(`j'-1)*`n' + `i', 1] = `1'[`i', `j']
        }
    }
end
capture program drop bk_lmx
program define bk_lmx
    local ng2 = `1'^2
    local nr = 0.5 * `1' * (`1' - 1)
    matrix `2' = J(`nr', `ng2', 0)
    local ia 2
    local ij 1
    while `ij' <= `nr' {
        local ik 0
        local klim = `1' - `ia'
        while `ik' <= `klim' {
            local ip = `ia' + (`ia' - 2) * `1' + `ik'
            matrix `2'[`ij', `ip'] = 1
            local ij = `ij' + 1
            local ik = `ik' + 1
        }
        local ia = `ia' + 1
    }
end
capture program drop bk_unvecmx
program define bk_unvecmx
    local n2 = rowsof(`1')
    local n = sqrt(`n2')
    matrix `2' = J(`n', `n', 0)
    forvalues i = 1/`n' {
        forvalues j = 1/`n' {
            matrix `2'[`i', `j'] = `1'[(`j'-1)*`n' + `i', 1]
        }
    }
end

* unrestricted
bk_mkels
matrix bk_ep_ns = ep
bk_complet
matrix bk_xep_ns = xep
matrix bk_xe = xe
matrix bk_bhat = bhat

* symmetry restricted (Deaton's approximation)
bk_vecmx bhat vbhat
bk_lmx $ngds llx
bk_commx $ngds k
global ng2 = $ngds * $ngds
matrix bigi = I($ng2)
matrix k = bigi - k
matrix r = llx * k
matrix rh = b0 # wbar
matrix rh = r * rh
matrix rh = -1 * rh
matrix iss = iden # invs
matrix rp = r'
matrix iss = iss * rp
matrix inn = r * iss
matrix inn = syminv(inn)
matrix inn = iss * inn
matrix dis = r * vbhat
matrix dis = rh - dis
matrix dis = inn * dis
matrix vbtild = vbhat + dis
bk_unvecmx vbtild btild
matrix bhat = btild
bk_mkels
matrix bk_ep_sym = ep
bk_complet
matrix bk_xep_sym = xep

matrix bk_wbar = wbar
matrix bk_b0 = b0
matrix bk_b1 = b1
matrix bk_xi = xi
matrix bk_el = el
matrix bk_btild = btild
