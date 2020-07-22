/* Sample survival regression methods code
   in Stata, using kidney failure data
   Submitted by Junho Choi */

************************************
** Data cleansing and observation **
************************************   

use kidney03.dta, clear

// Before getting into the real question

summ

tab year, su(faildays)

sort year

egen kdied_mean = mean(kdied), by(year)
by year: gen counter = _n

twoway line kdied_mean year if counter == 1 ///
       , xtitle("") ytitle("") sort(year) ///
       xlabel(1987(2)1999)

areg faildays kdied rblack dblack rfemale ///
    dfemale rage dage, cluster(year) absorb(year)
outreg2 using areg.doc, replace

// set-up for streg
stset faildays, failure(kdied)
stsum

***********************
** Approach 1: Tobit **
***********************

streg rblack dblack rfemale dfemale rage dage i.year, cluster(year) ///
      distribution(lognormal) nolog
outreg2 using tobit.doc, replace

streg c.rblack##c.dblack c.rfemale##c.dfemale rage dage i.year, ///
      cluster(year) ///
      distribution(lognormal) nolog
outreg2 using tobit.doc, append
stcurve, survival saving(tobit01.gph,replace)
stcurve, hazard saving(tobit02.gph,replace)

streg c.rblack##c.dblack c.rfemale##c.dfemale rage dage, ///
      cluster(year) ///
      distribution(lognormal) nolog
outreg2 using tobit.doc, append

graph combine tobit01.gph tobit02.gph, title(Lognormal with regressors)

*************************
** Approach 2: Weibull **
*************************

streg rblack dblack rfemale dfemale rage dage i.year, cluster(year) ///
      distribution(weibull) nolog nohr
outreg2 using weibull.doc, replace

streg c.rblack##c.dblack c.rfemale##c.dfemale rage dage i.year, ///
      cluster(year) ///
      distribution(weibull) nolog nohr
outreg2 using weibull.doc, append
stcurve, survival saving(wei01.gph,replace)
stcurve, hazard saving(wei02.gph,replace)
graph combine wei01.gph wei02.gph, title(Weibull with regressors)

streg c.rblack##c.dblack c.rfemale##c.dfemale rage dage, ///
      cluster(year) ///
      distribution(weibull) nolog nohr
outreg2 using weibull.doc, append

******************************************
** Approach 3: discrete choice approach **
******************************************

/* I will follow the method of in-class log file */

use kiddur04.dta, replace
gen byte end = 0 
sort id
by id: replace end=1 if _n == _N & kdied == 1
label var end "=1 if kidney fails in the month"

recode month 13/24=13 25/36=14 37/72=15 73/108=16 109/144=17 145/.=18 ///
       , generate(moncat)

// LPM
reg end i.moncat rblack dblack rfemale dfemale rage dage i.year, cluster(id)
outreg2 using lpm.doc, replace

reg end i.moncat c.rblack##c.dblack c.rfemale##c.dfemale rage dage i.year ///
    , cluster(id)
predict yhat_lpm
egen yhat_lpm_avg = mean(yhat_lpm), by(month)
line yhat_lpm_avg month, ytitle("") title("LPM; hazard function") sort(month)
outreg2 using lpm.doc, append

reg end i.moncat c.rblack##c.dblack c.rfemale##c.dfemale rage dage ///
    , cluster(id)
outreg2 using lpm.doc, append

// Probit
probit end i.moncat rblack dblack rfemale dfemale rage dage i.year, ///
       cluster(id) nolog

outreg2 using probit.doc, replace

probit end i.moncat c.rblack##c.dblack c.rfemale##c.dfemale rage dage ///
       i.year, cluster(id)
outreg2 using probit.doc, append
predict yhat_probit
egen yhat_probit_avg = mean(yhat_probit), by(month)
line yhat_probit_avg month, ytitle("") ///
     title("Probit; hazard function") ///
     sort(month)
     
probit end i.moncat c.rblack##c.dblack c.rfemale##c.dfemale rage dage ///
    , cluster(id) nolog
outreg2 using probit.doc, append
