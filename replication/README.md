# Replication of the technical note

Every table of *Estimating Deaton's unit-value model: the duvm Stata module*
is produced by one script of this folder, run from this folder:

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
reduces the two bootstrap scripts from 400 to 40 replications.

| script | table of the note |
|---|---|
| `Table1_2_data_quality.do` | Table 1 (the data behind each good), Table 2 (first-stage parameters, quality) |
| `Table3_4_elasticities.do` | Table 3 (price elasticities with linearized SE), Table 4 (the four treatments) |
| `Table5_variance_validation.do` | Table 5 (linearized against bootstrap SE: SRS, weights, survey design) |
| `Table6_shortcut.do` | Table 6 (bootstrap of both stages against Deaton's shortcut) |
| `Table7_deciles.do` | Table 7 (own-price elasticities by quintile; the decile run is kept in `out/table7_deciles10.csv`) |
| `Table8_timing.do` | Table 8 (execution times; the WELCOM rows need the WELCOM files, otherwise they stay missing) |
| `TableA1_corrections.do` | Table A1 (from the Stata code published with Deaton (1997) to the book, one correction at a time) |
| `TableA2_compat_code.do` | Table A2 (`duvm, compat` against `deaton_1997_ch5.do`, a line-by-line transcription of Deaton's programs) |
| `Figure1_3_engel.do` | Figures 1-3 (Engel curves of the budget share, the unit value and the quantity, drawn by `estat engel`; PDF files in `../paper/fig`) |
| `deaton_1997_ch5.do` | Deaton's `allindia.do` and `mkmats.do`, transcribed for the Mexican data (used by Table A2) |

`_setup.do` holds the common preamble (paths, the model, a CSV writer).
