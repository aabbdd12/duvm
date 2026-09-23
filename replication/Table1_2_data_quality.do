* Table1_2_data_quality.do — Table 1 (the data behind each good) and Table 2
* (first-stage parameters: b0, b1, expenditure elasticity, zeta, quality share,
* unit-value response to own price) of the technical note.
do _setup.do
use "$DATA", clear
duvm $GOODS [aw=sweight], $OPTS

tempname T1 T2
matrix `T1' = e(shares_mean)' * 100, e(N_report)', (e(N_report)' / e(N)) * 100, e(N_clust_report)', e(n1)', e(n0)'
matrix colnames `T1' = share_pct reporters reporters_pct clusters n_plus_harm n_harm
matrix rownames `T1' = `e(goods)'
wcsv table1_data `T1'

matrix `T2' = e(b0)' , e(se_elast_exp)' , e(b1)', e(se_elast_qual)', e(elast_exp)', e(zeta)', hadamard(e(zeta), e(shares_mean))', vecdiag(e(Psi))'
matrix colnames `T2' = b0 se_e b1 se_b1 e zeta zeta_wbar psi_GG
matrix rownames `T2' = `e(goods)'
wcsv table2_quality `T2'
matlist `T1'
matlist `T2'
