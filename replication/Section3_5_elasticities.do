* Section3_5_elasticities.do — Section 3.5 of the note (which elasticity: of
* the household, of the individual or of the market; option elasticities() of
* duvm 1.1.5): the own-price and expenditure elasticities of the four goods and
* the budget shares at which they are evaluated, with linearized standard
* errors, for the three types; out/sec35_types.csv.
do _setup.do
use "$DATA", clear
tempname T
matrix `T' = J(4, 15, .)
local c 0
foreach t in households individuals market {
    qui duvm $GOODS [aw=sweight], $OPTS elasticities(`t') notable
    tempname E SE X SX W
    matrix `E'  = e(elast_price)
    matrix `SE' = e(se_elast_price)
    matrix `X'  = e(elast_exp)
    matrix `SX' = e(se_elast_exp)
    matrix `W'  = e(shares_mean)
    forvalues j = 1/4 {
        matrix `T'[`j', `c' + 1] = `E'[`j', `j']
        matrix `T'[`j', `c' + 2] = `SE'[`j', `j']
        matrix `T'[`j', `c' + 3] = `X'[1, `j']
        matrix `T'[`j', `c' + 4] = `SX'[1, `j']
        matrix `T'[`j', `c' + 5] = 100 * `W'[1, `j']
    }
    local c = `c' + 5
}
matrix rownames `T' = $GOODS
matrix colnames `T' = hh_own hh_own_se hh_exp hh_exp_se hh_share_pct ///
    ind_own ind_own_se ind_exp ind_exp_se ind_share_pct ///
    mkt_own mkt_own_se mkt_exp mkt_exp_se mkt_share_pct
wcsv sec35_types `T'
matlist `T', format(%8.3f) title("Own-price and expenditure elasticities: households, individuals, market")
