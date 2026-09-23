* Table6_shortcut.do — Table 6: the bootstrap of both stages against Deaton's
* shortcut (second stage only), own-price SE and their ratio; the shortcut
* gives no standard error to the expenditure and quality elasticities.
do _setup.do
if "$BOOT" == "" global BOOT 1
local reps = cond($BOOT, 400, 40)
use "$DATA", clear
qui duvm $GOODS [aw=sweight], $OPTS vce(bootstrap, reps(`reps') seed(1))
tempname full short T6
matrix `full' = vecdiag(e(se_elast_price)), e(se_elast_exp)
qui duvm $GOODS [aw=sweight], $OPTS vce(bootstrap, reps(`reps') seed(1) shortcut)
matrix `short' = vecdiag(e(se_elast_price)), e(se_elast_exp)
matrix `T6' = `full' \ `short'
mata: st_matrix("`T6'", st_matrix("`T6'") \ (st_matrix("`T6'")[1, .] :/ st_matrix("`T6'")[2, .]))
matrix rownames `T6' = both_stages shortcut ratio
matrix colnames `T6' = p_corn p_wheat p_rice p_other p_composite e_corn e_wheat e_rice e_other
wcsv table6_shortcut `T6'
matlist `T6'
