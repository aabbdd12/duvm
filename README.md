# Estimating Deaton's unit-value model: the duvm Stata module

`duvm` estimates the unit-value model of Deaton (1988, 1990, 1997 ch. 5):
own- and cross-price elasticities of quantity, expenditure elasticities and
quality elasticities for a group of goods, from the budget shares and the unit
values (expenditure / quantity) that households report, using the spatial
variation of prices across clusters. Closed-form, written in Mata.

* Deaton's two stages as the book states them: within-cluster regressions,
  between-cluster regressions of the purged cluster averages with the
  errors-in-variables correction (eq. 5.85), the quality parameter from weak
  separability (eq. 5.92), completion of the system with a composite good,
  approximate Slutsky symmetry;
* sampling weights (`aw`, `fw`, `pw`, `iw`) with the effective cluster sizes
  they imply;
* a linearized variance from the influence functions of every first- and
  second-stage moment, including the generated-regressor terms of the first
  stage, through the analytic Jacobian of the chain, clustered by price cluster
  (`vce(cluster)`, the default) or by survey design read from `svyset`
  (`vce(svy)`: PSUs, strata, finite-population correction);
* a design bootstrap of both stages (`vce(bootstrap)`), and Deaton's shortcut
  that resamples the second stage only (`shortcut`);
* `duvmdiag` / `estat diagnostics`: what will make the elasticities fragile,
  before estimating;
* results by group (`hgroup()`), a selection correction (`csb(1)`), `estat`,
  standard `e()` results, a dialog box (`db duvm`);
* `compat`, which reproduces the Stata code published with Deaton (1997)
  (checked against a line-by-line transcription of his programs), and
  `compatflags()` to switch its departures from the book one at a time.

Every variance is validated against the bootstrap under simple random sampling
of clusters, sampling weights and a stratified design; the technical note in
`paper/` gives the model, the estimator, the variance and the validation.

## Installation

```stata
net install duvm, from("https://raw.githubusercontent.com/aabbdd12/duvm/main") replace
net get duvm          // the example data and the guided tour
```

Stata 14.2 or later, nothing else: the `stars` and `saveres()` tables are
built by a private copy of the `tabstars` command
shipped with the package.

## Quick start

```stata
use Mexico_2014_Cereals, clear
duvmdiag corn wheat rice other [aw=sweight], hhsize(hhsize) expend(hh_current_inc) ///
    cluster(psu) region(rururb) indcat(sex educ) indcon(age)
duvm corn wheat rice other [aw=sweight], hhsize(hhsize) expend(hh_current_inc) ///
    cluster(psu) region(rururb) indcat(sex educ) indcon(age)
estat quality
duvm corn wheat rice other [aw=sweight], hhsize(hhsize) expend(hh_current_inc) ///
    cluster(psu) region(rururb) indcat(sex educ) indcon(age) stars saveres(duvm_results.docx)
svyset psu [pw=sweight], strata(quintile)
duvm corn wheat rice other, hhsize(hhsize) expend(hh_current_inc) cluster(psu) ///
    region(rururb) indcat(sex educ) indcon(age) vce(svy)
```

`help duvm` and `help duvmdiag` document every option and stored result;
`examples/duvm_tour.do` walks through the features.

## Layout

```
src/          duvm.ado, duvm.sthlp, duvm.dlg, duvm_estat.ado, duvmdiag.ado, duvmdiag.sthlp
examples/     Mexico_2014_Cereals.dta (four cereal groups of the ENIGH 2014),
              duvm_tour.do
paper/        the technical note (PDF)
replication/  one script per table of the note, master.do, make_tables.py
stata.toc, duvm.pkg    net-install manifest
```

## Citing

Araar, A. (2026). *Estimating Deaton's unit-value model: the duvm Stata
module*. https://github.com/aabbdd12/duvm (see `CITATION.cff`), and the model's
references:

Deaton, A. 1988. Quality, quantity, and spatial variation of price. *American
Economic Review* 78: 418-430.

Deaton, A. 1997. *The Analysis of Household Surveys: A Microeconometric Approach
to Development Policy*. Johns Hopkins University Press, chapter 5.

## License

GNU General Public License v3.0 or later (`LICENSE`).

## Author

Abdelkrim Araar, Université Laval / PEP — aabd@ecn.ulaval.ca
