* Table8_timing.do — Table 8: execution times (seconds) of the WELCOM version
* and of duvm 1.0, same data, same machine: estimation, ten groups, one
* bootstrap replication of both stages, one replication of the shortcut.
* The WELCOM version needs its own files on the adopath (tests/lock and the
* WELCOM installer); when they are absent its rows are left missing.
do _setup.do
use "$DATA", clear
* duvm 1.0
timer clear
timer on 1
qui duvm $GOODS [aw=sweight], $OPTS vce(none)
timer off 1
timer on 2
qui duvm $GOODS [aw=sweight], $OPTS vce(none) hgroup(decile)
timer off 2
timer on 3
qui duvm $GOODS [aw=sweight], $OPTS vce(bootstrap, reps(20) seed(1))
timer off 3
timer on 4
qui duvm $GOODS [aw=sweight], $OPTS vce(bootstrap, reps(20) seed(1) shortcut)
timer off 4
qui timer list
local d1 = r(t1)
local d2 = r(t2)
local d3 = r(t3) / 20
local d4 = r(t4) / 20

* WELCOM duvm (2017), if available (it drops every matrix, so the timings
* are kept in locals and the table is assembled afterwards)
local w1 .
local w2 .
local w4 .
capture confirm file "$ROOT/tests/lock/duvm_welcom.ado"
if _rc == 0 {
    adopath ++ "C:/Users/aabd/OneDrive/Desktop/EASI_project/Installer/files/main"
    capture which mk_xtab_tr
    if _rc == 0 {
        run "$ROOT/tests/lock/duvm_welcom.ado"
        cd out
        use "$DATA", clear
        timer clear
        timer on 1
        qui duvm corn wheat rice other, hhsize(hhsize) expend(hh_current_inc) cluster(psu) indcat(sex educ) indcon(age) region(rururb) hweight(sweight)
        timer off 1
        use "$DATA", clear
        timer on 2
        qui duvm corn wheat rice other, hhsize(hhsize) expend(hh_current_inc) cluster(psu) indcat(sex educ) indcon(age) region(rururb) hweight(sweight) hgroup(decile)
        timer off 2
        use "$DATA", clear
        timer on 4
        qui duvm corn wheat rice other, hhsize(hhsize) expend(hh_current_inc) cluster(psu) indcat(sex educ) indcon(age) region(rururb) hweight(sweight) boot(20)
        timer off 4
        qui timer list
        local w1 = r(t1)
        local w2 = r(t2)
        local w4 = (r(t4) - r(t1)) / 20
        foreach f in tempa tempclus bootall {
            capture erase `f'.dta
        }
        capture erase stata_out.xml
        cd ..
        program drop _all
        do _setup.do
    }
}
tempname T8
matrix `T8' = (`w1', `w2', ., `w4') \ (`d1', `d2', `d3', `d4')
matrix rownames `T8' = WELCOM_2017 duvm_1_0
matrix colnames `T8' = estimation ten_deciles boot_rep_both boot_rep_shortcut
wcsv table8_timing `T8'
matlist `T8'
