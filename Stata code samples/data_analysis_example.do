/* Sample data analysis Stata code
   Submitted by Junho Choi */
   
/* Setting my directory; should be changed appropriately */
cd "D:/"

/* I note that I use the command "precombine," which
   is downloadable by typing "search precombine" then clicking
   the package "dm0081" (and installing it from there) */

*******************************
** Cleaning deceased dataset **
*******************************

use "d.dta", clear

** binary variable for less than 28 days **
gen within_28days = 0
replace within_28days = 1 if (lived_unit <= 2)
replace within_28days = 1 if (lived_unit == 3 & lived < 28)
label var within_28days "=1 if lived less than 28 days"

** binary variable for less than 1 year **
gen within_year = 1
replace within_year = 0 if (lived >= 12 & lived_unit==4) | (lived_unit==5)
label var within_year "=1 if lived less than a year"

** per-household sum of children deceased **
egen hh_28days_n = sum(within_28days), by(id_household)
egen hh_year_n = sum(within_year), by(id_household)
bysort id_household: gen hh_deceased_n = _N

label var hh_28days_n "no. of deceased child. living less than 28 days in HH"
label var hh_year_n "no. of deceased child. living less than a year in HH"
label var hh_deceased_n "no. of deceased child. in the HH"

** saving the data, just in case **
save "d (binaries_calc).dta", replace

** keeping data for merging with household data **
keep id_household hh_28days_n hh_year_n hh_deceased_n
duplicates drop

** saving the household-level data
save "d (sum_of_deceased_HH).dta", replace


*******************************
** Cleaning children dataset **
*******************************

use c.dta, clear

** number of children in the household **
bysort id_household: gen n_child = _N
label var n_child "number of children in a household"

** approximate age **
gen approx_age = 2007 - year_birth
label var approx_age "Approximate age (2007 - birth year)"

egen avg_approx_age = sum(approx_age), by(id_household)
label var avg_approx_age "Average approximate age of children in the HH"

/* generating the ratio of individuals who should be in school
   yet not attending school */
gen should_attend_high = (approx_age <= 18 & activities != 2 & ///
                          approx_age >= 6)
gen should_attend_middle = (approx_age <= 14 & activities != 2 & ///
                            approx_age >= 6)
label var should_attend_high ///
   "Old enough to attend school (up to high school), but not attending"
label var should_attend_middle ///
   "Old enough to attend school (up to middle school), but not attending"
   
/* household-level of should-be-attending (ratio)*/
egen sh_attend_high_hh = sum(should_attend_high), by(id_household)
replace sh_attend_high_hh = sh_attend_high_hh / n_child

egen sh_attend_middle_hh = sum(should_attend_middle), by(id_household)
replace sh_attend_middle_hh = sh_attend_middle_hh / n_child

label var sh_attend_high_hh ///
   "Ratio of children old enough to attend up to high school, but not"
label var sh_attend_middle_hh ///
   "Ratio of children old enough to attend up to middle school, but not"

/* generating the ratio of individuals who never attended any form
   of education (despite being older than 5 years) */   
gen not_attended_ofage = (approx_age > 6 & highest_educ == 8) 
label var not_attended_ofage ///
   "Older than 5 y-o, but never attended school"

/* household-level of never attended school despite being older */
egen not_attended_ofage_hh = sum(not_attended_ofage), by(id_household)
replace not_attended_ofage_hh = not_attended_ofage_hh / n_child
label var not_attended_ofage_hh ///
   "Household ratio of children older than 5 but never attended school"   
   
** saving the data, just in case **
save "c (binaries_calc).dta", replace

** keeping variables for household-level data **
keep id_household n_child avg_approx_age sh_attend_* not_attended_ofage_hh

duplicates drop
save "c (sum_of_children_HH).dta", replace


**************************
** Merging the datasets **
**************************

** trying to merge first with deceased dataset **
use h.dta, clear
precombine "d (sum_of_deceased_HH).dta", current
destring id_household, replace // changing to long, for merging

merge 1:1 id_household using "d (sum_of_deceased_HH).dta"

** I fill the missing values for newly added vars **
local vars hh_28days_n hh_year_n hh_deceased_n
foreach v of varlist `vars' {
    replace `v' = 0 if `v'==.
}

** binary variables for households living less than 28 days / 1 year **
gen hh_28days_yesno = (hh_28days_n >= 1)
gen hh_year_yesno = (hh_year_n >= 1)

** binary variables for households with any child deaths **
gen hh_deceased_child_yesno = (hh_deceased_n >= 1)

** reoccurrence, if any **
gen hh_28days_reoccur = (hh_28days_n >= 2)
gen hh_year_reoccur = (hh_year_n >= 2)
gen hh_deceased_child_reoccur = (hh_deceased_n >= 2)

** saving, just in case **
save "h (with_deceased).dta", replace

** trying to merge with children dataset **
use "h (with_deceased).dta", clear
precombine "c (sum_of_children_HH).dta", current
ren _merge _merge_deceased

merge 1:1 id_household using "c (sum_of_children_HH).dta"

** Again, I fill the missing values for newly added vars **
local vars n_child sh_attend_* not_attended* avg_approx_age
foreach v of varlist `vars' {
    replace `v' = 0 if `v'==.
}

** children born, including those that passed away **
gen n_child_born = n_child + hh_deceased_n
label var n_child_born "total number of child born from this household"

** larger geographical unit **
gen geography = 1 // Geographical unit: Java
replace geography = 2 if province_id >= 70 // Sulawesi
replace geography = 3 if province_id >= 50 & province_id < 70 // Lesser Sunda
label define geo 1 "Java" 2 "Sulawesi" 3 "Lesser Sunda"
label val geography geo

** binary variable of no latrine **
gen no_latrine = (latrine == 6)
label var no_latrine "=1 if no accessible latrines available"

** number of non-children (adults) in the household **
gen hh_size_adults = hh_size - n_child
label var hh_size_adults "household size - number of children"

** "better water" being piped or water from pumped wells
gen better_water = (drinking_water <= 2)
label var better_water "=1 if drinking water sourced f/ pipes or pumped wells"

save "h (with_dec_and_chi).dta", replace


****************
** Subsetting **
****************

use "h (with_dec_and_chi).dta", clear

/* households with currently with children or
   those with them in the past will be used */
gen scope = (n_child >= 1 | hh_deceased_n >= 1)
drop if scope == 0

save "h (with_dec_and_chi) subset.dta", replace


**************
** Analysis **
**************

use "h (with_dec_and_chi) subsetted.dta", clear

** basic tabulations **

local vars hh_deceased_child_yesno hh_28days_yesno hh_year_yesno
local othervars latrine better_water insurance 
foreach case of varlist `othervars' {
	foreach v of varlist `vars' {
        tab `case' `v', r chi2
    }
}

** regression analyses **

/* note that hh_size_adults > 0 condition was used for some regressions
   as the number of adults were negative for 2 observations */   

** logistic regressions **
global basic_vars no_latrine better_water n_child_born
logit hh_28days_yesno $basic_vars, r
logit hh_year_yesno $basic_vars, r

global added_controls i.geography hh_size_adults new_members
logit hh_28days_yesno $basic_vars $added_controls if hh_size_adults>0, r
logit hh_year_yesno $basic_vars $added_controls if hh_size_adults>0, r

** linear regressions **
reg hh_28days_n $basic_vars, r
reg hh_year_n $basic_vars, r

local altered_added hh_size_adults new_members
areg hh_28days_n $basic_vars `altered_added' ///
     if hh_size_adults>0, ab(geography) cl(geography)
areg hh_year_n $basic_vars `altered_added' ///
     if hh_size_adults>0, ab(geography) cl(geography)
