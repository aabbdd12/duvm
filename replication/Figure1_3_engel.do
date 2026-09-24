* Figure1_3_engel.do — Figures 1 to 3 of the note: the Engel curves after the
* model of Table 3 (weighted, linearized SE clustered by psu), drawn by
* estat engel against the percentiles of total expenditure:
*   Figure 1  the budget share
*   Figure 2  the log unit value (quality)
*   Figure 3  the log quantity, normalized to 0 at the mean of ln x
* The graphs go to ../paper/fig as PDF, the plotted curves to out/.
do _setup.do
capture mkdir "../paper"
capture mkdir "../paper/fig"
use "$DATA", clear
qui duvm $GOODS [aw=sweight], $OPTS notable
local i 0
foreach c in share quality quantity {
    local ++i
    local o = cond("`c'" == "quantity", "normalize", "")
    estat engel, `c' `o' data("out/figure`i'_engel_`c'.dta") title("")
    graph export "../paper/fig/fig_engel_`c'.pdf", replace
}
