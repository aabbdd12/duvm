* TableA1_corrections.do — Table A1 of the appendix: from the formulas of the
* WELCOM/posted code to the book, one correction at a time; own-price
* elasticities of the completed, symmetry-restricted system (weighted model).
* compatflags(): zeta completion sign counts chi mean region
do _setup.do
use "$DATA", clear
tempname T
local rn ""
local steps `""zeta completion sign counts chi mean region" "completion sign counts chi mean region" "sign counts chi mean region" "counts chi mean region" "chi mean region" "mean region" "region" """'
* row names (make_tables.py spells them out): welcom, then each correction added
local lab welcom zeta completion sign counts chi mean region
local i 0
foreach f of local steps {
    local ++i
    local l : word `i' of `lab'
    if "`f'" == "" qui duvm $GOODS [aw=sweight], $OPTS vce(none)
    else           qui duvm $GOODS [aw=sweight], $OPTS vce(none) compatflags(`f')
    if `i' == 1 matrix `T' = vecdiag(e(elast_price))
    else        matrix `T' = `T' \ vecdiag(e(elast_price))
    local rn `rn' `l'
}
matrix rownames `T' = `rn'
matrix colnames `T' = corn wheat rice other composite
wcsv tableA1_corrections `T'
matlist `T', format(%8.4f)
