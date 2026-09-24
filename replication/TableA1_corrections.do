* TableA1_corrections.do — Table A1 of the appendix: from the Stata code
* published with Deaton (1997) to the book's equations, one correction at a
* time; own-price elasticities of the completed, symmetry-restricted system.
* Unweighted, as Deaton's code is.
* compatflags(): zeta completion sign chi region (compat = all five)
do _setup.do
use "$DATA", clear
tempname T
local rn ""
local steps `""zeta completion sign chi region" "completion sign chi region" "sign chi region" "chi region" "region" """'
* row names (make_tables.py spells them out): the code, then each correction added
local lab code zeta completion sign chi region
local i 0
foreach f of local steps {
    local ++i
    local l : word `i' of `lab'
    if "`f'" == "" qui duvm $GOODS, $OPTS vce(none)
    else           qui duvm $GOODS, $OPTS vce(none) compatflags(`f')
    if `i' == 1 matrix `T' = vecdiag(e(elast_price))
    else        matrix `T' = `T' \ vecdiag(e(elast_price))
    local rn `rn' `l'
}
matrix rownames `T' = `rn'
matrix colnames `T' = corn wheat rice other composite
wcsv tableA1_corrections `T'
matlist `T', format(%8.4f)
