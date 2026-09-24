* _setup.do — common preamble of the replication scripts (included by each).
* Run every script from the replication/ folder.
capture confirm file "master.do"
if _rc {
    di as err "run the replication scripts from DUVM_Project/replication"
    exit 601
}
local ROOT = subinstr("`c(pwd)'", "\", "/", .) + "/.."
global ROOT "`ROOT'"
global DATA "`ROOT'/examples/mexico_2014_cereals.dta"
global GOODS "corn wheat rice other"
global OPTS "hhsize(hhsize) expend(hh_current_inc) cluster(psu) indcat(sex educ) indcon(age) region(rururb)"
adopath ++ "`ROOT'/src"
capture mkdir out
set more off

* write a Stata matrix to out/<name>.csv with its row and column names
capture program drop wcsv
program define wcsv
    args name mat
    mata: _wcsv("out/`name'.csv", st_matrix("`mat'"), st_matrixrowstripe("`mat'"), st_matrixcolstripe("`mat'"))
end
capture mata: mata drop _wcsv()
mata:
void _wcsv(string scalar f, real matrix A, string matrix rs, string matrix cs)
{
    real scalar fh, i, j
    unlink(f)
    fh = fopen(f, "w")
    fput(fh, "," + invtokens(cs[., 2]', ","))
    for (i = 1; i <= rows(A); i++) {
        fwrite(fh, rs[i, 2])
        for (j = 1; j <= cols(A); j++) fwrite(fh, "," + strofreal(A[i, j], "%21.12g"))
        fput(fh, "")
    }
    fclose(fh)
}
end
