* Table5_variance_validation.do — Table 5: the linearized standard errors
* against the design bootstrap of both stages (400 replications), under simple
* random sampling of clusters, with sampling weights, and with a stratified
* survey design read from svyset. Own-price SE and the distribution of the
* ratio over the 34 parameters of e(b).
do _setup.do
if "$BOOT" == "" global BOOT 1
local reps = cond($BOOT, 400, 40)

capture mata: mata drop _ratio()
mata:
real rowvector _ratio(real matrix Va, real matrix Vb)
{
    real colvector sa, sb, r, ok
    sa = sqrt(diagonal(Va)); sb = sqrt(diagonal(Vb))
    ok = sb :> 1e-8
    r = select(sa, ok) :/ select(sb, ok)
    _sort(r, 1)
    return((min(r), r[ceil(rows(r)/2)], max(r), rows(r)))
}
end

tempname T5 R5
local first 1
local rn ""

foreach case in srs aw svy {
    use "$DATA", clear
    if "`case'" == "srs" {
        local w ""
        local v "vce(cluster)"
        local vb "vce(bootstrap, reps(`reps') seed(11))"
    }
    if "`case'" == "aw" {
        local w "[aw=sweight]"
        local v "vce(cluster)"
        local vb "vce(bootstrap, reps(`reps') seed(12))"
    }
    if "`case'" == "svy" {
        svyset psu [pw=sweight], strata(quintile)
        local w ""
        local v "vce(svy)"
        local vb "vce(bootstrap, reps(`reps') seed(13) svy)"
    }
    qui duvm $GOODS `w', $OPTS `v'
    mata: Va = st_matrix("e(V)")
    tempname sa
    matrix `sa' = vecdiag(e(se_elast_price))
    qui duvm $GOODS `w', $OPTS `vb'
    mata: Vb = st_matrix("e(V)")
    tempname sb
    matrix `sb' = vecdiag(e(se_elast_price))
    if `first' matrix `T5' = `sa' \ `sb'
    else       matrix `T5' = `T5' \ `sa' \ `sb'
    local rn `rn' `case'_linearized `case'_bootstrap
    if `first' mata: st_matrix("`R5'", _ratio(Va, Vb))
    else       mata: st_matrix("`R5'", st_matrix("`R5'") \ _ratio(Va, Vb))
    local first 0
}
matrix rownames `T5' = `rn'
matrix colnames `T5' = `e(goods)' other
wcsv table5_ownprice_se `T5'
matrix rownames `R5' = srs aw svy
matrix colnames `R5' = min median max parameters
wcsv table5_ratios `R5'
matlist `T5'
matlist `R5'
