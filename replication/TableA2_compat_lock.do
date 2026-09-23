* TableA2_compat_lock.do — Table A2: duvm, compat, against the frozen output
* of the WELCOM version (tests/lock, six cases): largest relative difference
* over every intermediate matrix and the final elasticities.
do _setup.do
capture confirm file "$ROOT/tests/lock/lock_w_region.mmat"
if _rc {
    di as txt "tests/lock is not available; Table A2 skipped"
    exit
}
capture mata: mata drop _lockdiff()
mata:
real rowvector _lockdiff(string scalar f)
{
    real scalar d1, d2
    string rowvector pairs
    real scalar i
    real matrix A, B
    pointer(real matrix) scalar p
    d1 = 0; d2 = 0
    pairs = ("e(b0)","b0","e(b1)","b1","e(omega)","ome","e(chi)","lam","e(n0)","n0","e(n1)","n1",
             "e(S)","s","e(Sf)","sf","e(Rf)","rf","e(B_ols)","bols","e(B_sym)","btild")
    for (i = 1; i <= cols(pairs); i = i + 2) {
        A = st_matrix(pairs[i]); p = findexternal("L_" + pairs[i+1]); B = *p
        if (rows(A) != rows(B)) A = A'
        d1 = max((d1, max(abs(A - B) :/ (1 :+ abs(B)))))
    }
    pairs = ("e(elast_price_M_ns)","B_NS_ep","e(elast_price_M)","B_SY_ep","e(elast_price_ns)","C_NS_ep","e(elast_price)","C_SY_ep")
    for (i = 1; i <= cols(pairs); i = i + 2) {
        A = st_matrix(pairs[i]); p = findexternal("L_" + pairs[i+1]); B = *p
        d2 = max((d2, max(abs(A - B) :/ (1 :+ abs(B)))))
    }
    return((d1, d2))
}
end
tempname T
local cases w_region unw_region w_noregion w_region_csb w_region_con
local opts `""hweight(sweight)" "" "hweight(sweight)" "hweight(sweight) csb(1)" "hweight(sweight)""'
local i 0
foreach c of local cases {
    local ++i
    local o : word `i' of `opts'
    use "$DATA", clear
    if "`c'" == "w_noregion" local b "hhsize(hhsize) expend(hh_current_inc) cluster(psu) indcat(sex educ) indcon(age)"
    else if "`c'" == "w_region_con" local b "hhsize(hhsize) expend(hh_current_inc) cluster(psu) indcon(age perc_ocupa) region(rururb)"
    else local b "$OPTS"
    qui duvm $GOODS, `b' `o' compat vce(none)
    mata: mata matuse "$ROOT/tests/lock/lock_`c'.mmat", replace
    if `i' == 1 mata: st_matrix("`T'", _lockdiff(""))
    else        mata: st_matrix("`T'", st_matrix("`T'") \ _lockdiff(""))
}
matrix rownames `T' = `cases'
matrix colnames `T' = moments elasticities
wcsv tableA2_compat_lock `T'
matlist `T', format(%10.2e)
