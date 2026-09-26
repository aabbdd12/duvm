*! master.do — reproduce every table and figure of the technical note of duvm 1.1,
*! and the numbers of its Sections 3.4 (selection of the buyers) and 3.5 (which
*! elasticity: household, individual, market)
*!
*! Run from this directory:
*!     cd replication
*!     do master.do
*!
*! Data: ../examples/mexico_2014_cereals.dta; module: ../src. Everything
*! written goes to out/; python make_tables.py then writes the LaTeX tables
*! into ../paper/fig. README.md maps each script to its table.
*!
*! The two bootstrap scripts (Table5, Table6) run 400 replications each and
*! take about five minutes together; global BOOT 0 reduces them to 40.
*! Section3_4_selection runs 500 and 100 replications (50 and 40 with BOOT 0).
clear all
set more off
if "$BOOT" == "" global BOOT 1

local scripts Table1_2_data_quality Table3_4_elasticities Table7_deciles Table8_timing ///
    TableA1_corrections TableA2_compat_code Figure1_3_engel Table5_variance_validation Table6_shortcut ///
    Section3_4_selection Section3_5_elasticities

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
