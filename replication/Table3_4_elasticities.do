* Table3_4_elasticities.do — Table 3 (the price elasticities of quantity,
* completed system, symmetry restricted, with linearized SE clustered by psu)
* and Table 4 (own-price elasticities across the four treatments: no quality
* correction, quality corrected unrestricted, symmetry restricted, completed).
do _setup.do
use "$DATA", clear
duvm $GOODS [aw=sweight], $OPTS

tempname E SE T4
matrix `E' = e(elast_price)
matrix `SE' = e(se_elast_price)
wcsv table3_elast `E'
wcsv table3_se `SE'

local M = e(M)
matrix `T4' = J(`M', 4, .)
forvalues j = 1/`M' {
    matrix `T4'[`j', 1] = el(e(elast_price_noqual), `j', `j')
    matrix `T4'[`j', 2] = el(e(elast_price_M_ns), `j', `j')
    matrix `T4'[`j', 3] = el(e(elast_price_M), `j', `j')
    matrix `T4'[`j', 4] = el(e(elast_price), `j', `j')
}
matrix rownames `T4' = `e(goods)'
matrix colnames `T4' = no_quality quality_unrestricted quality_symmetric completed
wcsv table4_treatments `T4'
matlist `T4'
