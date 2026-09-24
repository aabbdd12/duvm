{smcl}
{* *! version 1.0.1  24sep2026}{...}
{vieweralsosee "duvm" "help duvm"}{...}
{title:Title}

{p2colset 5 17 19 2}{...}
{p2col:{cmd:duvmdiag} {hline 2}}Diagnostics of the unit-value model before estimating it{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 16 2}
{cmd:duvmdiag} {it:goods} {ifin} [{it:weight}]{cmd:,} {it:duvm_options} [{opt dec(#)}]

{pstd}
The syntax is that of {helpb duvm}; the variance options are ignored.


{title:Description}

{pstd}
{cmd:duvmdiag} runs the two stages of {helpb duvm} without the variance and
reports what will make the price elasticities fragile: goods reported by few
households or in few clusters, clusters too small for the measurement-error
correction, a correction that removes most of the between-cluster variance of
the unit value (little price signal left), negative quality elasticities,
expenditure elasticities near zero (unstable quality parameter), an
ill-conditioned or non-positive corrected moment matrix, and a symmetry
restriction that moves the second-stage coefficients a long way. The same
report is available after estimation with {cmd:estat diagnostics}.

{pstd}
It starts with the coding of the non-buyers (Table D0). A buyer is a household
whose budget share is positive; the table counts, good by good, the buyers, the
budget shares coded missing (read as 0, so that the household stays in the
model), the non-buyers that have a unit value in the data -- imputed, or coded 0
-- and the clusters that have a unit value but no buyer, whose price can only
come from outside the cluster. Each case is also reported as a warning, with
what {helpb duvm##options:nonbuyers()} does with it: imputed unit values bias
the quality elasticity toward zero, the more so the rarer the good.


{title:Stored results}

{synoptset 20 tabbed}{...}
{synopt:{cmd:r(N_warn)}}number of warnings{p_end}
{synopt:{cmd:r(cond_Sf)}}condition number of the corrected moment matrix{p_end}
{synopt:{cmd:r(mineig_Sf)}}its smallest eigenvalue{p_end}
{synopt:{cmd:r(sym_dist)}}||B_sym - B|| / ||B||{p_end}


{title:Example}

{phang2}{cmd:. use mexico_2014_cereals}{p_end}
{phang2}{cmd:. duvmdiag corn wheat rice other [aw=sweight], hhsize(hhsize) expend(hh_current_inc) cluster(psu) region(rururb) indcat(sex educ) indcon(age)}{p_end}


{title:Author}

{pstd}Abdelkrim Araar, Universit{c e'} Laval / PEP, aabd@ecn.ulaval.ca{p_end}
