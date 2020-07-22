/* Question 1 */

/* Setting directory */
cd "D:/All/Documents/UChicago/2018-19/BoothMetrics/PS3"

/* Question 1-(a) through 1-(d) */

clear
set matsize 10000

local N = 100
local T = 6 // Will change to 25 in 1-(e)
local NT = 600
set obs `NT'

/* Need to declare individual and time indicator */
gen indiv = .
forv i = 1/`N' {
    replace indiv = `i' if _n >= (`i'-1)*`T'+1 & _n <= `i'*`T'
    }
bysort indiv: gen time = _n

/* Declear panel data */
xtset indiv time

/* regression results (rho) saved here.
   each column: alternates between fixed effects estimate,
   HK estimate, and first-difference IV estimate (3)
   and we have three rhos, so 3x3 = 9 */
matrix rho_result = J(1000, 9, 0)

/* setting seed for replicability */
set seed 60637

local j = 1

/* Iteration, T=6 */

foreach rho in 0 0.5 0.95 {

    cap drop u
	cap drop a
	cap drop y

    forv i = 1/1000 {
	
        cap drop u
	    cap drop a
	    cap drop y

	    /* u_it */
	    gen u = rnormal(0, 1)

	    /* alpha_i */
	    gen a = rnormal(0, 1) if time == 1
	    replace a = l.a if time > 1
		
		/* y_it */
		gen y = . 
	    replace y = rnormal(a/(1-`rho'), 1/(1-`rho'^2)) if time == 1
	    replace y = `rho'*l.y + a + u if time > 1
		
		/* FE regression */
		quietly xtreg y l.y, fe
	    matrix rho_result[`i', `j'] = _b[L.y]
	
	    /* HK FE */
     	matrix rho_result[`i', `j'+1] = _b[L.y] + (1+_b[L.y])/`T'
	
	    /* FD IV */
		quietly ivregress 2sls d.y (dl.y=l2.y), noconst
        matrix rho_result[`i', `j'+2] = _b[LD.y]

	    }
		
        local j = `j'+3
		
    }
	
putexcel set "PS3_Q1_sim_t6.xlsx", sheet("sheet1") replace
putexcel A1=matrix(rho)

/* Question 1-(e) */
// same, except for T and NT.

clear
set matsize 10000

local N = 100
local T = 25
local NT = 2500
set obs `NT'

/* Need to declare individual and time indicator */
gen indiv = .
forv i = 1/`N' {
    replace indiv = `i' if _n >= (`i'-1)*`T'+1 & _n <= `i'*`T'
    }
bysort indiv: gen time = _n

/* Declear panel data */
xtset indiv time

/* regression results (rho) saved here.
   each column: alternates between fixed effects estimate,
   HK estimate, and first-difference IV estimate (3)
   and we have three rhos, so 3x3 = 9 */
matrix rho_result = J(1000, 9, 0)

/* setting seed for replicability */
set seed 60637

local j = 1

/* Iteration, T=6 */

foreach rho in 0 0.5 0.95 {

    cap drop u
	cap drop a
	cap drop y

    forv i = 1/1000 {
	
        cap drop u
	    cap drop a
	    cap drop y

	    /* u_it */
	    gen u = rnormal(0, 1)

	    /* alpha_i */
	    gen a = rnormal(0, 1) if time == 1
	    replace a = l.a if time > 1
		
		/* y_it */
		gen y = . 
	    replace y = rnormal(a/(1-`rho'), 1/(1-`rho'^2)) if time == 1
	    replace y = `rho'*l.y + a + u if time > 1
		
		/* FE regression */
		quietly xtreg y l.y, fe
	    matrix rho_result[`i', `j'] = _b[L.y]
	
	    /* HK FE */
     	matrix rho_result[`i', `j'+1] = _b[L.y] + (1+_b[L.y])/`T'
	
	    /* FD IV */
		quietly ivregress 2sls d.y (dl.y=l2.y), noconst
        matrix rho_result[`i', `j'+2] = _b[LD.y]

	    }
		
        local j = `j'+3
		
    }
	
putexcel set "PS3_Q1_sim_t25.xlsx", sheet("sheet1") replace
putexcel A1=matrix(rho_result)
