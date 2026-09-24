* TableA2_compat_code.do — Table A2: duvm, compat, against a line-by-line
* transcription of the Stata code published with Deaton (1997, ch. 5),
* deaton_1997_ch5.do; unweighted, with and without the region purge. Largest
* relative difference |a - b| / (1 + |b|) over the first-stage and
* second-stage quantities, and over the elasticities.
do _setup.do
capture mata: mata drop _codediff()
mata:
real rowvector _codediff()
{
    real scalar d1, d2, i
    string rowvector pairs
    real matrix A, B
    d1 = 0; d2 = 0
    pairs = ("e(shares_mean)","bk_wbar","e(b0)","bk_b0","e(b1)","bk_b1","e(zeta)","bk_xi",
             "e(B)","bk_bhat","e(B_sym)","bk_btild")
    for (i = 1; i <= cols(pairs); i = i + 2) {
        A = st_matrix(pairs[i]); B = st_matrix(pairs[i+1])
        if (rows(A) != rows(B)) A = A'
        d1 = max((d1, max(abs(A - B) :/ (1 :+ abs(B)))))
    }
    pairs = ("e(elast_exp)","bk_el","e(elast_exp_x)","bk_xe",
             "e(elast_price_M_ns)","bk_ep_ns","e(elast_price_M)","bk_ep_sym",
             "e(elast_price_ns)","bk_xep_ns","e(elast_price)","bk_xep_sym")
    for (i = 1; i <= cols(pairs); i = i + 2) {
        A = st_matrix(pairs[i]); B = st_matrix(pairs[i+1])
        if (rows(A) != rows(B)) A = A'
        d2 = max((d2, max(abs(A - B) :/ (1 :+ abs(B)))))
    }
    return((d1, d2))
}
end
tempname T
local i 0
foreach c in region noregion {
    local ++i
    local reg = cond("`c'" == "region", "rururb", "")
    local o = cond("`c'" == "region", "$OPTS", subinstr("$OPTS", "region(rururb)", "", .))
    use "$DATA", clear
    qui do deaton_1997_ch5.do "$GOODS" "i.sex i.educ age" `reg'
    use "$DATA", clear
    qui duvm $GOODS, `o' compat vce(none)
    if `i' == 1 mata: st_matrix("`T'", _codediff())
    else        mata: st_matrix("`T'", st_matrix("`T'") \ _codediff())
}
matrix rownames `T' = region noregion
matrix colnames `T' = moments elasticities
wcsv tableA2_compat_code `T'
matlist `T', format(%10.2e)
