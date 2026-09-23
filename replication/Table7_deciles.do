* Table7_deciles.do — Table 7: own-price elasticities by quintile of per capita
* current income, the model re-estimated within each quintile, linearized SE.
* (By decile, as in the WELCOM manual, the groups keep fewer than two reporting
* households per cluster and several elasticities become unstable; the decile
* run is kept in out/table7_deciles10.csv for the record.)
do _setup.do
use "$DATA", clear
duvm $GOODS [aw=sweight], $OPTS hgroup(decile)
tempname T10
matrix `T10' = e(elast_price_own_group)
wcsv table7_deciles10 `T10'
use "$DATA", clear
duvm $GOODS [aw=sweight], $OPTS hgroup(quintile)
tempname T7
matrix `T7' = e(elast_price_own_group)
wcsv table7_deciles `T7'
