{smcl}
{* *! version 1.0.1  24sep2026}{...}
{vieweralsosee "duvmdiag" "help duvmdiag"}{...}
{viewerjumpto "Syntax" "duvm##syntax"}{...}
{viewerjumpto "Description" "duvm##description"}{...}
{viewerjumpto "Options" "duvm##options"}{...}
{viewerjumpto "Remarks" "duvm##remarks"}{...}
{viewerjumpto "Engel curves" "duvm##engel"}{...}
{viewerjumpto "Stored results" "duvm##results"}{...}
{viewerjumpto "Examples" "duvm##examples"}{...}
{viewerjumpto "References" "duvm##references"}{...}
{title:Title}

{p2colset 5 14 16 2}{...}
{p2col:{cmd:duvm} {hline 2}}Deaton's unit-value model: quality-corrected price and expenditure elasticities from budget shares and unit values{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:duvm} {it:goods} {ifin} [{it:{help duvm##weight:weight}}]{cmd:,}
{opt hhs:ize(varname)} {opt exp:end(varname)} {opt cl:uster(varname)}
[{it:options}]

{p 8 8 2}
{it:goods} is a list of item names; for each item {it:g} the data must contain
{cmd:w}{it:g}, the budget share, and {cmd:luv}{it:g}, the log of the unit value
(the households that do not buy the item have a zero, or missing, share; their
unit value, missing or not, is ignored: see {opt nonbuyers()}).

{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Model}
{p2coldent:* {opt hhs:ize(varname)}}household size{p_end}
{p2coldent:* {opt exp:end(varname)}}total expenditure (or income) of the household{p_end}
{p2coldent:* {opt cl:uster(varname)}}cluster (village, PSU) within which prices are constant{p_end}
{synopt:{opt indcon(varlist)}}continuous household characteristics{p_end}
{synopt:{opt indcat(varlist)}}categorical household characteristics (entered as dummies){p_end}
{synopt:{opt reg:ion(varname)}}region: its effect is removed from the cluster averages{p_end}
{synopt:{opt sub:round(varname)}}survey round: idem{p_end}
{synopt:{opt csb(1)}}add the inverse Mills ratio of a probit of purchase to the share equations{p_end}
{synopt:{opt nonb:uyers(mode)}}unit values of the households that do not buy the good: {cmd:drop} (the default), {cmd:average} or {cmd:asis}{p_end}
{synopt:{opt qoth:er(#)}}quality elasticity assumed for the composite of all other goods; default 0.25{p_end}
{synopt:{opt nosym:metry}}do not impose the (approximate) Slutsky symmetry{p_end}

{syntab:Variance}
{synopt:{opt vce(cluster)}}linearized, clustered by {opt cluster()}; the default{p_end}
{synopt:{opt vce(svy)}}linearized, with the design declared by {helpb svyset} (PSU, strata, FPC, weight){p_end}
{synopt:{cmd:vce(bootstrap} [{cmd:,} {it:{help duvm##bootopts:boot_opts}}]{cmd:)}}design bootstrap of both stages{p_end}
{synopt:{opt vce(none)}}point estimates only{p_end}
{synopt:{opt l:evel(#)}}confidence level; default {cmd:level(95)}{p_end}

{syntab:Reporting}
{synopt:{opt hg:roup(varname)}}re-estimate within each group and report the own-price elasticities{p_end}
{synopt:{opt dec(#)}}decimals displayed; default 3{p_end}
{synopt:{opt seall}}display the standard errors after every price-elasticity table, not only after the final one{p_end}
{synopt:{opt dreg:res(1)}}display the first-stage regressions{p_end}
{synopt:{opt notab:le}}suppress the tables{p_end}
{synopt:{opt st:ars}}tables with significance stars on the estimates, the standard errors of each table as Table {it:N}-b{p_end}
{synopt:{opt saveres(filename)}}write the tables to a file; the extension gives the format: {cmd:.docx}, {cmd:.tex}, {cmd:.xlsx}, {cmd:.csv}, {cmd:.md}{p_end}

{syntab:Compatibility}
{synopt:{opt hw:eight(varname)}}sampling weight, as an analytic weight (WELCOM syntax){p_end}
{synopt:{opt boot(#)}}same as {cmd:vce(bootstrap, reps(}{it:#}{cmd:))}{p_end}
{synopt:{opt compat}}reproduce the Stata code published with Deaton (1997); see {help duvm##compat:Remarks}{p_end}
{synopt:{opt compatf:lags(list)}}reproduce only some of its departures from the book; see {help duvm##compat:Remarks}{p_end}
{synoptline}
{p 4 6 2}* required.{p_end}

{marker weight}{...}
{p 4 6 2}{opt aweight}s, {opt fweight}s, {opt pweight}s and {opt iweight}s are allowed; see {help weight}.
The weights enter the first-stage regressions, the mean budget shares and the cluster
averages; the second stage treats every cluster as one observation.{p_end}

{marker bootopts}{...}
{synoptset 24}{...}
{synopthdr:boot_opts}
{synoptline}
{synopt:{opt r:eps(#)}}number of replications; default 200{p_end}
{synopt:{opt seed(#)}}random-number seed{p_end}
{synopt:{opt str:ata(varname)}}resample within strata{p_end}
{synopt:{opt psu(varname)}}resampling unit; default is {opt cluster()}{p_end}
{synopt:{opt svy}}take PSU, strata and weight from {helpb svyset}{p_end}
{synopt:{opt short:cut}}resample the cluster-level file only (Deaton's shortcut), the first stage held fixed{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:duvm} estimates the unit-value model of Deaton (1988, 1990, 1997 ch. 5):
own- and cross-price elasticities of quantity, expenditure elasticities and
quality elasticities for a group of goods, from the budget shares and the unit
values (expenditure divided by quantity) reported by households, using the
spatial variation of prices across clusters. It corrects the unit values for
quality shading and for measurement error, completes the system with a
composite good and imposes an approximate Slutsky symmetry.

{pstd}
The estimator is closed-form and runs in Mata. The first stage regresses,
within clusters, the budget shares and the log unit values on the log of
expenditure, the log of household size and the characteristics. The second
stage regresses the cluster averages of the purged shares on the cluster
averages of the purged unit values, with the errors-in-variables correction of
Deaton (1997, eq. 5.85). The quality parameter of eq. (5.92) then separates the
price elasticity from the quality response, eqs. (5.90)-(5.91); the system is
completed by eqs. (5.93)-(5.97) and the symmetry restriction of eqs.
(5.98)-(5.102) is imposed on the second-stage coefficients.

{pstd}
Standard errors are linearized by default: influence functions of every
first- and second-stage moment, including the generated-regressor terms of
the first-stage coefficients in the cluster averages, aggregated by cluster,
by survey PSU within strata with a finite-population correction under
{cmd:vce(svy)}, and combined through the analytic Jacobian of the chain from
the moments to the elasticities. A design bootstrap of the whole procedure is
available with {cmd:vce(bootstrap)}.


{marker options}{...}
{title:Options}

{dlgtab:Model}

{phang}
{opt hhsize(varname)}, {opt expend(varname)} and {opt cluster(varname)} are
required. The logs of household size and of expenditure are the first two
regressors of each first-stage equation; the coefficient of log expenditure in
the unit-value equation is the quality elasticity, its coefficient in the share
equation gives the expenditure elasticity of quantity.

{phang}
{opt indcon(varlist)} and {opt indcat(varlist)} add continuous variables and
sets of dummies (one per level, the first level omitted) to the first-stage
equations.

{phang}
{opt region(varname)} and {opt subround(varname)} remove region and
survey-round effects from the cluster-level series before the second stage
(Deaton's {it:purge}). The value of a cluster is that of its first household
with a non-missing value.

{phang}
{opt csb(1)} estimates, for each good, a probit of buying the good on the
first-stage regressors and adds the inverse Mills ratio to the share equation
of that good. Households whose Mills ratio cannot be computed leave that
equation.

{phang}
{opt nonbuyers(drop|average|asis)} says what to do with the unit values of the
households that do not buy the good. A {it:buyer} is a household whose budget
share is positive; a missing budget share is read as 0, so that a household that
does not buy a good stays in the model whatever the coding of its share (. or
0). A non-buyer has no unit value (an expenditure of 0 over a quantity of 0), but
survey files often hold one: a value imputed from the cluster or from a wider
area, or a 0.

{phang2}
{cmd:drop}, the default, ignores the unit value of every non-buyer, whatever its
coding: the unit-value equation is estimated on the buyers, as in Deaton (1997),
and a cluster without buyers has no price for that good. The households dropped
from that equation carry no information on quality, since they bought nothing.

{phang2}
{cmd:average} gives each non-buyer the weighted mean of the unit values of the
buyers of its cluster (never a value from outside the cluster), the rule of the
earlier WELCOM data preparation. It biases the quality elasticity toward zero,
the more so the rarer the good, since the added households carry no
within-cluster variation of the unit value; it also understates the
measurement-error variance and inflates the cluster sizes, so that the
errors-in-variables correction is too small. It is there to reproduce earlier
results.

{phang2}
{cmd:asis} takes the unit values as they are in the data, imputed or not; it is
the default under {opt compat}, as Deaton's code takes the data it is given.
{cmd:duvmdiag} and {cmd:estat diagnostics} count, good by good, the missing
shares, the non-buyers that have a unit value (and how many are coded 0), and the
clusters that have a unit value but no buyer.

{phang}
{opt qother(#)} is the quality elasticity assumed for the composite "all other
goods" when the system is completed; Deaton's code uses 0.25.

{phang}
{opt nosymmetry} reports the unrestricted second stage. By default the
restriction that {it:B} + {it:wbar b0'} is symmetric, eq. (5.98), is imposed as in
Deaton's code; it is exact only when quality effects are small.

{dlgtab:Variance}

{phang}
{opt vce(cluster)}, the default, is the linearized variance with the price
clusters as the sampling units. {opt vce(svy)} reads the survey design from
{helpb svyset}: the PSUs (which must contain the price clusters), the strata,
the finite-population correction and, when no weight is given to {cmd:duvm},
the sampling weight. {opt vce(bootstrap)} resamples PSUs with replacement
within strata and re-runs both stages on every replication; a PSU drawn twice
is two distinct clusters; the households keep their weights.
{opt shortcut} resamples the cluster-level file only, as Deaton (1997, p. 313)
did to save computer time; it holds the first stage fixed and therefore gives
no standard error to the expenditure and quality elasticities.

{dlgtab:Reporting}

{phang}
{opt hgroup(varname)} re-estimates the whole model within each group of the
variable (deciles, regions, ...) and reports the own-price elasticities by
group, with their standard errors.

{dlgtab:Compatibility}

{phang}
{opt hweight(varname)} and {opt boot(#)} keep the syntax of the earlier WELCOM
version of the command. {opt compat} switches to the formulas of the Stata code
published with Deaton (1997); see below.


{marker remarks}{...}
{title:Remarks}

{pstd}
{ul:What is estimated.} Write {it:w} for the budget share and {it:v} for the
unit value of a good, {it:x} for total expenditure and {it:pi} for the true
price of the cluster. The first stage estimates {it:b0} = dw/dln x and
{it:b1} = dln v/dln x within clusters. The expenditure elasticity of quantity
is 1 - {it:b1} + {it:b0}/{it:wbar}; the second stage estimates
{it:B} = Theta Psi^-1, where Theta = dw/dln pi and Psi = dln v/dln pi.
Quality shading links the two through the parameter zeta of eq. (5.92),
zeta = {it:b1} / [{it:b0} + {it:wbar}(1 - {it:b1})], so that Psi = [I - D(zeta)B' + D(zeta)D(wbar)]^-1,
Theta = B'Psi and the price elasticities of quantity are E = [D(wbar)^-1 B' - I]Psi.
Every estimate displayed has a standard error in {cmd:e()}: the shares, the
expenditure and quality elasticities, zeta, and the five price-elasticity
matrices; the tables show the standard errors of the final matrix, {opt seall}
shows them after every matrix, and {cmd:estat elasticities} shows those of the
variant it displays.
The tables are numbered as follows: 1 budget shares, 2
expenditure elasticities, 3 quality elasticities, 4 E with the unit values
taken as prices (no quality correction), 5-6 the quality-corrected M x M
system, unrestricted and symmetry restricted, 7-8 the completed system,
unrestricted and symmetry restricted (8 is the final matrix), 9 the standard
errors of Table 8, 10 the own-price elasticities by group. {opt stars} renders
the same tables with significance stars on the estimates, each table with a
variance followed by its standard errors as Table {it:N}-b, so Table 9 is not
repeated; {opt saveres(filename)} writes exactly these tables to one file
(Word, LaTeX with its preamble, Excel with the values as numbers, CSV,
Markdown), with or without {opt stars} on screen. Both work on replay:
{cmd:duvm, stars}. The tables are built by a private copy of the
{cmd:tabstars} command shipped with the package ({cmd:_duvm_tabstars.ado});
for other layouts (levels, symbols, labels, column groups) install the
{cmd:tabstars} package and call it on the {cmd:e()} matrices. The last row and
column of the completed tables are the composite of all other goods, named
{cmd:composite} in the matrices and in {cmd:e(b)}.

{pstd}
{ul:Cluster sizes.} The measurement-error correction divides the residual
variances of the first stage by the harmonic mean of the cluster sizes, eq.
(5.55). With weights the size of a cluster is its effective size,
(sum w)^2 / sum w^2, which is the number of households when the weight is
constant within the cluster.

{marker compat}{...}
{pstd}
{ul:compat.} The Stata code published with Deaton (1997, ch. 5; programs
{it:allindia.do} and {it:mkmats.do} on the World Bank LSMS site) departs from
the book's equations in three places: the quality parameter is computed as
{it:b1}/({it:b0} + 1 - {it:b1 wbar}) instead of eq. (5.92); the completed system
uses the reciprocal of zeta, obtained through {cmd:syminv(diag(b1))}, which also
drops the correction of any good with a negative {it:b1}; and the last row of
the completed Theta is +colsum instead of -colsum (eq. 5.94). It also follows
two conventions: the covariance of the first-stage residuals comes from an
auxiliary regression, and the region of a cluster is that of its first
household. {opt compat} reproduces the code, so that results computed with it can
be recovered: on unweighted data {cmd:duvm, compat} matches a line-by-line
transcription of Deaton's programs to 1e-9. The code is unweighted; with weights,
{opt compat} keeps its formulas and applies the weights as the default does.
The default follows the book. No analytic variance is available under
{opt compat}.

{pstd}
{opt compatflags(list)} reproduces only the departures listed, among {cmd:zeta},
{cmd:completion}, {cmd:sign}, {cmd:chi} and {cmd:region} ({opt compat} is all
five), which shows the effect of each. Two more flags reproduce the weighting of
the earlier WELCOM implementation: {cmd:counts} (the size of a cluster is the
sum of its weights) and {cmd:mean} (its cluster averages).

{pstd}
{ul:After estimation.} {cmd:estat diagnostics} reports, good by good, the
households and clusters behind the price signal, the share of the between-
cluster variance removed by the measurement-error correction, the sign of the
quality elasticity and the conditioning of the moment matrix, with warnings;
{helpb duvmdiag} runs the same report before estimating. {cmd:estat elasticities}
[{cmd:, unrestricted noquality uncompleted}] and {cmd:estat quality} redisplay
the tables. {cmd:predict} and {cmd:estat engel} give the Engel curves; see
{help duvm##engel:Engel curves}.


{marker engel}{...}
{title:Engel curves: predict and estat engel}

{p 8 16 2}
{cmd:predict} [{it:type}] {it:newvar} {ifin}{cmd:,} {c -(}{opt sh:are}|{opt qu:ality}|{opt qua:ntity}{c )-}
{opt go:od(name)} [{opt atm:eans}|{opt aso:bserved}] [{opt stdp} {opt norm:alize}]

{p 8 16 2}
{cmd:predict} [{it:type}] {it:stub}{cmd:*} {ifin}{cmd:,} {c -(}{opt sh:are}|{opt qu:ality}|{opt qua:ntity}{c )-}
[{opt atm:eans}|{opt aso:bserved}] [{opt stdp} {opt norm:alize}]

{p 8 16 2}
{cmd:estat engel} {ifin} [{cmd:,} {c -(}{opt sh:are}|{opt qu:ality}|{opt qua:ntity}{c )-}
{opt atm:eans}|{opt aso:bserved} {opt norm:alize} {opt lnx} {opt n(#)} {opt trim(#)} {opt l:evel(#)} {opt noci}
{opt bw:idth(#)} {opt data(filename)} {opt sav:ing(filename)} {opt nodraw} {it:graph_combine_options}]

{pstd}
The first stage of {cmd:duvm} regresses, within clusters, the budget share and
the log unit value of each good on the log of total expenditure {it:x} and the
other household variables. It therefore gives three Engel curves:

{p2colset 8 20 22 2}{...}
{p2col:{opt share}}the budget share {it:w}(ln {it:x}), slope {it:b0}; the Engel curve of the budget share{p_end}
{p2col:{opt quality}}the log unit value ln {it:v}(ln {it:x}), slope {it:b1}; how richer households buy dearer varieties{p_end}
{p2col:{opt quantity}}the log quantity ln {it:q} = ln {it:w} + ln {it:x} - ln {it:v}, slope 1 + {it:b0}/{it:w} - {it:b1}, the expenditure elasticity of quantity{p_end}
{p2colreset}{...}

{pstd}
{opt atmeans}, the default, evaluates the curve at the household's ln {it:x}, the
other regressors held at their weighted means (over the households that report
the good for {opt quality}) and prices at their common level: the Engel curve
itself, a straight line in ln {it:x} for the share and the unit value.
{opt asobserved} keeps the household's own regressors and the effect of its
cluster: the fitted value of the first stage. {opt good()} names the good; with
{it:stub}{cmd:*}, one variable is created per good, {it:stub}{it:good}.
{opt stdp} is the standard error of the Engel curve ({opt atmeans}), linearized
over the same design as the estimates (clusters, or the {cmd:svyset} design; after
{cmd:vce(bootstrap)} the linearization on the bootstrap design); the
covariances it uses are those of {cmd:e(V)}. It is not available after
{cmd:vce(none)}, nor, for the share and the quantity, after {cmd:csb(1)}, whose
share equations also hold the inverse Mills ratio.

{pstd}
{ul:Units of the quantity curve.} {it:q} = {it:w x} / {it:v} is the expenditure
of the household on the good divided by its unit value: the quantity bought by
the household (not per head), over the period of {opt expend()}, in the unit of
the unit value (kilograms when {cmd:luv}{it:g} is the log of a price per
kilogram). Two conditions: {opt expend()} must be the denominator of the budget
shares, otherwise the level is shifted by the ratio of the two; and when the unit
value of a group of items is an index (a Laspeyres index of the items, as in the
example data), {it:q} is a quantity index whose level has no physical unit. The
slope of the curve, the expenditure elasticity of quantity, does not depend on
units. {opt normalize} sets the log quantity to 0 at the mean of ln {it:x}: the
curve then reads as the percentage difference in quantity from the household at
mean expenditure, without units, and the goods can be compared; its standard
error is 0 at that point by construction.

{pstd}
The budget share is linear in ln {it:x} (the Working-Leser form of Deaton's
first stage), so at high or low expenditure it can leave the unit interval: where
the fitted share is not positive the log quantity is left missing, and a note
says how many values this concerns. The curves of {helpb easi}, polynomials in
real expenditure, can bend where these cannot.

{pstd}
{cmd:estat engel} draws the curve of every good, one panel per good, against the
percentiles of total expenditure (the layout of {cmd:easi}'s {cmd:estat engel}),
or against its log with {opt lnx}, with the confidence band of {opt stdp}.
{opt n()} sets the number of points of the grid, {opt trim()} the percent left
out at each tail (default 1). With {opt asobserved} the fitted values are
smoothed by a local linear regression of bandwidth {opt bwidth()} (default: the
rule of thumb of {helpb lpoly}), without a band. {opt data()} saves the plotted
curves; {opt nodraw} computes them without drawing. {cmd:estat engel} stores
{cmd:r(n)}, {cmd:r(curve)} and, with {opt asobserved}, {cmd:r(bwidth)}.

{phang2}{cmd:. predict w_corn, share good(corn)}{p_end}
{phang2}{cmd:. predict se_w_corn, share good(corn) stdp}{p_end}
{phang2}{cmd:. predict lnq_*, quantity}{p_end}
{phang2}{cmd:. estat engel}{p_end}
{phang2}{cmd:. estat engel, quality lnx}{p_end}
{phang2}{cmd:. predict lnq_corn, quantity good(corn) normalize}{p_end}
{phang2}{cmd:. estat engel, quantity normalize}{p_end}
{phang2}{cmd:. estat engel, quantity level(90) data(engel_q)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:duvm} stores the following in {cmd:e()}:

{synoptset 24 tabbed}{...}
{p2col 5 24 28 2: Scalars}{p_end}
{synopt:{cmd:e(N)}}number of households{p_end}
{synopt:{cmd:e(N_clust)}}number of clusters{p_end}
{synopt:{cmd:e(N_psu)}}number of PSUs (linearized variance){p_end}
{synopt:{cmd:e(N_reps)}}, {cmd:e(N_reps_ok)}}bootstrap replications, successful ones{p_end}
{synopt:{cmd:e(M)}}number of goods{p_end}
{synopt:{cmd:e(qother)}}quality elasticity of the composite good{p_end}

{p2col 5 24 28 2: Macros}{p_end}
{synopt:{cmd:e(cmd)}}{cmd:duvm}{p_end}
{synopt:{cmd:e(goods)}}the goods{p_end}
{synopt:{cmd:e(clustvar)}}cluster variable{p_end}
{synopt:{cmd:e(vce)}}{cmd:cluster}, {cmd:svy}, {cmd:bootstrap} or {cmd:none}{p_end}
{synopt:{cmd:e(symmetry)}}{cmd:approx} or {cmd:none}{p_end}
{synopt:{cmd:e(compat)}}{cmd:compat} when set{p_end}

{p2col 5 24 28 2: Matrices}{p_end}
{synopt:{cmd:e(b)}}every reported estimate: the five price-elasticity matrices row by row (equations {cmd:E_noqual}, {cmd:E_M}, {cmd:E_Msym}, {cmd:E_x}, {cmd:E_xsym}; names {it:quantity}{cmd:_p}{it:price}), the expenditure elasticities ({cmd:exp}), the quality elasticities ({cmd:qual}), the mean budget shares ({cmd:share}) and the quality parameters ({cmd:zeta}){p_end}
{synopt:{cmd:e(V)}}their variance{p_end}
{synopt:{cmd:e(elast_price)}}E, completed system, symmetry restricted (M+1 x M+1){p_end}
{synopt:{cmd:e(elast_price_ns)}}idem, unrestricted{p_end}
{synopt:{cmd:e(elast_price_M)}}, {cmd:e(elast_price_M_ns)}}the M x M systems{p_end}
{synopt:{cmd:e(elast_price_noqual)}}E without the quality correction{p_end}
{synopt:{cmd:e(se_elast_price)}}, {cmd:e(se_elast_price_ns)}, {cmd:e(se_elast_price_M)}, {cmd:e(se_elast_price_M_ns)}, {cmd:e(se_elast_price_noqual)}}standard errors of the five matrices{p_end}
{synopt:{cmd:e(elast_exp)}}, {cmd:e(elast_exp_x)}, {cmd:e(se_elast_exp)}}expenditure elasticities{p_end}
{synopt:{cmd:e(elast_qual)}}, {cmd:e(se_elast_qual)}}quality elasticities{p_end}
{synopt:{cmd:e(se_shares_mean)}}, {cmd:e(se_zeta)}}standard errors of the mean shares and of zeta{p_end}
{synopt:{cmd:e(elast_price_own_group)}}own-price elasticities by group ({opt hgroup()}){p_end}
{synopt:{cmd:e(shares_mean)}}, {cmd:e(b0)}, {cmd:e(b1)}, {cmd:e(zeta)}, {cmd:e(zeta_x)}}first-stage parameters{p_end}
{synopt:{cmd:e(beta0)}}, {cmd:e(beta1)}}all first-stage coefficients{p_end}
{synopt:{cmd:e(omega)}}, {cmd:e(sigma)}, {cmd:e(chi)}, {cmd:e(n0)}, {cmd:e(n1)}}residual moments and harmonic cluster sizes{p_end}
{synopt:{cmd:e(S)}}, {cmd:e(R)}, {cmd:e(Sf)}, {cmd:e(Rf)}}second-stage moments, raw and corrected{p_end}
{synopt:{cmd:e(B_ols)}}, {cmd:e(B)}, {cmd:e(B_sym)}}second-stage coefficients{p_end}
{synopt:{cmd:e(Psi)}}, {cmd:e(Theta)}, {cmd:e(Psi_x)}, {cmd:e(Theta_x)}}quality and share responses to prices{p_end}
{synopt:{cmd:e(G)}}, {cmd:e(V_eta)}}Jacobian and variance of the moments (linearized){p_end}
{synopt:{cmd:e(boot_b)}}the bootstrap replications{p_end}
{synopt:{cmd:e(elprice)}}, {cmd:e(elincome)}}the same as {cmd:e(elast_price_M)} and {cmd:e(elast_exp)}, under the names of the earlier WELCOM version{p_end}


{marker examples}{...}
{title:Examples}

{pstd}The cereal groups of the Mexican ENIGH 2014 (installed with the package){p_end}
{phang2}{cmd:. use mexico_2014_cereals}{p_end}
{phang2}{cmd:. duvm corn wheat rice other [aw=sweight], hhsize(hhsize) expend(hh_current_inc) cluster(psu) region(rururb) indcat(sex educ) indcon(age)}{p_end}
{phang2}{cmd:. estat diagnostics}{p_end}
{phang2}{cmd:. estat quality}{p_end}

{pstd}With the survey design{p_end}
{phang2}{cmd:. svyset psu [pw=sweight], strata(quintile)}{p_end}
{phang2}{cmd:. duvm corn wheat rice other, hhsize(hhsize) expend(hh_current_inc) cluster(psu) region(rururb) indcat(sex educ) indcon(age) vce(svy)}{p_end}

{pstd}Bootstrap of both stages, and by decile{p_end}
{phang2}{cmd:. duvm corn wheat rice other [aw=sweight], hhsize(hhsize) expend(hh_current_inc) cluster(psu) region(rururb) indcat(sex educ) indcon(age) vce(bootstrap, reps(500) seed(1))}{p_end}
{phang2}{cmd:. duvm corn wheat rice other [aw=sweight], hhsize(hhsize) expend(hh_current_inc) cluster(psu) region(rururb) indcat(sex educ) indcon(age) hgroup(decile)}{p_end}

{pstd}The tables with significance stars, on screen and in a Word file{p_end}
{phang2}{cmd:. duvm, stars}{p_end}
{phang2}{cmd:. duvm corn wheat rice other [aw=sweight], hhsize(hhsize) expend(hh_current_inc) cluster(psu) region(rururb) indcat(sex educ) indcon(age) saveres(duvm_results.docx)}{p_end}

{pstd}Before estimating a larger system{p_end}
{phang2}{cmd:. duvmdiag corn wheat rice other [aw=sweight], hhsize(hhsize) expend(hh_current_inc) cluster(psu) region(rururb) indcat(sex educ) indcon(age)}{p_end}


{marker references}{...}
{title:References}

{phang}Deaton, A. 1988. Quality, quantity, and spatial variation of price.
{it:American Economic Review} 78: 418-430.{p_end}

{phang}Deaton, A. 1990. Price elasticities from survey data: extensions and
Indonesian results. {it:Journal of Econometrics} 44: 281-309.{p_end}

{phang}Deaton, A. 1997. {it:The Analysis of Household Surveys: A Microeconometric
Approach to Development Policy}. Baltimore: Johns Hopkins University Press,
chapter 5.{p_end}


{title:Author}

{pstd}Abdelkrim Araar, Universit{c e'} Laval / PEP, aabd@ecn.ulaval.ca{p_end}
{pstd}Version 1.0.1. License: GPL-3.0-or-later.{p_end}
