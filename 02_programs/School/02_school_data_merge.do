clear all

*set the paths
gl data_dir ${clone}/01_GEPD_raw_data/
gl processed_dir ${clone}/03_GEPD_processed_data/


*save some useful locals
local preamble_info_individual school_code 
local preamble_info_school school_code 
local not school_code
local not1 interview__id

***************
***************
* School File
***************
***************

********
*read in the raw school file
********
frame create school
frame change school

use "${data_dir}\\School\\EPDash.dta" 



* Fixes in school file:  teacher_ids:

replace m4saq1_number = 2  if school_code_preload == "27850"
replace m4saq1_number = 6  if school_code_preload == "12767"


replace m4saq1_number = 1 if school_code_preload  == "16711" & interview__id == "e7d4c404ad31475ab4b83e156ff4ab56"
replace m4saq1_number = 2 if school_code_preload  == "61915" & interview__id == "92185b79ca60414eaff13773789c6586"


********
*read in the school weights
********

frame create weights
frame change weights
import delimited "${data_dir}\\Sampling\\${weights_file_name}"

* rename school code
rename ${school_code_name} school_code
rename location urban_rural
gen strata = urban_rural + "-" + gender

keep school_code ${strata} ${other_info} strata_prob ipw

destring school_code, replace force
destring strata_prob, replace force
duplicates drop school_code, force

**# Bookmark #1



******
* Merge the weights
*******
frame change school

gen school_code = school_emis_preload
*fix missing cases
replace school_code = m1s0q2_emis if school_info_correct==0


destring school_code, replace force

drop if missing(school_code)

frlink m:1 school_code, frame(weights)
frget ${strata} ${other_info} urban_rural ipw strata_prob, from(weights)


*create weight variable that is standardized
gen school_weight=1/strata_prob // school level weight

*fourth grade student level weight
egen g4_stud_count = mean(m4scq4_inpt), by(school_code)


*create collapsed school file as a temp
frame copy school school_collapse_temp
frame change school_collapse_temp

order school_code
sort school_code

* collapse to school level
ds, has(type numeric)
local numvars "`r(varlist)'"
local numvars : list numvars - not

ds, has(type string)
local stringvars "`r(varlist)'"
local stringvars : list stringvars- not



collapse (max) `numvars' (firstnm) `stringvars', by(school_code)



***************
***************
* Teacher File
***************
***************

frame create teachers
frame change teachers
********
* Addtional Cleaning may be required here to link the various modules
* We are assuming the teacher level modules (Teacher roster, Questionnaire, Pedagogy, and Content Knowledge have already been linked here)
* See Merge_Teacher_Modules code folder for help in this task if needed
********

use "${data_dir}\\School\\PAK_KP_teacher_level_updated.dta" 

recode m2saq3 1=2 0=1

cap drop urban_rural
cap drop public
cap drop school_weight
foreach var in $other_info {
	cap drop `var'
}
cap drop $strata

frlink m:1 school_code, frame(school_collapse_temp)
frget school_code ${strata} $other_info urban_rural  school_weight numEligible numEligible4th, from(school_collapse_temp)

*get number of 4th grade teachers for weights
egen g4_teacher_count=sum(m3saq2_4), by(school_code)
egen g1_teacher_count=sum(m3saq2_1), by(school_code)

order school_code
sort school_code

*weights
*teacher absense weights
*get number of teachers checked for absense
egen teacher_abs_count=count(m2sbq6_efft), by(school_code)
gen teacher_abs_weight=numEligible/teacher_abs_count
replace teacher_abs_weight=1 if missing(teacher_abs_weight) //fix issues where no g1 teachers listed. Can happen in very small schools

/*
*teacher questionnaire weights
*get number of teachers checked for absense
egen teacher_quest_count=count(m3s0q1), by(school_code)
gen teacher_questionnaire_weight=numEligible4th/teacher_quest_count
replace teacher_questionnaire_weight=1 if missing(teacher_questionnaire_weight) //fix issues where no g1 teachers listed. Can happen in very small schools

*teacher content knowledge weights
*get number of teachers checked for absense
egen teacher_content_count=count(m3s0q1), by(school_code)
gen teacher_content_weight=numEligible4th/teacher_content_count
replace teacher_content_weight=1 if missing(teacher_content_weight) //fix issues where no g1 teachers listed. Can happen in very small schools

*teacher pedagogy weights
gen teacher_pedagogy_weight=numEligible4th/1 // one teacher selected
replace teacher_pedagogy_weight=1 if missing(teacher_pedagogy_weight) //fix issues where no g1 teachers listed. Can happen in very small schools

drop if missing(school_weight)
*/ 


*get number of teachers (at school) who completed the questionnaire
egen teacher_quest_count=count(m3s0q1) if m3s0q1 == 1, by(school_code) // participated in the questionnaire

*make sure we have this on on the school level
bysort school_code: egen max_teacher_quest_count = max(teacher_quest_count)
replace max_teacher_quest_count = 0 if max_teacher_quest_count == .
replace teacher_quest_count = max_teacher_quest_count

egen teacher_selected =count(m3s0q1), by(school_code) // selected for the questionnaire (in the ideal world this should be selected for both, but given the issues in CAR with the manual entry of the  questionnaire, we need to adjust this one for the assessment)

*recreate numEligible4th for the cases when it is empty
rename m2saq7_* m2saq7__*
rename m2saq8_97 m2saq8__97
egen eligible = rowmax(m2saq7__1 m2saq7__2 m2saq7__3 m2saq7__4 m2saq7__5 m2saq7__6 m2saq7__7)
replace eligible = 0 if m2saq8__97 == 1 
replace eligible = 0 if !inlist(teacher_available, 1, 90) & !missing(teacher_available)
replace eligible = 0  if m2saq6 == 2
replace eligible = 0 if m2saq5 == 4

replace eligible = 1 if eligible != 1 & !missing(m3s0q1)

bysort school_code: egen numEligible4th_manual = sum(eligible)

gen teacher_questionnaire_weight=(numEligible4th_manual/teacher_selected)*(teacher_selected/teacher_quest_count)

replace teacher_questionnaire_weight=1 if missing(teacher_questionnaire_weight) //fix issues where no g1 teachers listed. Can happen in very small schools


*teacher content knowledge weights
*recreate numEligible4th for the cases when it is empty (just do it once again given the adjustments that were made for the questionnaire)
drop eligible numEligible4th_manual

egen eligible = rowmax(m2saq7__1 m2saq7__2 m2saq7__3 m2saq7__4 m2saq7__5 m2saq7__6 m2saq7__7)
replace eligible = 0 if m2saq8__97 == 1 & eligible != 1
replace eligible = 0 if !inlist(teacher_available, 1, 90) & !missing(teacher_available)
replace eligible = 0  if m2saq6 == 2
replace eligible = 0 if m2saq5 == 4

replace eligible = 1 if eligible != 1 & typetest != . // to include the teachers that were never supposed to be assessed but were assessed regardless

bysort school_code: egen numEligible4th_manual = sum(eligible)

*since we do not have a consent variable, what we want to do here is to assume that the consent variable from the questionnaire applies to this one as well, excluding the cases where the teachers were not eligible but that submitted the questionnaire regardless
egen teacher_content_count=count(typetest), by(school_code) // participated in the test

bysort school_code: egen max_teacher_content_count = max(teacher_content_count)
replace max_teacher_content_count = 0 if max_teacher_content_count == .
replace teacher_content_count = max_teacher_content_count

*construct selected teachers 
*add the teachers that did not do the questionnaire but did the assessment
gen m3s0q1_modified = m3s0q1
replace m3s0q1_modified = 1 if typetest != . & missing(m3s0q1)

egen teacher_selected_content =count(m3s0q1_modified), by(school_code) // selected for the questionnaire 

gen teacher_content_weight=(numEligible4th_manual/teacher_selected_content)*(teacher_selected_content/teacher_content_count)

replace teacher_content_weight=1 if missing(teacher_content_weight) //fix issues where no g1 teachers listed. Can happen in very small schools

*teacher pedagogy weights
*reconstuct eligibility again. for the number of eligible teachers, I use the number of 4th grade teachers that teach either math of language (with some exceptions, see below). For now, part-time and volunteer teachers are a part of the calculation
drop eligible numEligible4th_manual

egen eligible = rowmax(m2saq7__4)

*exclude the teachers who are not available or not present during the absence check (unless they are observed for some unclear reason...)
replace eligible = 0 if (teacher_available == 2 & !missing(teacher_available)) | (m2sbq6_efft == 6 & !missing(m2sbq6_efft))

replace eligible = 1 if (teacher_available == 2 & s_0_1_1 != . & !missing(teacher_available)) | (m2sbq6_efft == 6 & s_0_1_1 != . & !missing(m2sbq6_efft))

*exclude the teachers that teach other subject only 
replace eligible = 0 if m2saq8__97 == 1 & subject_joined == ""

*some of the teachers teaching other subjects were observed, include them back in the eligible count
replace eligible = 1 if eligible == 0 & m2saq8__97 == 1 & subject_joined == "" & s_0_1_1 != .

*now move to the schools that had teachers NOT from grade 4 observed. for these schools, assume that ALL teachers teaching language and math are eligible, excluding principals who do not teach
gen flag = 1 if eligible == 0 & s_0_1_1 != .
bysort school_code: egen tagged_school = max(flag)

*remove the teachers teaching other subjects only (unless they were observed)
replace tagged_school = 0 if m2saq8__97 == 1 & subject_joined == "" & s_0_1_1 == . & tagged_school != .

*remove principals who do not teach and special needs/preschool only teachers 
replace tagged_school = 0 if m2saq7__n77 == 1 & tagged_school != .

*remove the teachers who teach 

egen other_grades = rowmax(m2saq7__1 m2saq7__2 m2saq7__3 m2saq7__4 m2saq7__5 m2saq7__6 m2saq7__7)
replace tagged_school = 0 if other_grades == 0 & (m2saq7__98 == 1 | m2saq7__99 == 1) & tagged_school != .
replace tagged_school = 0 if other_grades == . & tagged_school != .
drop other_grades

*finally, remove those not present at school,
replace tagged_school = 0 if ((teacher_available == 2 & !missing(teacher_available)) | (m2sbq6_efft == 6 & !missing(m2sbq6_efft))) & tagged_school != .

*get the final count for these "special schools"
bysort school_code: egen final_count = sum(tagged_school), miss

*get the final count for the regular schools
bysort school_code: egen numEligible4th_manual = sum(eligible)

*replace with the count for the special schools, wherever applicable
replace numEligible4th_manual = final_count if final_count != .

drop final_count tagged_school flag

*correct for the cases where the observed teacher is the one 
gen teacher_pedagogy_weight=numEligible4th_manual/1 // one teacher selected
replace teacher_pedagogy_weight=1 if missing(teacher_pedagogy_weight) //fix issues where no g1 teachers listed. Can happen in very small schools

drop if missing(school_weight)



********************************************************************************
save "${processed_dir}\\School\\Confidential\\Merged\\teachers.dta" , replace
********************************************************************************


********
* Add some useful info back onto school frame for weighting
********

*collapse to school level
frame copy teachers teachers_school
frame change teachers_school

collapse g1_teacher_count g4_teacher_count, by(school_code)

frame change school
frlink m:1 school_code, frame(teachers_school)

frget g1_teacher_count g4_teacher_count, from(teachers_school)



***************
***************
* 1st Grade File
***************
***************

frame create first_grade
frame change first_grade
use "${data_dir}\\School\\ecd_assessment.dta" 


frlink m:1 interview__key interview__id, frame(school)
frget school_code ${strata} $other_info urban_rural school_weight m6_class_count g1_teacher_count, from(school)


order school_code
sort school_code


*weights
gen g1_class_weight=g1_teacher_count/1, // weight is the number of 1st grade streams divided by number selected (1)
replace g1_class_weight=1 if g1_class_weight<1 //fix issues where no g1 teachers listed. Can happen in very small schools

bysort school_code: gen g1_assess_count=_N
gen g1_student_weight_temp=m6_class_count/g1_assess_count // 3 students selected from the class

gen g1_stud_weight=g1_class_weight*g1_student_weight_temp

save "${processed_dir}\\School\\Confidential\\Merged\\first_grade_assessment.dta" , replace

***************
***************
* 4th Grade File
***************
***************

frame create fourth_grade
frame change fourth_grade
use "${data_dir}\\School\\fourth_grade_assessment.dta" 


frlink m:1 interview__key interview__id, frame(school)
frget school_code ${strata}  $other_info urban_rural school_weight m4scq4_inpt g4_stud_count  g4_teacher_count, from(school)

order school_code
sort school_code

*weights
gen g4_class_weight=g4_teacher_count/1, // weight is the number of 4tg grade streams divided by number selected (1)
replace g4_class_weight=1 if g4_class_weight<1 //fix issues where no g4 teachers listed. Can happen in very small schools

bysort school_code: gen g4_assess_count=_N

gen g4_student_weight_temp=g4_stud_count/g4_assess_count // max of 25 students selected from the class

gen g4_stud_weight=g4_class_weight*g4_student_weight_temp

save "${processed_dir}\\School\\Confidential\\Merged\\fourth_grade_assessment.dta" , replace

***************
***************
* Collapse school data file to be unique at school_code level
***************
***************

frame change school

*******
* collapse to school level
*******

*drop some unneeded info
drop enumerators*

order school_code
sort school_code

********************************************************************************
* Comment_AR:

/*
* Adjust value label names that are too long 
la copy fillout_teacher_questionnaire fillout_teacher_q
la val fillout_teacher_questionnaire fillout_teacher_q
la drop fillout_teacher_questionnaire
clonevar fillout_teacher_q = fillout_teacher_questionnaire
la val fillout_teacher_q fillout_teacher_q
drop fillout_teacher_questionnaire

la copy fillout_teacher_content fillout_teacher_con
la val fillout_teacher_content fillout_teacher_con
la drop fillout_teacher_content
clonevar fillout_teacher_con = fillout_teacher_content
la val fillout_teacher_con fillout_teacher_con
drop fillout_teacher_content
*/

********************************************************************************



* collapse to school level
ds, has(type numeric)
local numvars "`r(varlist)'"
local numvars : list numvars - not

ds, has(type string)
local stringvars "`r(varlist)'"
local stringvars : list stringvars- not

* Store variable labels:

 foreach v of var * {
	local l`v' : variable label `v'
       if `"`l`v''"' == "" {
 	local l`v' "`v'"
 	}
 }
 
 
 
 * Store value labels: 
 
label dir 
return list

local list_of_valuelables = r(names)  // specify labels you want to keep
* local list_of_valuelables =  "m7saq7 m7saq10 teacher_obs_gender"


// save the label values in labels.do file to be executed after the collapse:


label save using "${clone}\02_programs\School\labels.do", replace

// note the names of the label values for each variable that has a label value attached to it: need the variable name - value label correspodence
   local list_of_vars_w_valuelables
 * foreach var of varlist m7saq10 teacher_obs_gender m7saq7 {
   
   foreach var of varlist * {
   
   local templocal : value label `var'
   if ("`templocal'" != "") {
      local varlabel_`var' : value label `var'
      di "`var': `varlabel_`var''"
      local list_of_vars_w_valuelables "`list_of_vars_w_valuelables' `var'"
   }
}
di "`list_of_vars_w_valuelables'"


********************************************************************************
*drop labels and then reattach
label drop _all
collapse (mean) `numvars' (firstnm) `stringvars', by(school_code)

********************************************************************************


* Redefine var labels:  
  foreach v of var * {
	label var `v' `"`l`v''"'
 }
 

// Run labels.do to redefine the label values in collapsed file
do "${clone}/02_programs/School/labels.do"
// reattach the label values
foreach var of local list_of_vars_w_valuelables {
   cap label values `var' `varlabel_`var''
}


* Firm confirmed this change:
isid school_code
list m6_teacher_code if school_code == 28463
replace m6_teacher_code = 4 if school_code == 28463



save "${processed_dir}\\School\\Confidential\\Merged\\school.dta" , replace
