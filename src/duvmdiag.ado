*! duvmdiag 1.0.1  2026-09-24  Abdelkrim Araar
*! Pre-estimation diagnostic of the unit-value model: same syntax as duvm,
*! runs the two stages without the variance and reports what will make the
*! elasticities fragile (few reporters, tiny clusters, a correction that
*! swamps the price variation, negative quality elasticities, ill-conditioned
*! moment matrix).
program define duvmdiag, rclass
    version 14.2
    syntax anything(name=namelist id="goods") [if] [in] [aweight fweight pweight iweight] , [ DEC(integer 3) * ]
    local w ""
    if "`weight'" != "" local w "[`weight'`exp']"
    qui duvm `namelist' `if' `in' `w', `options' vce(none) notable
    duvm_estat diagnostics, dec(`dec')
    return add
end
