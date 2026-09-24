*! master.do — reproduce every table of the technical note of duvm 1.0
*!
*! Run from this directory:
*!     cd replication
*!     do master.do
*!
*! Data: ../examples/Mexico_2014_Cereals.dta; module: ../src. Everything
*! written goes to out/; python make_tables.py then writes the LaTeX tables
*! into ../paper/fig. README.md maps each script to its table.
*!
*! The two bootstrap scripts (Table5, Table6) run 400 replications each and
*! take about five minutes together; global BOOT 0 reduces them to 40.
clear all
set more off
if "$BOOT" == "" global BOOT 1

local scripts Table1_2_data_quality Table3_4_elasticities Table7_deciles Table8_timing ///
    TableA1_corrections TableA2_compat_code Table5_variance_validation Table6_shortcut

capture mkdir out
timer clear 9
timer on 9
foreach s of local scripts {
    di as txt _n "{hline 78}" _n "==> `s'" _n "{hline 78}"
    do `s'.do
}
timer off 9
timer list 9
di as res _n "master.do: all scripts ran.  Tables: python make_tables.py"
