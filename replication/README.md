# Replication of the technical note

Every table and figure of *Estimating Deaton's unit-value model: the duvm
Stata module*, and the numbers of its Sections 3.4 (selection of the buyers) and
3.5 (which elasticity), are
produced by the scripts of this folder, run from this folder:

```stata
cd replication
do master.do
```

then, to write the LaTeX tables into `../paper/fig`:

```
python make_tables.py
```

The data are `../examples/mexico_2014_cereals.dta`, the module `../src`. The
scripts write CSV files into `out/`. `global BOOT 0` before `do master.do`
reduces the bootstraps of Tables 5 and 6 from 400 to 40 replications, and those
of Section 3.4 from 500 and 100 to 50 and 40.

| script | table of the note (the numbers of the note; the script names keep the order in which they were written) |
|---|---|
| `Table1_2_data_quality.do` | Table 1 (the data behind each good), Table 2 (first-stage parameters, quality) |
| `Table3_4_elasticities.do` | Table 3 (price elasticities with linearized SE), Table 4 (the four treatments) |
| `Table5_variance_validation.do` | Table 7 (linearized against bootstrap SE: SRS, weights, survey design) |
| `Table6_shortcut.do` | Table 8 (bootstrap of both stages against Deaton's shortcut) |
| `Table7_deciles.do` | Table 5 (own-price elasticities by quintile; the decile run is kept in `out/table7_deciles10.csv`) |
| `Table8_timing.do` | Table 6 (execution times; the WELCOM rows need the WELCOM files, otherwise they stay missing) |
| `TableA1_corrections.do` | Table 9, appendix (from the Stata code published with Deaton (1997) to the book, one correction at a time) |
| `TableA2_compat_code.do` | Table 10, appendix (`duvm, compat` against `deaton_1997_ch5.do`, a line-by-line transcription of Deaton's programs) |
| `Figure1_3_engel.do` | Figures 1-3 (Engel curves of the budget share, the unit value and the quantity, drawn by `estat engel`; PDF files in `../paper/fig`) |
| `Section3_4_selection.do` | Section 3.4 (option `selection`): the oracle against `probit` and `areg`, the constructed case (quality elasticity with and without the correction; linearized against bootstrap SE, 500 replications), the Engel curves, and on the Mexican data Table D3, the quality elasticity with and without the correction and the bootstrap / linearized SE (100 replications); files `out/sec34_*.csv` |
| `Section3_5_elasticities.do` | Section 3.5 (option `elasticities()`): the own-price and expenditure elasticities, with linearized SE, and the budget shares at which they are evaluated, for the household, the individual and the market; file `out/sec35_types.csv` |
| `deaton_1997_ch5.do` | Deaton's `allindia.do` and `mkmats.do`, transcribed for the Mexican data (used by Table A2) |

`_setup.do` holds the common preamble (paths, the model, a CSV writer).
