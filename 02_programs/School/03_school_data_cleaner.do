*Clean data files for GEPD school indicators
*Written originally by Kanika Verma
*Updated by Brian Stacy on December 8, 2023.

clear all

*set the paths
gl data_dir ${clone}/01_GEPD_raw_data/
gl processed_dir ${clone}/03_GEPD_processed_data/


*save some useful locals
local preamble_info_individual school_code 
local preamble_info_school school_code 
local not school_code
local not1 interview__id

*Set working directory on your computer here
gl wrk_dir "${processed_dir}\\School\\Confidential\\Merged\\"
gl save_dir "${processed_dir}\\School\\Confidential\\Cleaned\\"

********************************************
* Create indicators and necessary variables
********************************************

************
*School data
************
cap frame create school
frame change school
*Load the school data
use "${wrk_dir}/school.dta"

************
*Teacher absence
************
cap frame create teachers
frame change teachers
*Load the teachers data
use "${wrk_dir}/teachers.dta"

cap drop school_absence_rate
cap drop sch_absence_rate 
cap drop absence_rate


************
*4th grade assessment
************
cap frame create fourth_grade_assessment
frame change fourth_grade_assessment
*Load the 4th fourth_grade_assessment assessment data
use "${wrk_dir}/fourth_grade_assessment.dta"


************
*ECD assessment
************
cap frame create first_grade_assessment
frame change first_grade_assessment
*Load the ecd data
use "${wrk_dir}/first_grade_assessment.dta"

set type double

*********************************************************
* Data is clean and ready to produce indicators
*********************************************************

*********************************************************
* Teacher Absence 
*********************************************************
* School survey. Percent of teachers absent. Teacher is coded absent if they are: 
* - not in school 
* - in school but absent from the class 
* - Loading teacher_absence dataset
frame change teachers

*Generate school absence variable
gen sch_absence_rate = 0 if (m2sbq6_efft!=6) & !missing(m2sbq6_efft)
replace sch_absence_rate = 1 if (m2sbq6_efft==6 | (teacher_available==2 & !inlist(m2sbq6_efft, 1, 2, 3, 4, 5))) & !missing(m2sbq6_efft)
replace sch_absence_rate = 100*sch_absence_rate
*generate absence variables
gen absence_rate = 0 if ((m2sbq6_efft==1 | m2sbq6_efft==3 | m2sbq6_efft==2 | m2sbq6_efft==4)) & !missing(m2sbq6_efft)
replace absence_rate = 100 if (m2sbq6_efft==6 | m2sbq6_efft==5 | (teacher_available==2 & !inlist(m2sbq6_efft, 1, 2, 3, 4))) & !missing(m2sbq6_efft)

*generate principal absence_rate
gen principal_absence = 0 if m2sbq3_efft!=8 & !missing(m2sbq3_efft)
replace principal_absence = 100 if m2sbq3_efft==8 & !missing(m2sbq3_efft)

*Fix absence rates, where in some cases the principal is the only one they could assess for absence (1 room schools type of situation?)
bysort school_code: egen count = count( m2sbq6_efft ) // number of teachers in the school where we actually collected this information
 
 replace absence_rate = principal_absence if count == 0 
 replace sch_absence_rate = principal_absence if count == 0
 
*Generating teacher presence rate- whether in school or classroom
gen presence_rate = 100-absence_rate

drop count

svyset school_code, strata($strata) singleunit(scaled) weight(school_weight)   || unique_teach_id, weight(teacher_abs_weight)
svy: mean absence_rate


********************************************************************************
* Comment_AR: Gender variable labels are messed up: Check why is this happening:

clonevar teacher_gender = m2saq3

replace teacher_gender = 0 if m2saq3 ==1
replace teacher_gender = 1 if m2saq3 ==2

fre teacher_gender
fre m2saq3

*Quick fix:
replace m2saq3 = teacher_gender

********************************************************************************
*males

svy: mean absence_rate if m2saq3==0

*females
svy: mean absence_rate if m2saq3==1


*********************************************
***** Student Attendance ***********
*********************************************
frame change school
*Percent of 4th grade students who are present during an unannounced visit.

gen student_attendance=m4scq4_inpt/m4scq12_inpt

assert (student_attendance >= 0 & student_attendance <= 1) | missing(student_attendance) // making sure this value is within expected boundaries (should always be the case (at least in new implementaations) since there is a validation condition for this in SS)

replace student_attendance=100*student_attendance


svyset school_code [pw=school_weight], strata($strata) singleunit(scaled) 
svy: mean student_attendance


*Girls attendance
 replace m4scq13_girls = . if m4scq13_girls == 98 // replace do not know as missing

 gen girls_num_attending = (m4scq4_inpt-m4scq4n_girls)
 gen girls_on_list = (m4scq12_inpt-m4scq13_girls)
 
 replace girls_on_list = (m4scq4_inpt-m4scq4n_girls) if (m4scq4_inpt-m4scq4n_girls) > (m4scq12_inpt-m4scq13_girls) & !missing(girls_num_attending) & !missing(girls_on_list)
 replace girls_num_attending = (m4scq12_inpt-m4scq13_girls) if (m4scq12_inpt-m4scq13_girls) < (m4scq4_inpt-m4scq4n_girls) & !missing(girls_num_attending) & !missing(girls_on_list)
 
 gen student_attendance_female = girls_num_attending/girls_on_list
 
 assert (student_attendance_female >= 0 & student_attendance_female <= 1) | missing(student_attendance_female) // making sure this is indeed correct
 
 replace student_attendance_female=100*student_attendance_female
 
*Boys attendance
 gen student_attendance_male = m4scq4n_girls/m4scq13_girls
 
replace student_attendance_male = m4scq13_girls/m4scq4n_girls if m4scq13_girls < m4scq4n_girls & !missing(m4scq13_girls) & !missing(m4scq4n_girls)
 
 assert (student_attendance_male >= 0 & student_attendance_male <= 1) | missing(student_attendance_male) // making sure this is indeed correct
 
 replace student_attendance_male=100*student_attendance_male
 
 
 svyset school_code [pw=school_weight], strata(strata) singleunit(scaled) 
 svy: mean student_attendance_male
 
 
**********************************************************
* Teacher Content Knowledge
**********************************************************
*School survey. Fraction correct on teacher assessment. In the future, we will align with SDG criteria for minimum proficiency.

frame change teachers

cap drop *content_knowledge 
cap drop *content_proficiency 

*recode assessment variables to be 1 if student got it correct and zero otherwise
de m5s1q* m5s2q* m5s1q* m5s2q*, varlist
*Replacing values is enumerators have entered values other than 01,00 and 99- eg:2. Also replacing "No response" code 99 to 0- this is treated as incorrect answer- No such values have been detected in the file currently, this can be removed to increase speed of code
foreach var in `r(varlist)' {
replace `var'=1 if `var'==2 & !missing(`var')
replace `var'=0 if `var'!=1 & !missing(`var')
}

*create indicator for % correct on teacher assessment

****Literacy****
*calculate # of literacy items correct
*Assessment consists of 4 parts- identifying correct letter, cloze, grammar and reading comprehension
*For whole assessment
egen literacy_content_knowledge=rowmean(m5s1q*)
*For separate parts of assessment- Correct the letter has been dropped
egen cloze=rowmean(m5s1q2*)
egen grammar=rowmean(m5s1q1*)
egen read_passage=rowmean(m5s1q4*)

****Math****
*calculate # of math items correct
*Assessment consists of 3 parts- arithmetic checks, geometry and data interpretation
*For whole assessment
egen math_content_knowledge=rowmean(m5s2q*)
*For separate parts of assessment
egen arithmetic_number_relations=rowmean(*_number)
egen geometry=rowmean(*_geometric)
egen interpret_data=rowmean(*_data)

*calculate % correct for literacy, math, and total
gen content_knowledge=(math_content_knowledge+literacy_content_knowledge)/2 if !missing(literacy_content_knowledge) & !missing(math_content_knowledge)
replace content_knowledge=math_content_knowledge if missing(literacy_content_knowledge)
replace content_knowledge=literacy_content_knowledge if missing(math_content_knowledge)
gen content_proficiency=(content_knowledge>=.80) if !missing(content_knowledge)
gen literacy_content_proficiency=(literacy_content_knowledge>=.80) if !missing(literacy_content_knowledge)
gen math_content_proficiency=(math_content_knowledge>=.80) if !missing(math_content_knowledge)

foreach var in content_proficiency content_knowledge literacy_content_knowledge literacy_content_proficiency math_content_proficiency cloze grammar read_passage math_content_knowledge arithmetic_number_relations geometry interpret_data {
	replace `var' = `var'*100
}

egen m5_teach_count = count(content_knowledge), by(school_code)
bysort school_code: egen m5_teach_count_math=count(math_content_knowledge) if typetest==1



svyset school_code, strata($strata) singleunit(scaled) weight(school_weight)   || unique_teach_id, weight(teacher_content_weight)
foreach var in content_proficiency  {
svy: mean `var'
}

*For male teachers
foreach var in content_proficiency  {
svy: mean `var' if m2saq3 == 0
}

*For female teachers
foreach var in content_proficiency  {
svy: mean `var' if m2saq3 == 1
}




********************************************************************************
* Comment_AR: Plug in TEACH code in the revamped WF. 
********************************************************************************

*KP:

* use "C:\Users\wb549384\WBG\HEDGE Files - GEPD-Confidential\General\Country_Data\GEPD_Production-Balochistan\01_GEPD_raw_data\School\Balochistan_teacher_level.dta", clear 

* Commment_AR: Adjust variable names in code for it run. 

/*
** grouping teach variables and storing them into globals 

gl low_medium_high s_0_1_2 s_0_2_2 s_0_3_2 s_a2_1 s_a2_2 s_a2_3 s_b3_1 s_b3_2 s_b3_3 s_b3_4 s_b5_1 s_b5_2 s_b6_1 ///
  s_b6_2 s_b6_3 s_c7_1 s_c7_2 s_c7_3 s_c8_1 s_c8_2 s_c8_3 s_c9_1 s_c9_2 s_c9_3
  
gl low_medium_high_na s_a1_1 s_a1_2 s_a1_3 s_a1_4a s_a1_4b s_b4_1 s_b4_2 s_b4_3  

gl yes_no s_0_1_1 s_0_2_1 s_0_3_1	

gl overall s_a1 s_a2 s_b3 s_b4 s_b5 s_b6 s_c7 s_c8 s_c9
*/


gl low_medium_high s_0_1_2 s_0_2_2 s_0_3_2 s_a2_1 s_a2_2 s_a2_3 s_b3_1 s_b3_2 s_b3_3 s_b3_4 s_b5_1 s_b5_2 s_b6_1 s_b6_2 s_b6_3 s_c7_1 s_c7_2 s_c7_3  s_c8_1 s_c8_2 s_c8_3 s_c9_1 s_c9_2 s_c9_3

  
gl low_medium_high_na s_a1_1 s_a1_2 s_a1_3 s_a1_4a s_a1_4b s_b4_2 s_b4_3


gl yes_no s_0_1_1 s_0_2_1 s_0_3_1

gl overall s_a1 s_a2 s_b3 s_b4 s_b5 s_b6 s_c7 s_c8 s_c9


** Verfying that the teach vars have observations
**# Bookmark #1

foreach var in $overall $yes_no $low_medium_high $low_medium_high_na {
sum `var'
}


** encoding the string responses into numeric -- Read below to understnad how the loop works 
	/*
	a- we define value lables to be used for encoding
	b- the loop first execute a test to confirm the varibales are coded as string:
		- if it is string (rc==0), the loop will execute and encode them into factor/numerical and labled vars
		- if it is numeric(rc==7), the loop will stop executing with an error -- already encoded into factor (do nothing more).

	*/

foreach var of global overall {
capture confirm string varibale `v'
if (_rc == 7) continue 
	*these aggregate vars must be numeric -- if they are, the loop would do nothing

	destring `var', replace
		tab `var'
}



/*

* Comment_AR: This part of the code is breaking: typemismatch

*  gl low_medium_high s1_0_1_2 s1_0_2_2 s1_0_3_2 s1_a2_1 s1_a2_2 s1_a2_3 s1_b3_1 s1_b3_2 s1_b3_3 s1_b3_4 s1_b5_1 s1_b5_2 s1_b6_1 s1_b6_2 s1_b6_3 s1_c7_1 s1_c7_2 s1_c7_3  s1_c8_1 s1_c8_2 s1_c8_3 s1_c9_1 s1_c9_2 s1_c9_3
 
 
label define low_medium_high_lbl 1 "NA" 2 "L" 3 "M" 4 "H"
foreach var of global low_medium_high_ar {
capture confirm string varibale `v'
if (_rc == 7) continue 
	tab `var', m
	
	replace `var'= upper(`var')							  //Making all upper
	replace `var'= subinstr(`var', " ", "", .)			  //Trimming spaces
	replace `var'= substr(`var' , 1, 1) if `var' !="NA"	  //for L,M,H; extract only first letters

	replace `var' ="1" if (`var'=="NA" | `var'=="")
	replace `var' ="2" if `var'=="L"
	replace `var' ="3" if `var'=="M"
	replace `var' ="4" if `var'=="H"

	destring `var', replace
		label val `var' low_medium_high_lbl
		
		tab `var'
}



foreach var of global low_medium_high_na {
capture confirm string varibale `v'
if (_rc == 7) continue 
	tab `var', m
	
	replace `var'= upper(`var')							  //Making all upper
	replace `var'= subinstr(`var', " ", "", .)			  //Trimming spaces
	replace `var'= substr(`var' , 1, 1) if `var' !="NA"	  //for L,M,H; we extract only first letters

	replace `var' ="1" if (`var'=="NA" | `var'=="")
	replace `var' ="2" if `var'=="L"
	replace `var' ="3" if `var'=="M"
	replace `var' ="4" if `var'=="H"

	destring `var', replace
		label val `var' low_medium_high_lbl
		
		tab `var'
}





label define yes_no_lbl 0 "N" 1 "Y"
foreach var of global yes_no {
capture confirm string varibale `v'
if (_rc == 7) continue 
	tab `var', m
	
	replace `var'= upper(`var')								//Making all upper
	replace `var'= subinstr(`var', " ", "", .)				//Trimming spaces
	replace `var'= substr(`var' , 1, 1) if `var' !="NA"	    //for Yes, No; we extract only first letters

	replace `var' =""  if `var'=="NA"
	replace `var' ="0" if `var'=="N"
	replace `var' ="1" if `var'=="Y"

	destring `var', replace
		label val `var' yes_no_lbl
		
		tab `var'
}

*/

** create sub-indicators from TEACH and calculating Teach score

*  a- first, create an average score var of the sub-componenets  
*  b- second, we creat an indicator varibale "counter", to know on how many of the sub componenets the
*		teacher scored above 3. -- these varibales will be used to calculate the proficiency scores. 

egen classroom_culture = rowmean(s_a1 s_a2)

	foreach var of varlist s_a1 s_a2 {
	
	gen     `var'_pro =.
	replace `var'_pro =1 if (`var' >=3 & `var'<=5)
	replace `var'_pro =0 if (`var' <3)
	
		tab `var'_pro
		}
		egen cc_counter= rowtotal(s_a1_pro s_a2_pro), m
			tab cc_counter
	
	
	
	
egen instruction = rowmean(s_b3 s_b4 s_b5 s_b6)
	foreach var of varlist s_b3 s_b4 s_b5 s_b6 {
	
	gen     `var'_pro =.
	replace `var'_pro =1 if (`var' >=3 & `var'<=5)
	replace `var'_pro =0 if (`var' <3)
	
		tab `var'_pro
		}
		egen i_counter= rowtotal(s_b3_pro s_b4_pro s_b5_pro s_b6_pro), m
			tab i_counter

egen socio_emotional_skills = rowmean(s_c7 s_c8 s_c9)
	foreach var of varlist s_c7 s_c8 s_c9 {
	
	gen     `var'_pro =.
	replace `var'_pro =1 if (`var' >=3 & `var'<=5)
	replace `var'_pro =0 if (`var' <3)
	
		tab `var'_pro
		}
		egen se_counter= rowtotal(s_c7_pro s_c8_pro s_c9_pro), m
			tab se_counter

			
			
egen teach_score=rowmean(classroom_culture instruction socio_emotional_skills)
	foreach var of varlist classroom_culture instruction socio_emotional_skills {
	
	gen     `var'_pro =.
	replace `var'_pro =1 if (`var' >=3 & `var'<=5)
	replace `var'_pro =0 if (`var' <3)
	
		tab `var'_pro
		}
		egen tch_counter= rowtotal(classroom_culture_pro instruction_pro socio_emotional_skills_pro), m
			tab tch_counter
		

** estimate teach proficiency: 
*			(100% if all teach score components>=3;) 
*					teacher scoring 3 or more on each of the subcomponents
*			(50% if at least one teach score compenents >=3;) if a teacher is proficient on 
*					at least one of the components and the overall teach_score is <3. 
*			(0% if all teach score components <3;) 
*					teacher scoring below 3 on all of the subcomponents



*-- First component proficiency (classroom culture)
gen classroom_culture_prof=.
	replace classroom_culture_prof=1*100    if (classroom_culture >=3 & classroom_culture<=5)
	replace classroom_culture_prof=0	    if (classroom_culture <3)
	replace classroom_culture_prof=0.5*100  if cc_counter==1

*-- Second component proficiency  (instruction)
gen instruction_prof=.
	replace instruction_prof=1*100  	  if (instruction >=3 & instruction<=5)
	replace instruction_prof=0	     	  if (instruction <3)
	replace instruction_prof=0.5*100      if (i_counter==2 | i_counter==3)

*-- Thired component proficiency (socio-emotional)
gen socio_emotional_skills_prof=.
	replace socio_emotional_skills_prof=1*100  	if (socio_emotional_skills >=3 & socio_emotional_skills<=5)
	replace socio_emotional_skills_prof=0	   	if (socio_emotional_skills <3)
	replace socio_emotional_skills_prof=0.5*100 if se_counter==2

*--Overall teach proficiency
gen teach_prof=. 
	replace teach_prof=1*100    if (teach_score >=3 & teach_score <=5)
	replace teach_prof=0	    if teach_score <3
	replace teach_prof=0.5*100  if tch_counter==2

	

drop s_a1_pro s_a2_pro s_b3_pro s_b4_pro s_b5_pro s_b6_pro ///
s_c7_pro s_c8_pro s_c9_pro classroom_culture_pro instruction_pro ///
socio_emotional_skills_pro cc_counter i_counter se_counter tch_counter

********************************************************************************

************
*4th grade assessment
************

*Proficiency in math > 82%
*Proficiency in literacy > 83.3%
*Overall proficiency >82.9%
*Scoring questions m8saq2 and m8saq3, in which students identify letters/words that enumerator calls out is tricky, because enumerators would not always follow instructions to say out loud the same letters/words. In order to account for this, will assume if 80% of the class has a the exact same response, then this is the letter/word called out. If there is a deviation from what 80% of the class says, then it is wrong.
frame change fourth_grade_assessment
de m8saq* m8sbq* m8saq* m8sbq*, varlist
*There are no incorrect values of variables- but just as a check, replacing any possible "No response" value of 99 with 0
foreach var in `r(varlist)' {
replace `var'=0 if `var'==99 & !missing(`var')
}
*create indicator for % correct on 4th grade assessment

* Define bin_var function
capture program drop bin_var
program define bin_var
    args varname correct_value
	gen score_temp = 0 if !missing(`varname')
    replace score_temp = 1 if `varname' == `correct_value'
	replace `varname' = score_temp
	drop score_temp
end

* Define call_out_scorer function
capture program drop call_out_scorer
program define call_out_scorer
    args varname threshold
    gen score_temp = 0 if !missing(`varname')
	egen score_med = median(`varname'), by(school_code)
    replace `varname' = (1-abs(`varname'-score_med) >= `threshold')
	drop score_temp
	drop score_med
end

* Recode assessment variables to be 1 if student got it correct and zero otherwise
qui de m8saq5* m8saq6* m8sbq2* m8sbq3* m8sbq4* m8sbq5* m8sbq6*, varlist
foreach var in `r(varlist)' {
    bin_var `"`var'"' 1
}

* Now handle the special cases
replace m8saq4_id = 4 if m8saq4_id == 5
bin_var m8saq7a_gir 3
bin_var m8saq7b_gir 3
bin_var m8saq7c_gir 2
bin_var m8saq7d_gir 3
bin_var m8saq7e_gir 4
bin_var m8saq7f_gir 1
bin_var m8saq7g_gir 2
bin_var m8saq7h_gir 2
bin_var m8saq7i_gir 4
bin_var m8saq7j_gir 1
bin_var m8saq7k_gir 3

* Grade lonely giraffe question
* This part is not clear in Stata, as Stata does not have a group_by equivalent

*grade circling questions
tempfile complete
save `complete'

foreach v in m8saq2_id m8saq3_id m8sbq1_number_sense {
	
	*number of letters/words/numbers circled by each student
	egen number_`v' = rowtotal(`v'__1 `v'__2 `v'__3 `v'__4 `v'__5 `v'__6 `v'__7 `v'__8 `v'__9)

	*address the cases of no response to make sure that those marked as no response is marked as 0 if we have 1 in other options
	forvalues i = 1/9 {
		replace `v'__99 = 0 if `v'__`i' == 1
	}
}

*also generate a dummy if the letters from the manual were circled
*h, F, v letters (3, 4, 6), respect (2), 4, 23, 55 numbers (1, 3, 4). Note that other provinces in PAK only seemed to have one word but here we also see three words? For the schools where most students only circled one word, I am assuming only one word was called out, for the others, I am assuming three words
gen number_m8saq2_id_cor = 1 if m8saq2_id__3 == 1 & m8saq2_id__4 == 1 & m8saq2_id__6 == 1 & number_m8saq2_id == 3
gen number_m8saq3_id_cor = 1 if (m8saq3_id__2 == 1 & number_m8saq3_id == 1) 
gen number_m8sbq1_number_sense_cor = 1 if m8sbq1_number_sense__1 == 1 & m8sbq1_number_sense__3 == 1 & m8sbq1_number_sense__4 == 1 & number_m8sbq1_number_sense == 3


*do the following check: (i) if the number of correct (according to the manual) is >= 50% OR if the number of students circling three letters is 50%, then do not drop this question from grading. 
foreach v in m8saq2_id m8saq3_id m8sbq1_number_sense {
	replace number_`v'_cor = 0 if number_`v'_cor != 1 & number_`v' != . 
	
	*now check the mean for each of them 
	sum number_`v'_cor
	local mean_`v' = `r(mean)'
}

		preserve
			keep school_code fourth_grade_assessment__id m8saq2_id* m8saq3_id* m8sbq1_number_sense* number_*
			
			*gen share of responses for each of the letters/words/numbers
			foreach v in m8saq2_id m8saq3_id m8sbq1_number_sense {
				forvalues i = 1/9 {
					bysort school_code: egen count_`v'_`i' = count(`v'__`i')
					bysort school_code: egen total_`v'_`i' = sum(`v'__`i')
					gen share_`v'_`i' = total_`v'_`i' / count_`v'_`i'
					
					drop total_`v'_`i' count_`v'_`i'
				}
			}
				
				tempfile student
				save `student'
				
		restore
				
                *move to a school level 
				preserve 
					use `student', clear
					keep school_code share_m8saq2_id_* share_m8saq3_id_* share_m8sbq1_number_sense_*
					
					duplicates drop
					
					reshape long share_m8saq2_id_ share_m8saq3_id_ share_m8sbq1_number_sense_, i(school_code)
					
					rename share_m8saq2_id_ share_letter
					rename share_m8saq3_id_ share_word
					rename share_m8sbq1_number_sense_ share_number
					
					gen share_word2 = share_word
					
					*mark all above 80% in two separare categories -- the first category is the one for the letters/words/numbers that correspond to the manual and the second one is for those that do not.  (*h, F, v letters (3, 4, 6), respect, greet and fruit words (2, 6, 7), 4, 23, 55 numbers (1, 3, 4))
					gen letter_manual = 1 if share_letter >= 0.8 & inlist(_j, 3, 4, 6)
					gen letter_not_manual = 1 if share_letter >= 0.8 & !inlist(_j, 3, 4, 6)
					gen word_manual = 1 if share_word >= 0.8 & inlist(_j, 2, 6, 7)
					gen word_not_manual = 1 if share_word >= 0.8 & !inlist(_j, 2, 6, 7)
					
					gen word_manual2 = 1 if share_word >= 0.8 & inlist(_j, 2)
					gen word2_not_manual = 1 if share_word >= 0.8 & !inlist(_j, 2)
					
					gen number_manual = 1 if share_number >= 0.8 & inlist(_j, 1, 3, 4)
					gen number_not_manual = 1 if share_number >= 0.8 & !inlist(_j, 1, 3, 4)
					
					*also get the total number of letters/words/numbers with more than 0.8% circles
					foreach v in letter word number {
						bysort school_code: egen above80_`v' = count(share_`v') if share_`v' >= 0.8
						bysort school_code: egen count_above80_`v' = max(above80_`v')
						drop above80_`v'
					}
					
					*SOLUTION 1: the schools where the count of above 80 is 3 and the number of letters from the manual is three are the perfect case, tag those. In PAK, words should be == 1
					foreach v in letter number word {
						bysort school_code: egen total_`v'_manual = sum(`v'_manual)
						
						gen perfect_match_`v' = 1 if total_`v'_manual == 3 & count_above80_`v' == 3
					}
					
					bysort school_code: egen total_word_manual2 = sum(word_manual2)
					gen perfect_match_word2 = 1 if total_word_manual2 == 1 & count_above80_word == 1
					
					*now get the top 3 shares for each school, just to see if in the cases of 1 and 2 letters, one of the letters from the manual is the second and the third in the rank 
					*for letters words and numbers, create a dummy variable for sorting that will help in case of ties
					gen letter = 1 if inlist(_j, 3, 4, 6)
					gen word2 = 1 if inlist(_j, 2)
					gen word = 1 if inlist(_j, 2, 6, 7)
					gen number = 1 if inlist(_j, 1, 3, 4)
					
					foreach v in letter word number {
						gsort school_code -share_`v'  `v'
						bysort school_code: gen rank_`v' = _n
					}
					
					gsort school_code -share_word word2
					bysort school_code: gen rank_word2 = _n
					
					*for each school, gen the list of the three most circled ones. Just one for the word
					foreach v in letter number word {
						forvalues i = 1/9 {
							gen `v'_top_`i' = 1 if _j == `i' & inlist(rank_`v', 1, 2, 3) & share_`v' != 0
						}
					}
					
					forvalues i = 1/9 {
						gen word2_top_`i' = 1 if _j == `i' & inlist(rank_word2, 1) & share_word2 != 0
					}
				
					*something that we will use in the future is the tag of complicated schools, get them here
					foreach v in letter word number word2 {
						bysort school_code: egen school_`v'_complicated = max(`v'_not_manual)
					}										
					
					keep school_code rank* _j count_above* *complicated* *top* *manual* share* perfect_match*
			
					*reshape to long
					reshape long letter_top_ word_top_ number_top_ word2_top_, i(school_code _j) j(j_new)
					drop if _j != j_new
					
					*SOLUTION 2: the schools where the count of above 80 is below 3 or == 3 but the letters from the manual are among the first ranked ones (should we have any threshold here?)  (*h, F, v letters (3, 4, 6), respect (2), 4, 23, 55 numbers (1, 3, 4))
					gen top_letter_manual_match = 1 if (_j == 3 & letter_top_ == 1) | (_j == 4 & letter_top_ == 1) | (_j == 6 & letter_top_ == 1) 
					gen top_word_manual_match = 1 if (_j == 2 & word_top_ == 1) | (_j == 6 & word_top_ == 1) | (_j == 7 & word_top_ == 1) 
					gen top_word2_manual_match = 1 if (_j == 2 & word2_top_ == 1) 
					gen top_number_manual_match = 1 if (_j == 1 & number_top_ == 1) | (_j == 3 & number_top_ == 1) | (_j == 4 & number_top_ ==1)
					
					foreach v in letter number word {
						bysort school_code: egen ttl_top_`v'_manual_match = sum(top_`v'_manual_match)
						gen second_match_`v' = 1 if (count_above80_`v' <= 3 | count_above80_`v' == .)  & ttl_top_`v'_manual_match == 3 & perfect_match_`v' != 1
					}
					
					bysort school_code: egen ttl_top_word2_manual_match = sum(top_word2_manual_match)
					gen second_match_word2 = 1 if (count_above80_word == .) & ttl_top_word2_manual_match == 1 & perfect_match_word != 1
					
					
					*SOLUTION 3:
					*schools with letters/words/numbers that have more than 80% but at least one letter is not on the manual
					foreach v in letter word number word2 {
						forvalues i = 1/9 {
							gen `v'_compl_list_`i' = `i' if _j == `i' & share_`v' >= 0.8 & school_`v'_complicated == 1
							
							bysort school_code: egen `v'_complicated_list_`i' = max( `v'_compl_list_`i')
						}
						
						*create the count of the letters from the list to tag the schools that have less than 3
						egen `v'_complicated_list_ttl = rownonmiss(`v'_complicated_list_*)
						
						*for schools that do only have 1 or two letters on the list, go with the ranking for now 
					if "`v'" != "word2" {
						forvalues i = 1/9 {
							drop `v'_complicated_list_`i'
							replace `v'_compl_list_`i' = `i' if  _j == `i' & rank_`v' == 2 & `v'_complicated_list_ttl == 1
							replace `v'_compl_list_`i' = `i' if  _j == `i' & rank_`v' == 3 & (`v'_complicated_list_ttl == 1 | `v'_complicated_list_ttl == 2)
							bysort school_code: egen `v'_complicated_list_`i' = max( `v'_compl_list_`i')
						}
					}
						
						*get a list of the letters that were called out
						gen `v'_complicated_list = ""
						
						forvalues i = 1/9 {
							replace `v'_complicated_list = `v'_complicated_list + "`i', " if `v'_complicated_list_`i' != .
							drop `v'_complicated_list_`i' `v'_compl_list_`i'
						}
					}
					
					*for words, depending on the context, decide which one we are keeping
					replace word_complicated_list = word2_complicated_list if count_above80_word < 3 & !missing(count_above80_word)
					replace school_word_complicated = school_word2_complicated if school_word2_complicated == 1 & school_word_complicated == .
					
					*in cases with all circled letters/words/numbers, set those to missing
					foreach v of varlist *_complicated_list {
						replace `v' = "" if `v' == "1, 2, 3, 4, 5, 6, 7, 8, 9, "
					} 
					
					keep school_code perfect_match_* second_match_* *_complicated_list school_*_complicated
					
					duplicates drop 
					tempfile school
					save `school'
				restore
				
				*now apply this school level information to the student level data
				use `student', clear
				
				merge m:1 school_code using `school', nogen
				
				*SCORE!!! when we have a perfect match or a second perfect match, then assign 
				
				*go with the schools with perfect matches and second matches (first for letters)
				*score the ones from the manual
				foreach v in 3 4 6 {
					gen score_letter_`v' = 1 if m8saq2_id__`v' == 1 & (perfect_match_letter == 1 | second_match_letter == 1)
					replace score_letter_`v' = 0 if  m8saq2_id__`v' == 0 & (perfect_match_letter == 1 | second_match_letter == 1)
				}
				
				*then the ones that are not on the manual 
				foreach v in 1 2 5 7 8 9 {
					gen score_letter_`v' = 1 if m8saq2_id__`v' == 0 & (perfect_match_letter == 1 | second_match_letter == 1)
					replace score_letter_`v' = 0 if m8saq2_id__`v' == 1 & (perfect_match_letter == 1 | second_match_letter == 1)
				}
				
				*now do the same for words 
				* first do it for the schools where only one word seemed to be called out (RESPECT only for PAK)
				*score the ones from the manual
				foreach v in 2  {
					gen score_word_`v' = 1 if m8saq3_id__`v' == 1 & (perfect_match_word2 == 1 | second_match_word2 == 1)
					replace score_word_`v' = 0 if  m8saq3_id__`v' == 0 & (perfect_match_word2 == 1 | second_match_word2 == 1)
				}
				
				*then the ones that are not on the manual 
				foreach v in 1 3 4 5 6 7 8 9 {
					gen score_word_`v' = 1 if m8saq3_id__`v' == 0 & (perfect_match_word2 == 1 | second_match_word2 == 1)
					replace score_word_`v' = 0 if m8saq3_id__`v' == 1 & (perfect_match_word2 == 1 | second_match_word2 == 1)
				}
				
				*now do the same thing in case of three words (2, 6, 7)
				foreach v in 2 6 7 {
					replace score_word_`v' = 1 if m8saq3_id__`v' == 1 & (perfect_match_word == 1 | second_match_word == 1)
					replace score_word_`v' = 0 if  m8saq3_id__`v' == 0 & (perfect_match_word == 1 | second_match_word == 1)
				}
				
				
				*then the ones that are not on the manual 
				foreach v in 1 3 4 5 8 9 {
					replace score_word_`v' = 1 if m8saq3_id__`v' == 0 & (perfect_match_word == 1 | second_match_word == 1)
					replace score_word_`v' = 0 if m8saq3_id__`v' == 1 & (perfect_match_word == 1 | second_match_word == 1)
				}
				
				*same thing for the numbers 
				foreach v in 1 3 4 {
					gen score_number_`v' = 1 if m8sbq1_number_sense__`v' == 1 & (perfect_match_number == 1 | second_match_number == 1)
					replace score_number_`v' = 0 if  m8sbq1_number_sense__`v' == 0 & (perfect_match_number == 1 | second_match_number == 1)
				}
				
				*then the ones that are not on the manual 
				foreach v in 2 5 6 7 8 9 {
					gen score_number_`v' = 1 if m8sbq1_number_sense__`v' == 0 & (perfect_match_number == 1 | second_match_number == 1)
					replace score_number_`v' = 0 if m8sbq1_number_sense__`v' == 1 & (perfect_match_number == 1 | second_match_number == 1)
				}
				
				foreach v in m8saq2_id m8saq3_id m8sbq1_number_sense {
					if "`v'" == "m8saq2_id" {
						local type letter
					}
					if "`v'" == "m8saq3_id" {
						local type word
					}
					if "`v'" == "m8sbq1_number_sense" {
						local type number
					}
					
					*for the complicated cases, for each student compare student responses with a variable with the school level answers
					forvalues i = 1/9 {
						*the ones matching with the list
						replace score_`type'_`i' = 1 if `v'__`i' == 1 & regexm(`type'_complicated_list, "`i'") & school_`type'_complicated == 1
						replace score_`type'_`i' = 1 if `v'__`i' == 0 & !regexm(`type'_complicated_list, "`i'")  &  school_`type'_complicated == 1
						*the ones not matching with the list 
						replace score_`type'_`i' = 0 if `v'__`i' == 0 & regexm(`type'_complicated_list, "`i'")  &  school_`type'_complicated == 1
						replace score_`type'_`i' = 0 if `v'__`i' == 1 & !regexm(`type'_complicated_list, "`i'")  &  school_`type'_complicated == 1
					}
					
					*now get the final scoring
					gen score_`type'_final = 0 if `v'__99 == 1 // if no response is given 
					
					egen score_`type'_total = rowtotal(score_`type'_1 score_`type'_2 score_`type'_3 score_`type'_4 score_`type'_5 score_`type'_6 score_`type'_7 score_`type'_8 score_`type'_9), missing
					
					replace score_`type'_final = (score_`type'_total-6)/3 if score_`type'_final == .
					
					*finally, replace those below 0 as 0 
					replace score_`type'_final = 0 if score_`type'_final < 0 & !missing(score_`type'_final)
					
				}
				
				rename score_letter_final m8saq2_id 
				rename score_word_final m8saq3_id 
				rename score_number_final m8sbq1_number_sense
					
				keep school_code fourth_grade_assessment__id m8saq2_id m8saq3_id m8sbq1_number_sense
				
				tempfile scored
				save `scored'
	
use `complete', clear
merge 1:1 school_code fourth_grade_assessment__id using `scored'
/*
* Call out scorer
qui ds m8saq2_id* m8saq3_id* m8sbq1_number_sense*
foreach var in `r(varlist)' {
    call_out_scorer `"`var'"' 0.8
}

* Subtract some letters not assessed and make out of 3 points
egen m8saq2_id = rowtotal(m8saq2_id*) , missing
replace m8saq2_id = (m8saq2_id - 7) / 3
egen m8saq3_id = rowtotal(m8saq3_id*) , missing
replace m8saq3_id = (m8saq3_id - 7) / 3

* More recoding
replace m8saq2_id = 0 if m8saq2_id < 0
replace m8saq3_id = 0 if m8saq3_id < 0

* Recode m8saq2_id and m8saq3_id to be 1 if greater than 1, otherwise keep the same
replace m8saq2_id = 1 if m8saq2_id > 1
replace m8saq3_id = 1 if m8saq3_id > 1
*/

* Recode m8saq4_id to be itself divided by 4 if not equal to 99, otherwise 0
replace m8saq4_id = m8saq4_id / 4 if m8saq4_id != 99
replace m8saq4_id = 0 if m8saq4_id == 99

* Recode m8saq7_word_choice using bin_var function
bin_var m8saq7_word_choice 2

/*
* Recode m8sbq1_number_sense to be itself minus 7 divided by 3
egen m8sbq1_number_sense = rowtotal(m8sbq1_number_sense*) , missing
replace m8sbq1_number_sense = (m8sbq1_number_sense - 7) / 3

* Recode m8sbq1_number_sense to be 0 if less than 0, otherwise keep the same
replace m8sbq1_number_sense = 0 if m8sbq1_number_sense < 0

* Recode m8sbq1_number_sense to be 1 if greater than 1, otherwise keep the same
replace m8sbq1_number_sense = 1 if m8sbq1_number_sense > 1
*/
* Drop variables starting with "m8saq2_id__", "m8saq3_id__", "m8sbq1_number_sense__"
ds m8saq2_id__* m8saq3_id__* m8sbq1_number_sense__*
drop `r(varlist)'

****Literacy****
*calculate # of literacy items correct
egen literacy_student_knowledge=rowmean(m8saq*)
replace literacy_student_knowledge = 100*literacy_student_knowledge
****Math****
*calculate # of math items correct
egen math_student_knowledge=rowmean(m8sbq*)
replace math_student_knowledge = 100*math_student_knowledge

*calculate % correct for literacy, math, and total
gen student_knowledge=(math_student_knowledge+literacy_student_knowledge)/2
gen student_proficient=100*(student_knowledge>=82.9) if !missing(student_knowledge)
gen literacy_student_proficient= 100*(literacy_student_knowledge>=83.3) if !missing(literacy_student_knowledge)
gen math_student_proficient= 100*(math_student_knowledge>=82) if !missing(math_student_knowledge)


svyset school_code, strata($strata) singleunit(scaled) weight(school_weight)   || fourth_grade_assessment__id, weight(g4_stud_weight)
foreach var in student_knowledge student_proficient {
svy: mean `var'
}
*For male students
foreach var in student_knowledge student_proficient {
svy: mean `var' if m8s1q3==1
}

*For female teachers

foreach var in student_knowledge student_proficient  {
svy: mean `var' if m8s1q3==2
}

*******************
*ECD assessment
*******************
frame change first_grade_assessment
*create indicator for % correct on ECD assessment
*There are no wrong values in the dataset- all variables are already set in [0,1] range

*#rename this variable to avoid dropping when I run anonymization program later
 rename   m6s2q6a_name_writing m6s2q6a_nm_writing
 rename   m6s2q6b_name_writing m6s2q6b_nm_writing_response

 *one of the questions had a full set of options, per conversation with Maryam, we are replacing "not administered" as missing
 gen not_administered = 1 if m6s2q13b_backward_digit == 77
 replace m6s2q13b_backward_digit = . if m6s2q13b_backward_digit == 77
 
* Recode variables ending with specified suffixes using bin_var function
foreach suffix in comprehension letters words sentence nm_writing print produce_set number_ident number_compare simple_add backward_digit perspective conflict_resol {
    ds *`suffix'
    foreach var in `r(varlist)' {
        bin_var `var' 1
    }
}

* Recode variables ending with "head_shoulders" to be 1 if equal to 2, otherwise 0
ds *head_shoulders
foreach var in `r(varlist)' {
    bin_var `var' 2
}

* Recode variables ending with "vocabn" based on conditions
ds *vocabn
foreach var in `r(varlist)' {
    replace `var' = . if `var' == 98
    replace `var' = 0 if inlist(`var', 99, 77)
    replace `var' = `var' / 10 if `var' < 10 & !missing(`var')	
    replace `var' = 1 if `var' >= 10 & !missing(`var')
}

* Recode variables ending with "counting" based on conditions
ds *counting
foreach var in `r(varlist)' {
    replace `var' = . if `var' == 98
    replace `var' = 0 if inlist(`var', 99, 77)
    replace `var' = `var' / 30 if `var' < 30 & !missing(`var')
    replace `var' = 1 if `var' >= 30 & !missing(`var')
}

 
****Literacy****
*calculate # of literacy items correct
egen ecd_literacy_student_knowledge=rowtotal(*vocabn *comprehension *letters *words *sentence m6s2q6a_nm_writing *_print)
replace ecd_literacy_student_knowledge=ecd_literacy_student_knowledge/25

****Math****
*calculate # of math items correct
egen ecd_math_student_knowledge=rowtotal(*counting *produce_set *number_ident *number_compare *simple_add)
replace ecd_math_student_knowledge=ecd_math_student_knowledge/19

****Executive Functioning****
*calculate # of executive functioning items correct
egen ecd_exec_student_knowledge=rowtotal(*backward_digit *head_shoulders)
*to account for the number of non-missing for that particular question that had a full set of options, divide the sum by 26
 replace ecd_exec_student_knowledge=ecd_exec_student_knowledge/26 if not_administered == 1
 replace ecd_exec_student_knowledge=ecd_exec_student_knowledge/27 if not_administered != 1
 
****Socio-Emotional****
*calculate # of socio emotional items correct
egen ecd_soc_student_knowledge=rowtotal(*perspective *conflict_resol)
replace ecd_soc_student_knowledge=ecd_soc_student_knowledge/5

*calculate % correct for literacy, math, exec functioning, socio emotional and total
gen ecd_student_knowledge=(ecd_literacy_student_knowledge+ecd_math_student_knowledge+ecd_exec_student_knowledge+ecd_soc_student_knowledge)/4
gen ecd_student_proficiency=(ecd_student_knowledge>=.80) if !missing(ecd_student_knowledge)
gen ecd_math_student_proficiency=(ecd_math_student_knowledge>=.80) if !missing(ecd_math_student_knowledge)
gen ecd_literacy_student_proficiency=(ecd_literacy_student_knowledge>=.80) if !missing(ecd_literacy_student_knowledge)
gen ecd_exec_student_proficiency=(ecd_exec_student_knowledge>=.80) if !missing(ecd_exec_student_knowledge)
gen ecd_soc_student_proficiency=(ecd_soc_student_knowledge>=.80) if !missing(ecd_soc_student_knowledge)

foreach var in ecd_literacy_student_knowledge ecd_math_student_knowledge ecd_soc_student_knowledge ecd_exec_student_knowledge ecd_student_knowledge ecd_student_proficiency ecd_math_student_proficiency ecd_literacy_student_proficiency ecd_exec_student_proficiency ecd_soc_student_proficiency  {
replace `var' = `var'*100
}
                                  


svyset school_code, strata($strata) singleunit(scaled) weight(school_weight)   || ecd_assessment__id, weight(g1_stud_weight)
svy: mean ecd_student_proficiency

*For male students

svy: mean ecd_student_proficiency if m6s1q3==1


*For female students

svy: mean ecd_student_proficiency if m6s1q3==2


*********************************************
***** School Inputs ********
*********************************************

* School survey. Total score starts at 1 and points added are the sum of whether a school has: 
*   - Functional blackboard 
* - Pens, pencils, textbooks, exercise books 
* - Fraction of students in class with a desk 
* - Used ICT in class and have access to ICT in the school

frame change school

gen blackboard_functional= 1 if m4scq10_inpt==1 & m4scq9_inpt==1 & m4scq8_inpt==1
replace blackboard_functional = 0 if (m4scq10_inpt==0 | m4scq9_inpt==0 | m4scq8_inpt==0)

gen share_textbook=(m4scq5_inpt)/(m4scq4_inpt)
gen share_pencil=(m4scq6_inpt)/(m4scq4_inpt)
gen share_exbook=(m4scq7_inpt)/(m4scq4_inpt)
gen pens_etc = (share_pencil>=0.9 & share_exbook>=0.9) if !missing(share_pencil) & !missing(share_exbook)
gen textbooks = (share_textbook>=0.9) if !missing(share_textbook)
gen share_desk = 1-(m4scq11_inpt/m4scq4_inpt)
gen used_ict_num =0 if m1sbq12_inpt==0
replace used_ict_num = m1sbq13a_inpt_etri if m1sbq12_inpt>=1 & !missing(m1sbq12_inpt)

gen access_ict = 0 if m1sbq12_inpt==0 | m1sbq13_inpt==0
replace access_ict =1 if m1sbq12_inpt>=1 & m1sbq13_inpt==1 & !missing(m1sbq12_inpt)
replace access_ict = 0.5 if m1sbq12_inpt>=1 & m1sbq13_inpt==0 & !missing(m1sbq12_inpt)


frame copy teachers school_teacher_ques_INPT
frame change school_teacher_ques_INPT
collapse (mean) m3sbq4_inpt, by(school_code)
rename m3sbq4_inpt used_ict_pct

frame change school
frlink m:1 school_code, frame(school_teacher_ques_INPT)
frget used_ict_pct, from(school_teacher_ques_INPT)

gen used_ict=(used_ict_pct>=0.5 & used_ict_num>=3) if !missing(used_ict_num) & !missing(used_ict_pct)

gen inputs = textbooks+blackboard_functional + pens_etc + share_desk +  0.5*used_ict + 0.5*access_ict


svyset school_code, strata($strata) singleunit(scaled) weight(school_weight)
svy: mean inputs


*********************************************
***** School Infrastructure ********
*********************************************

*School survey. Total score starts at 1 and points added are the sum of whether a school has: 
*Access to adequate drinking water 
*Functional toilets.  Extra points available if are separate for boys/girls, private, useable, and have hand washing facilities 
*Electricity  in the classroom 
*Internet
*School is accessible for those with disabilities (road access, a school ramp for wheelchairs, an entrance wide enough for wheelchairs, ramps to classrooms where needed, accessible toilets, and disability screening for seeing, hearing, and learning disabilities with partial credit for having 1 or 2 or the 3).)

frame change school

ds *_infr m4scq10_inpt m4scq8_inpt m1sbq15_inpt, has(type numeric)
*Replacing values if enumerators have entered value 99- "No response" code to 0- this is treated as incorrect answer
foreach var in `r(varlist)' {
replace `var'=0 if `var'==99 & !missing(`var') 
}
*Drinking water
gen drinking_water = (m1sbq9_infr==1 | m1sbq9_infr==2 | m1sbq9_infr==5 | m1sbq9_infr==6) if !missing(m1sbq9_infr)

*Functioning toilet
gen toilet_exists = 0 if m1sbq1_infr==7
replace toilet_exists = 1 if m1sbq1_infr!=7 & !missing(m1sbq1_infr)
gen toilet_separate = (m1sbq2_infr==1 | m1sbq2_infr==3) if !missing(m1sbq2_infr)
gen toilet_private = m1sbq4_infr
gen toilet_usable = m1sbq5_infr
gen toilet_handwashing = m1sbq7_infr
gen toilet_soap = m1sbq8_infr
*if toilet exist, separate for boys/girls, clean, private, useable,  handwashing available
gen functioning_toilet = 1 if toilet_exists==1 & toilet_usable==1 & toilet_separate==1  & toilet_private==1  & toilet_handwashing==1
replace functioning_toilet = 0 if toilet_exists==0 | toilet_usable==0 | toilet_separate==0  | toilet_private==0  | toilet_handwashing==0

*Visbility
gen visibility = 1 if m4scq10_inpt==1 & m4scq8_inpt==1
replace visibility = 0 if m4scq10_inpt==0 & m4scq8_inpt==1

*Electricity
gen class_electricity = (m1sbq11_infr==1) if !missing(m1sbq11_infr)

*Accessibility for people with disabilities

gen disab_road_access = 1 if m1s0q2_infr==1 & !missing(m1s0q2_infr)
replace disab_road_access = 0 if m1s0q2_infr!=1 & !missing(m1s0q2_infr)

gen disab_school_ramp = 1 if m1s0q3_infr == 0 & !missing(m1s0q3_infr)
replace disab_school_ramp = 1 if m1s0q4_infr==1 & m1s0q3_infr==1
replace disab_school_ramp = 0 if m1s0q4_infr==0 & m1s0q3_infr==1

gen disab_school_entr = 1 if m1s0q5_infr==1 & !missing(m1s0q5_infr)
replace disab_school_entr = 0 if m1s0q5_infr!=1 & !missing(m1s0q5_infr)

gen disab_class_ramp =1 if m4scq1_infr==0 & !missing(m4scq1_infr==1)
replace disab_class_ramp = 1 if m4scq2_infr==1 & m4scq1_infr==1
replace disab_class_ramp = 0 if m4scq2_infr==0 & m4scq1_infr==1

gen disab_class_entr = 1 if m4scq3_infr==1 & !missing(m4scq3_infr)
replace disab_class_entr = 0 if m4scq3_infr!=1 & !missing(m4scq3_infr)
egen disab_screening = rowmean(m1sbq17_infr__1 m1sbq17_infr__2 m1sbq17_infr__3)
gen coed_toilet = 0 if m1sbq1_infr==7 & !missing(m1sbq1_infr)
replace coed_toilet = m1sbq6_infr if m1sbq1_infr!=7 & !missing(m1sbq1_infr)
gen disability_accessibility = (disab_road_access+disab_school_ramp+disab_school_entr+disab_class_ramp+disab_class_entr+coed_toilet+disab_screening)/7
                          
gen internet = 1 if m1sbq15_inpt==2
replace internet = .5 if m1sbq15_inpt==1
replace internet = 0 if m1sbq15_inpt==0 | missing(m1sbq15_inpt)


gen infrastructure = drinking_water+ functioning_toilet+ internet + class_electricity+ disability_accessibility



svyset school_code, strata($strata) singleunit(scaled) weight(school_weight)
svy: mean drinking_water functioning_toilet internet class_electricity disability_accessibility infrastructure

*********************************************
**********School Operational Management *********
*********************************************

*Princials/head teachers are given two vignettes:
*One on solving the problem of a hypothetical leaky roof 
*One on solving a problem of inadequate numbers of textbooks.  
*Each vignette is worth 2 points.  
*
*The indicator will measure two things: presence of functions and quality of functions. In each vignette: 
*0.5 points are awarded for someone specific having the responsibility to fix 
*0.5 point is awarded if the school can fully fund the repair, 0.25 points is awarded if the school must get partial help from the community, and 0 points are awarded if the full cost must be born by the community 
*1 point is awarded if the problem is fully resolved in a timely manner, with partial credit given if problem can only be partly resolved

frame change school

gen vignette_1_resp = cond((m7sbq1_opmn==0 | m7sbq1_opmn == 98) & (m7sbq4_opmn==4 | m7sbq4_opmn==98),0,0.5,.)
replace vignette_1_resp=. if missing(m7sbq1_opmn) & missing(m7sbq1_opmn)
replace vignette_1_resp = 0.5 if !(m7sbq1_opmn==0 | m7sbq1_opmn == 98) & (m7sbq4_opmn==4 | m7sbq4_opmn==98)

gen vignette_1_finance= 0.5 if m7sbq2_opmn==1
replace vignette_1_finance = 0.25 if (m7sbq2_opmn==2 | m7sbq2_opmn==97)
replace vignette_1_finance = 0 if m7sbq2_opmn==3
replace vignette_1_finance = 0.5 if m7sbq1_opmn==0 & !(m7sbq4_opmn==4 | m7sbq4_opmn==98)

gen vignette_1_address = 0 if m7sbq3_opmn==1 & m7sbq1_opmn==1
replace vignette_1_address = 0.5 if (m7sbq3_opmn==2 | m7sbq3_opmn==97) & m7sbq1_opmn==1
replace vignette_1_address = 1 if m7sbq3_opmn==3 & m7sbq1_opmn==1
replace vignette_1_address = 0 if m7sbq5_opmn==1 & m7sbq1_opmn!=1 & !missing(m7sbq1_opmn)
replace vignette_1_address = 0.5 if m7sbq5_opmn==2 & m7sbq1_opmn!=1 & !missing(m7sbq1_opmn)
replace vignette_1_address = 1 if m7sbq5_opmn==3 & m7sbq1_opmn!=1 & !missing(m7sbq1_opmn)

*Give total score for this vignette
gen vignette_1 = vignette_1_resp + vignette_1_finance + vignette_1_address
*  // no one responsible that is known
gen vignette_2_resp = 0 if m7scq1_opmn==98
replace vignette_2_resp = 0.5 if m7scq1_opmn!=98 &!missing(m7scq1_opmn)

* //parents are forced to buy textbooks 
gen vignette_2_finance = 0 if m7scq1_opmn==1 | m7scq1_opmn == 98
replace vignette_2_finance = 0.5 if !(m7scq1_opmn==1 | m7scq1_opmn == 98) & !missing(m7scq1_opmn)

*Give partial credit based on how quickly it will be solved <1 month, 1-3, 3-6, 6-12, >1 yr
gen vignette_2_address = 1 if m7scq2_opmn==1
replace vignette_2_address = .75 if m7scq2_opmn==2
replace vignette_2_address = .5 if m7scq2_opmn==3
replace vignette_2_address = .25 if m7scq2_opmn==4
replace vignette_2_address = 0 if m7scq2_opmn==5 | m7scq2_opmn==98
*Sum all components for overall score
gen vignette_2= vignette_2_resp + vignette_2_finance + vignette_2_address
gen operational_management=1+vignette_1+vignette_2


svyset school_code, strata($strata) singleunit(scaled) weight(school_weight)
svy: mean operational_management

*********************************************
**********School Instructional Leadership *********
*********************************************

*School survey. Total score starts at 1 and points added are the sum of whether a teacher has: 
*  - Had a classroom observation in past year 
* - Had a discussion based on that observation that lasted longer than 10 min 
* - Received actionable feedback from that observation 
* - Teacher had a lesson plan and discussed it with another person

frame change teachers

gen classroom_observed = 1 if m3sdq15_ildr ==1
replace classroom_observed = 0 if m3sdq15_ildr!=1 & !missing(m3sdq15_ildr)
*Set recent to mean under 12 months
gen classroom_observed_recent = 1 if classroom_observed==1 & m3sdq16_ildr<=12
replace classroom_observed_recent = 0 if !(classroom_observed==1 & m3sdq16_ildr<=12)
replace classroom_observed_recent=. if missing(classroom_observed) & missing(classroom_observed)
gen discussion_30_min = 1 if m3sdq20_ildr==3
replace discussion_30_min = 0 if m3sdq20_ildr!=3 
replace discussion_30_min = . if missing(m3sdq20_ildr)
*Make sure there was discussion and lasted more than 30 min
gen discussed_observation = 1 if classroom_observed==1 & m3sdq19_ildr==1 & m3sdq20_ildr>=2
replace discussed_observation = 0 if !(classroom_observed==1 & m3sdq19_ildr==1 & m3sdq20_ildr>=2)
replace discussed_observation=. if missing(classroom_observed) 


gen feedback_observation = 1 if (m3sdq21_ildr==1)
 replace feedback_observation = 0 if !(m3sdq21_ildr==1)
 replace feedback_observation=. if missing(m3sdq21_ildr)
replace feedback_observation = 0 if !(m3sdq15_ildr==1 & m3sdq19_ildr==1) //fix an issue where teachers that never had classroom observed arent asked this question.
replace feedback_observation=. if missing(m3sdq15_ildr) & missing(m3sdq19_ildr)

gen lesson_plan = 1 if m3sdq23_ildr==1
replace lesson_plan = 0 if m3sdq23_ildr!=1 
replace lesson_plan = . if missing(m3sdq23_ildr)

gen lesson_plan_w_feedback = 1 if m3sdq23_ildr==1 & m3sdq24_ildr==1
replace lesson_plan_w_feedback = 0 if !(m3sdq23_ildr==1 & m3sdq24_ildr==1)
replace lesson_plan_w_feedback =. if missing(m3sdq23_ildr) & missing(m3sdq24_ildr)

gen instructional_leadership = 1+0.5*classroom_observed + 0.5*classroom_observed_recent + discussed_observation + feedback_observation + lesson_plan_w_feedback
replace instructional_leadership= (1.5 + lesson_plan_w_feedback) if classroom_observed!=1 & !missing(classroom_observed)


svyset school_code, strata($strata) singleunit(scaled) weight(school_weight)
svy: mean instructional_leadership

*********************************************
***** School Principal School Knowledge ***********
*********************************************
* The aim of this indicator is to measure the extent to which principals have the knowledge about their own schools that is necessary for them to be effective managers. A score from 1 to 5 capturing the extent to which the principal is familiar with certain key aspects of the day-to-day workings of the school (in schools that have principals). Principal receives points in the following way: 
*   - 5 points. Principal gets all 90-100% of questions within accuracy bounds (defined below). 
* - 4 points. Principal gets 80-90% of question within accuracy bounds. 
* - 3 points. Principal gets 70-80% of question within accuracy bounds. 
* - 2 points. Principal gets 60-70% of question within accuracy bounds. 
* - 1 points. Principal gets under 60% of question within accuracy bounds. 
* 
* Accuracy bounds for each question. 
* Within 1 teacher/student for each of the following: 
*   - Out of these XX teachers, how many do you think would be able to correctly add triple digit numbers (i.e. 343+215+127)? 
*   - Out of these XX teachers, how many do you think would be able to correctly to multiply double digit numbers (i.e. 37 x 13)? 
*   - Out of these XX teachers, how many do you think would be able to complete sentences with the correct world (i.e. The accident _____ (see, saw, had seen, was seen) by three people)? 
*   - Any of these XX teachers have less than 3 years of experience? 
*   - Out of these XX teachers, which ones have less than 3 years of experience as a teacher? 
* Within 3 teacher/student for each of the following: 
*   - In the selected 4th grade classroom, how many of the pupils have the relevant textbooks? 
*   Must identify whether or not blackboard was working in a selected 4th grade classroom.

frame copy teachers pknw_actual_cont_temp
frame change pknw_actual_cont_temp
*keep if !missing(m5s1q1f_grammer)
keep school_code m5_teach_count m5_teach_count_math m5s2q1c_number m5s2q1e_number m5s1q1f_grammer
collapse m5_teach_count m5_teach_count_math m5s2q1c_number m5s2q1e_number m5s1q1f_grammer, by(school_code)
frame put *,into(pknw_actual_cont)

frame copy teachers pknw_actual_exper_temp
frame change pknw_actual_exper_temp

 *just for now for the purposes of fuzzy matching try to get a list of all teachers from the roster
 preserve 
 	keep school_code m2saq2 m3saq5 m3saq6 m5s2q1c_number m5s2q1e_number m5s1q1f_grammer
 	
 	*for simplicity, drop the ones that do not have any relevant answers
 	egen missing = rownonmiss(m3saq5 m3saq6 m5s1q1f_grammer m5s2q1c_number m5s2q1e_number)
 	
 	*drop if missing == 0
 	*drop missing
 	
 	rename m2saq2 name
 	
	duplicates drop
	duplicates tag school_code name, gen(dupl)
	replace name = "shenaz begham 2" if name == "shenaz begham" & m3saq5 == 2004 // seem to be 2 different teachers, try to differentiate them
	replace name = strupper(name)

	drop dupl
	
	*some teachers do not have names in KP, for now drop them 
	drop if name == ""
	
 	isid school_code name
 	
 	gen experience=$year - m3saq5

 
 	tempfile for_fuzzy_teacher
 	save `for_fuzzy_teacher'
 	
 	unique school_code 
 	
 	if `r(unique)' != 200 { 
 		di "Some schools do not have the necessary data"
 		break
 	}
 	
restore
 

keep if !missing(m3saq5)

keep school_code m2saq2 m3saq5 m3saq6 m3s0q1

gen experience=$year - m3saq5

*keep if experience<3
egen teacher_count_experience_less3_a = count(school_code) if experience <3 & experience != ., by(school_code)

*count the number of teachers per school that answered this question (to be able to proprely get 0)
bysort school_code: egen counter = count(experience) 

bysort school_code: egen teacher_count_experience_less3 = max(teacher_count_experience_less3_a) if experience != .

replace teacher_count_experience_less3 = 0 if teacher_count_experience_less3 == . & counter != .

drop counter teacher_count_experience_less3_a m2saq2 m3saq5 m3saq6 m3s0q1

collapse (first) teacher_count_experience_less3, by(school_code)
frame put *,into(pknw_actual_exper)

frame copy school pknw_actual_school_inpts
frame change pknw_actual_school_inpts
keep school_code blackboard_functional m4scq5_inpt m4scq4_inpt

frame change school

frlink 1:1 school_code, frame(pknw_actual_cont)
frget * , from(pknw_actual_cont)
frlink 1:1 school_code, frame(pknw_actual_exper)
frget * , from(pknw_actual_exper)

*now prepare the file for principals
frame copy school pknw
frame change pknw

preserve 
	keep school_code m7sb_troster_pknw__* m7sfq5_pknw__* m7sfq6_pknw__* m7sfq7_pknw__* m7sfq9_pknw_filter m7sfq10_pknw m7sfq11_pknw m7sfq9_pknw__* m7sfq10_pknw m4scq5_inpt m7sfq11_pknw blackboard_functional m4scq4_inpt strata school_weight m4scq12_inpt
	
	foreach v of varlist m7sb_troster_pknw__* {
		replace `v' = "" if `v' == "##N/A##"
	}
	
	*now let's just reshape it to school teacher level
	reshape long m7sb_troster_pknw__, i(school_code) j(id)
	
	drop if m7sb_troster_pknw__ == ""
	
	replace id = id + 1
	
	*!!! discuss with Brian how the logic is supposed to work for these questions in SS
	*just checking that the logic holds 
	egen m7sfq5_pknw_count = rownonmiss(m7sfq5_pknw__*)
	egen m7sfq6_pknw_count = rownonmiss(m7sfq6_pknw__*)
	egen m7sfq7_pknw_count = rownonmiss(m7sfq7_pknw__*)
	egen m7sfq9_pknw_count = rownonmiss(m7sfq9_pknw__*)
	
	bysort school_code: egen id_count = count(id)
	
	foreach v in m7sfq5_pknw m7sfq6_pknw m7sfq7_pknw m7sfq9_pknw {
		gen `v' = 1 if `v'__0 == id | `v'__1 == id | `v'__2 == id | `v'__3 == id | `v'__4 == id | `v'__5 == id | `v'__6 == id | `v'__7 == id
		*there are some instances on SS when ids seem to be shifted, to minimize the errors here, count the number of teachers that were displayed and the number of teachers were a principal gave an answer, if the numbers match, set them to 1
		replace `v' = 1 if id_count == `v'_count & `v' == .
		replace `v' = 0 if `v' != 1
	}
	
	keep school_code m7sb_troster_pknw__ m7sfq5_pknw m7sfq6_pknw m7sfq7_pknw m7sfq9_pknw m7sfq9_pknw_filter m7sfq10_pknw m4scq5_inpt m7sfq11_pknw blackboard_functional m4scq4_inpt strata school_weight m4scq12_inpt
	
	replace m7sfq9_pknw = 0 if inlist(m7sfq9_pknw_filter, 0, 98) // setting do not know to 0
	
	drop m7sfq9_pknw_filter
	rename m7sb_troster_pknw__ name
	
	replace name = strupper(name)

	duplicates drop 
	
	*for now, for the teacher with the same name, randomly rename one of them 
	replace name = "SHENAZ BEGHAM 2" if name == "SHENAZ BEGHAM" & school_code == 23969 & m7sfq7_pknw == 0
	replace name = "ZAFAR HUSSAIN" if name == "ZAFAR AHMAD" & school_code == 22126
replace name = "SHUAIB MUHAMMAD" if name == "SHOAIB AHMAD" & school_code == 16392
	replace name = "MUHAMMAD RAZA SHAH" if name == "RAZA" & school_code == 20020
	
	isid school_code name 
		
	tempfile for_fuzzy_principal
	save `for_fuzzy_principal'
	
	unique school_code 
	
	if `r(unique)' != 640 {
		di "Some schools do not have the necessary data"
		break
	}
	
restore

*now merge on the school number to see what schools never collected the relevant data from teachers 
use `for_fuzzy_principal', clear

*first try to merge them in by a perfect match between the school code and the name
merge 1:1 school_code name using `for_fuzzy_teacher' // 510, 119 unmatched

preserve 
	keep if _merge == 3
	
	tempfile perfect_match
	save `perfect_match'
restore

*for the remaining ones, let's try a fuzzy match
*save the teachers from the teacher file 
preserve
	keep if _merge == 2 
	
	gen idusing = _n
	gen txtusing = name 
	
	levelsof school_code, local(schools)

	tempfile teachers_final 
	save `teachers_final'
restore

keep if _merge == 1

gen idmaster = _n
gen txtmaster = name

tempfile schools_final
save `schools_final' // to be able to bring this back later after the fuzzy merge

levelsof school_code, local(schools_principal)

foreach s of local schools_principal {
	preserve 
		keep if school_code == `s'
		
		tempfile school_`s'
		save `school_`s''
		
	restore
	
}

use `teachers_final', clear

levelsof school_code, local(schools)

foreach s of local schools {
	preserve 
		keep if school_code == `s'
		
		tempfile teachers_`s'
		save `teachers_`s''
	restore
}

foreach s of local schools_principal {
	
	use `school_`s'', clear
	
	cap matchit idmaster txtmaster using `teachers_`s'', idusing(idusing) txtusing(txtusing)
	
	*keep only the one with the highest score
	cap bysort idmaster txtmaster: egen double max_score = max(similscore)
	cap keep if similscore == max_score
	
	tempfile final_`s'
	save `final_`s''
}

local counter = 1 

foreach s of local schools_principal {
	
	if `counter' == 1 {
		use `final_`s'', clear
	}
	else {
		append using `final_`s''
	}
	
	local counter = `counter' + 1 
	
}

*remove the ones that were not matched
drop if txtusing == ""
keep idmaster idusing txtmaster txtusing similscore


*we need to make sure that we are only matching one teacher from the principal module to one teacher from the teacher module
isid idmaster txtmaster

*do the same thing for the teachers in the roster file, i.e. address the cases when the same teacher in the roster file was matched with two teachers 

isid idusing txtusing

*now bring in the data from the main modules
merge 1:1 idmaster txtmaster using `schools_final', gen(merge_schools) // ALL MATCHED!

merge m:1 idusing txtusing using `teachers_final', gen(merge_teachers) update

*in case of Bangladesh, everything has been confirmed, we can drop the ones from the teachers modules that were not matched to any teachers in the principal module. keeping 11 teachers from the principal module that cannot be matched to any teachers in the school
drop if merge_teachers == 2

*bring in the data from the perfect match
append using `perfect_match'

*dropping irrelevant variables
drop idmaster idusing txtmaster txtusing similscore 
order school_code name missing

count if _merge != 3 & merge_schools != 3 // 0 unmerge

tab missing, miss // 7 with no relevant information from any teacher module
tab experience, miss // 16 (3%) with no information on experience


*first compute the variables we need on a teacher level 
gen add_triple_digit_pknw_t_lvl = 1 - abs(m7sfq5_pknw-m5s2q1c_number)

gen multiply_double_digit_pknw_t_lvl = 1 - abs(m7sfq6_pknw-m5s2q1e_number)

gen complete_sentence_pknw_t_lvl = 1 - abs(m7sfq7_pknw-m5s1q1f_grammer)

gen experience_less_3 = 1 if experience < 3 & !missing(experience)
replace experience_less_3  = 0 if experience_less_3 == . & !missing(experience) 

gen experience_pknw_t_lvl = 1 - abs(m7sfq9_pknw - experience_less_3)

*now create final variables based on the 80% threshold for the school
foreach v in add_triple_digit_pknw multiply_double_digit_pknw complete_sentence_pknw experience_pknw {
	bysort school_code: egen count_`v' = count(`v'_t_lvl) // total number of nonmissing for each question for each school
	bysort school_code: egen good_`v' = sum(`v'_t_lvl)
	
	gen share_`v' = good_`v'/count_`v' if count_`v' != 0
	
	gen `v' = 1 if share_`v' >= 0.8 & share_`v' != .
	replace `v' = 0 if share_`v' < 0.8 & share_`v' != .
	
}


*!!! REMOVED THE DIVISION, JUST COMPARING THE NUMBERS (DISCUSS!!!). Adjusting the principal estimation by the attendance rate
gen attendance = m4scq4_inpt/m4scq12_inpt
gen textbooks_pknw = 1 if ((attendance*m7sfq10_pknw >= 0.8*m4scq5_inpt & attendance*m7sfq10_pknw <= 1.2*m4scq5_inpt & !missing(m7sfq10_pknw-m4scq5_inpt)))
replace textbooks_pknw = 0 if textbooks_pknw == . & !missing(m7sfq10_pknw-m4scq5_inpt)

gen blackboard_pknw = 1 if m7sfq11_pknw==blackboard_functional & !missing(m7sfq11_pknw) & !missing(blackboard_functional)
replace blackboard_pknw = 0 if !missing(m7sfq11_pknw) & !missing(blackboard_functional) & m7sfq11_pknw == 98 // per conversation with Brian, if a principal does not know if there is blackboard, then we can set this to 0 
replace blackboard_pknw = 0 if m7sfq11_pknw!=blackboard_functional & !missing(m7sfq11_pknw) & !missing(blackboard_functional)

*finally only keep the relevant variables and bring it to the school level
keep school_code add_triple_digit_pknw multiply_double_digit_pknw complete_sentence_pknw experience_pknw textbooks_pknw blackboard_pknw strata school_weight

duplicates drop

isid school_code



/*
*replace teacher_count_experience_less3 = 0 if missing(teacher_count_experience_less3)
gen m5s2q1c_number_new = m5s2q1c_number*m5_teach_count
gen m5s2q1e_number_new=m5s2q1e_number*m5_teach_count,
gen m5s1q1f_grammer_new=m5s1q1f_grammer*m5_teach_count
*
* create a new indicator, m7sfq5_pknw, which contains the number of non-missing responses to questions starting with m7sfq5_pknw__*
gen m7sfq5_pknw = 0
ds m7sfq5_pknw__*
foreach var in `r(varlist)' {
replace m7sfq5_pknw = m7sfq5_pknw + (!missing(`var'))
}
* do the same for m7sfq6_pknw, m7sfq7_pknw
gen m7sfq6_pknw = 0
ds m7sfq6_pknw__*
foreach var in `r(varlist)' {
replace m7sfq6_pknw = m7sfq6_pknw + (!missing(`var'))
}
gen m7sfq7_pknw = 0
ds m7sfq7_pknw__*
foreach var in `r(varlist)' {
replace m7sfq7_pknw = m7sfq7_pknw + (!missing(`var'))
}

gen add_triple_digit_pknw = 1 if ((1-abs(m7sfq5_pknw-m5s2q1c_number_new)/m7_teach_count>= 0.8) | (m7sfq5_pknw-m5s2q1c_number_new <= 1)) & !missing(m7sfq5_pknw) & !missing(m5s2q1c_number_new) & !missing(m7_teach_count)
replace add_triple_digit_pknw = 0 if !((1-abs(m7sfq5_pknw-m5s2q1c_number_new)/m7_teach_count>= 0.8) | (m7sfq5_pknw-m5s2q1c_number_new <= 1)) & !missing(m7sfq5_pknw) & !missing(m5s2q1c_number_new) & !missing(m7_teach_count)

gen multiply_double_digit_pknw = 1 if ((1-abs(m7sfq6_pknw-m5s2q1e_number_new)/m7_teach_count>= 0.8) | (m7sfq6_pknw-m5s2q1e_number_new <= 1)) & !missing(m7sfq6_pknw) & !missing(m5s2q1e_number_new) & !missing(m7_teach_count)
replace multiply_double_digit_pknw = 0 if !((1-abs(m7sfq6_pknw-m5s2q1e_number_new)/m7_teach_count>= 0.8) | (m7sfq6_pknw-m5s2q1e_number_new <= 1)) & !missing(m7sfq6_pknw) & !missing(m5s2q1e_number_new) & !missing(m7_teach_count)

gen complete_sentence_pknw = 1 if ((1-abs(m7sfq7_pknw-m5s1q1f_grammer_new)/m7_teach_count>= 0.8) | (m7sfq7_pknw-m5s1q1f_grammer_new <= 1)) & !missing(m7sfq7_pknw) & !missing(m5s1q1f_grammer_new) & !missing(m7_teach_count)
replace complete_sentence_pknw = 0 if !((1-abs(m7sfq7_pknw-m5s1q1f_grammer_new)/m7_teach_count>= 0.8) | (m7sfq7_pknw-m5s1q1f_grammer_new <= 1)) & !missing(m7sfq7_pknw) & !missing(m5s1q1f_grammer_new) & !missing(m7_teach_count)

gen experience_pknw = 1 if ((1-abs(m7sfq9_pknw_filter-teacher_count_experience_less3)/m7_teach_count>= 0.8) | (m7sfq9_pknw_filter-teacher_count_experience_less3 <= 1)) & !missing(m7sfq9_pknw_filter) & !missing(teacher_count_experience_less3) & !missing(m7_teach_count)
replace experience_pknw = 0 if !((1-abs(m7sfq9_pknw_filter-teacher_count_experience_less3)/m7_teach_count>= 0.8) | (m7sfq9_pknw_filter-teacher_count_experience_less3 <= 1)) & !missing(m7sfq9_pknw_filter) & !missing(teacher_count_experience_less3) & !missing(m7_teach_count)

gen textbooks_pknw = 1 if ((1-abs(m7sfq10_pknw-m4scq5_inpt)/m4scq4_inpt>= 0.8) | (m7sfq10_pknw-m4scq5_inpt <= 3)) & !missing(m7sfq10_pknw) & !missing(m4scq5_inpt) & !missing(m4scq4_inpt)
replace textbooks_pknw = 0 if !((1-abs(m7sfq10_pknw-m4scq5_inpt)/m4scq4_inpt>= 0.8) | (m7sfq10_pknw-m4scq5_inpt <= 3)) & !missing(m7sfq10_pknw) & !missing(m4scq5_inpt) & !missing(m4scq4_inpt)

gen blackboard_pknw = 1 if m7sfq11_pknw==blackboard_functional & !missing(m7sfq11_pknw) & !missing(blackboard_functional)
replace blackboard_pknw = 0 if m7sfq11_pknw!=blackboard_functional & !missing(m7sfq11_pknw) & !missing(blackboard_functional)


*/

egen principal_knowledge_avg = rowmean(add_triple_digit_pknw multiply_double_digit_pknw complete_sentence_pknw experience_pknw textbooks_pknw blackboard_pknw)
gen principal_knowledge_score = 5 if principal_knowledge_avg>0.9 & !missing(principal_knowledge_avg)
replace principal_knowledge_score = 4 if principal_knowledge_avg>0.8 & principal_knowledge_avg<=0.9
replace principal_knowledge_score = 3 if principal_knowledge_avg>0.7 & principal_knowledge_avg<=0.8
replace principal_knowledge_score = 2 if principal_knowledge_avg>0.6 & principal_knowledge_avg<=0.7
replace principal_knowledge_score = 1 if principal_knowledge_avg<=0.6 & !missing(principal_knowledge_avg)

svyset school_code, strata(strata) singleunit(scaled) weight(school_weight)
svy: mean principal_knowledge_score

frame change school

frlink 1:1 school_code, frame(pknw)
frget add_triple_digit_pknw multiply_double_digit_pknw complete_sentence_pknw experience_pknw textbooks_pknw blackboard_pknw principal_knowledge_avg principal_knowledge_score, from(pknw)


********************************************
***** School Principal Management Skills ***********
*********************************************


* Score of 1-5 based on sum of following: 
* goal setting:
*   - 1 Point. School Goals Exists 
* - 1 Point. School goals are clear to school director, teachers, students, parents, and other members of community (partial credit available) 
* - 1 Point. Specific goals related to improving student achievement ( improving test scores, improving pass rates, reducing drop out, reducing absenteeism, improving pedagogy, more resources for infrastructure, more resources for inputs) 
* - 1 Point. School has defined system to measure goals (partial credit available)
* problem solving:
* - 1.33 point on proactive (partial credit for just notifying a superior) on absence issue
* - 0.33 for each group principal would contact to gather info on absence
* - 1.33 point for working with local authorities, 0.5 points for organizing remedial classes, 0.25 for just informing parents
*Create variables for whether school goals exists, are clear, are relevant to learning, and are measured in an appropriate way.

frame change school
*For goals
gen school_goals_exist = 1 if m7sdq1_pman==1
replace school_goals_exist= 0 if m7sdq1_pman!=1 & !missing(m7sdq1_pman)
egen school_goals_clear = rowmean(m7sdq3_pman__1 m7sdq3_pman__2 m7sdq3_pman__3 m7sdq3_pman__4 m7sdq3_pman__5) if m7sdq1_pman==1
replace school_goals_clear = 0 if m7sdq1_pman!=1 & !missing(m7sdq1_pman)
egen school_goals_relevant_total = rowmean(m7sdq4_pman__1 m7sdq4_pman__2 m7sdq4_pman__3 m7sdq4_pman__4 m7sdq4_pman__5 m7sdq4_pman__6 m7sdq4_pman__7 m7sdq4_pman__8 m7sdq4_pman__97)
gen school_goals_relevant = 1 if school_goals_relevant_total>0 & !missing(school_goals_relevant_total) & m7sdq1_pman==1
replace school_goals_relevant = 0 if school_goals_relevant_total==0 & m7sdq1_pman==1
replace school_goals_relevant = 0 if m7sdq1_pman!=1 &!missing(m7sdq1_pman)
gen school_goals_measured = 0 if m7sdq5_pman ==1 & m7sdq1_pman==1
replace school_goals_measured =0.5 if (m7sdq5_pman==2 | m7sdq5_pman==97) & m7sdq1_pman==1
replace school_goals_measured =1 if m7sdq5_pman ==3 & m7sdq1_pman==1
replace school_goals_measured =0 if m7sdq1_pman!=1 & !missing(m7sdq1_pman)

gen goal_setting =1+school_goals_exist+school_goals_clear+school_goals_relevant+school_goals_measured

*Now for problem solving
gen problem_solving_proactive = 1 if m7seq1_pman ==4
replace problem_solving_proactive = 0.5 if (m7seq1_pman==2 | m7seq1_pman==3)
replace problem_solving_proactive = 0 if (m7seq1_pman==1 | m7seq1_pman==98)
replace problem_solving_proactive = 0 if ((!inlist(m7seq1_pman,1,2,3,4,98)) | missing(m7seq1_pman))

gen problem_solving_info_collect = (m7seq2_pman__1+m7seq2_pman__2 + m7seq2_pman__3 + m7seq2_pman__4)/4

*Error: Corrected but check
gen problem_solving_stomach = 1 if m7seq3_pman==4 
replace problem_solving_stomach = 0.5 if m7seq3_pman==3
replace problem_solving_stomach = 0.25 if (m7seq3_pman==1 | m7seq3_pman==2 | m7seq3_pman==97)
 replace problem_solving_stomach = 0 if ((!inlist(m7seq3_pman,1,2,3,4,97)) | missing(m7seq3_pman))

gen problem_solving=1+(4/3)*problem_solving_proactive+(4/3)*problem_solving_info_collect+(4/3)*problem_solving_stomach
gen principal_management = (goal_setting+problem_solving)/2

svyset school_code, strata($strata) singleunit(scaled) weight(school_weight)
svy: mean principal_management

*********************************************
***** Teacher Teaching Attraction ***********
*********************************************

* In the school survey, a number of De Facto questions on teacher attraction are asked. 0.8 points is awarded for each of the following: 
*   - 0.8 Points. Teacher satisfied with job 
* - 0.8 Points. Teacher satisfied with status in community 
* - 0.8 Points. Would better teachers be promoted faster? 
*   - 0.8 Points. Do teachers receive bonuses? 
*   - 0.8 Points. One minus the fraction of months in past year with a salary delay.


*create function to clean teacher attitudes questions.  Need to reverse the order for scoring for some questions.  
*Should have thought about this, when programming in Survey Solutions and scale 1-5.

frame change teachers

gen teacher_satisfied_job = . if m3seq1_tatt==99
replace teacher_satisfied_job= 5 if m3seq1_tatt==1
replace teacher_satisfied_job= 4 if m3seq1_tatt==2
 replace teacher_satisfied_job= 3 if m3seq1_tatt==3
 replace teacher_satisfied_job= 2 if m3seq1_tatt==4
 replace teacher_satisfied_job= 1 if m3seq1_tatt==5
replace teacher_satisfied_job= teacher_satisfied_job/5

gen teacher_satisfied_status = . if m3seq2_tatt==99
replace teacher_satisfied_status= 5 if m3seq2_tatt==1
replace teacher_satisfied_status= 4 if m3seq2_tatt==2
 replace teacher_satisfied_status= 3 if m3seq2_tatt==3
 replace teacher_satisfied_status= 2 if m3seq2_tatt==4
 replace teacher_satisfied_status= 1 if m3seq2_tatt==5
replace teacher_satisfied_status= teacher_satisfied_status/5

gen better_teachers_promoted = 1 if m3seq3_tatt==1
replace better_teachers_promoted = 0 if m3seq3_tatt!=1 & !missing(m3seq3_tatt)

gen teacher_bonus = 1 if m3seq4_tatt==1
replace teacher_bonus = 0 if m3seq4_tatt!=1 & !missing(m3seq4_tatt)

gen teacher_bonus_attend =1 if m3seq5_tatt_1==1 & m3seq4_tatt==1 
replace teacher_bonus_attend =0 if m3seq5_tatt_1!=1 & !missing(m3seq5_tatt_1) & m3seq4_tatt==1 
replace teacher_bonus_attend =0 if m3seq4_tatt!=1 & !missing(m3seq4_tatt)

gen teacher_bonus_student_perform =1 if m3seq5_tatt_2==1 & m3seq4_tatt==1 
replace teacher_bonus_student_perform =0 if m3seq5_tatt_2!=1 & !missing(m3seq5_tatt_2) & m3seq4_tatt==1 
replace teacher_bonus_student_perform =0 if m3seq4_tatt!=1 & !missing(m3seq4_tatt)

gen teacher_bonus_extra_duty =1 if m3seq5_tatt_3==1 & m3seq4_tatt==1 
replace teacher_bonus_extra_duty =0 if m3seq5_tatt_3!=1 & !missing(m3seq5_tatt_3) & m3seq4_tatt==1 
replace teacher_bonus_extra_duty =0 if m3seq4_tatt!=1 & !missing(m3seq4_tatt)

gen teacher_bonus_hard_staff =1 if m3seq5_tatt_4==1 & m3seq4_tatt==1 
replace teacher_bonus_hard_staff =0 if m3seq5_tatt_4!=1 & !missing(m3seq5_tatt_4) & m3seq4_tatt==1 
replace teacher_bonus_hard_staff =0 if m3seq4_tatt!=1 & !missing(m3seq4_tatt)

gen teacher_bonus_subj_shortages =1 if m3seq5_tatt_5==1 & m3seq4_tatt==1 
replace teacher_bonus_subj_shortages =0 if m3seq5_tatt_5!=1 & !missing(m3seq5_tatt_5) & m3seq4_tatt==1 
replace teacher_bonus_subj_shortages =0 if m3seq4_tatt!=1 & !missing(m3seq4_tatt)

gen teacher_bonus_add_qualif =1 if m3seq5_tatt_6==1 & m3seq4_tatt==1 
replace teacher_bonus_add_qualif =0 if m3seq5_tatt_6!=1 & !missing(m3seq5_tatt_6) & m3seq4_tatt==1 
replace teacher_bonus_add_qualif =0 if m3seq4_tatt!=1 & !missing(m3seq4_tatt)

gen teacher_bonus_school_perform =1 if m3seq5_tatt_7==1 & m3seq4_tatt==1 
replace teacher_bonus_school_perform =0 if m3seq5_tatt_7!=1 & !missing(m3seq5_tatt_7) & m3seq4_tatt==1 
replace teacher_bonus_school_perform =0 if m3seq4_tatt!=1 & !missing(m3seq4_tatt)

*Error- m3seq5_other_tatt absent in teacher_questionnaire
*gen teacher_bonus_other = m3seq5_other_tatt if m3seq5_tatt_97==1 & m3seq4_tatt==1 
*replace teacher_bonus_other =. if m3seq5_tatt_97!=1 & !missing(m3seq5_tatt_97) & m3seq4_tatt==1 
*replace teacher_bonus_other =. if m3seq4_tatt!=1 & !missing(m3seq4_tatt)

gen salary_delays = m3seq7_tatt if m3seq6_tatt==1
replace salary_delays = 0 if m3seq6_tatt!=1 & !missing(m3seq6_tatt)
replace salary_delays = 12 if salary_delays>12 & !missing(salary_delays)
gen teacher_attraction=(1+(0.8*teacher_satisfied_job)+(.8*teacher_satisfied_status)+(.8*better_teachers_promoted)+(.8*teacher_bonus)+(.8*(1-salary_delays/12)))


svyset school_code, strata($strata) singleunit(scaled) weight(school_weight)   || unique_teach_id, weight(teacher_questionnaire_weight)
svy: mean teacher_attraction

*********************************************
***** Teacher Teaching Selection and Deployment ***********
*********************************************

* School Survey. The De Facto portion of the Teacher Selection and Deployment Indicator considers two issues: how teachers are selected into the profession and how teachers are assigned to positions (transferred) once in the profession. Research shows that degrees and years of experience explanin little variation in teacher quality, so more points are assigned for systems that also base hiring on content knowledge or pedagogical skill. 2 points are available for the way teachers are selected and 2 points are available for deployment. 
* 
* Selection 
* - 0 Points. None of the below 
* - 1 point. Teachers selected based on completion of coursework, educational qualifications, graduating from tertiary program (including specialized programs), selected based on experience 
* - 2 points. Teacher recruited based on passing written content knowledge test, passed interview stage assessment, passed an assessment conducted by supervisor based on practical experience, conduct during mockup class. 
* 
* Deployment 
* - 0 Points. None of the below 
* - 1 point. Teachers deployed based on years of experience or job title hierarchy 
* - 2 points. Teacher deployed based on performance assessed by school authority, colleagues, or external evaluator, results of interview.

frame change teachers

gen teacher_selection = 0 if (m3sdq1_tsdp_1==0 & m3sdq1_tsdp_2==0 & m3sdq1_tsdp_3==0 & m3sdq1_tsdp_4==0 & m3sdq1_tsdp_5==0 & m3sdq1_tsdp_6==0 & m3sdq1_tsdp_7==0 & m3sdq1_tsdp_8==0 & m3sdq1_tsdp_9==0)
replace teacher_selection = 1 if (m3sdq1_tsdp_1==1 | m3sdq1_tsdp_2==1 | m3sdq1_tsdp_3==1 | m3sdq1_tsdp_4==1 | m3sdq1_tsdp_7==1)
replace teacher_selection = 2 if (m3sdq1_tsdp_5==1 | m3sdq1_tsdp_6==1 | m3sdq1_tsdp_8==1 | m3sdq1_tsdp_9==1)

gen teacher_deployment = 0 if ((m3seq8_tsdp_1==0 & m3seq8_tsdp_2==0 & m3seq8_tsdp_3==0 & m3seq8_tsdp_4==0 & m3seq8_tsdp_5==0) | ( m3seq8_tsdp_99==1))
replace teacher_deployment = 1 if (m3seq8_tsdp_1==1 | m3seq8_tsdp_2==1 | m3seq8_tsdp_97==1)
replace teacher_deployment = 2 if (m3seq8_tsdp_3==1 | m3seq8_tsdp_4==1 | m3seq8_tsdp_5==1)

gen teacher_selection_deployment=1+teacher_selection+teacher_deployment


svyset school_code, strata($strata) singleunit(scaled) weight(school_weight)   || unique_teach_id, weight(teacher_questionnaire_weight)
svy: mean teacher_selection_deployment teacher_selection teacher_deployment

*********************************************
***** Teacher Teaching Support ***********
*********************************************


* School survey. Our teaching support indicator asks teachers about participation and the experience with several types of formal/informal training: 
*   
*   Pre-Service (Induction) Training: 
*   - 0.5 Points. Had a pre-service training 
* - 0.5 Points. Teacher reported receiving usable skills from training 
* 
* Teacher practicum (teach a class with supervision) 
* - 0.5 Points. Teacher participated in a practicum 
* - 0.5 Points. Practicum lasted more than 3 months and teacher spent more than one hour per day teaching to students. 
* 
* In-Service Training: 
*   - 0.5 Points. Had an in-service training 
* - 0.25 Points. In-service training lasted more than 2 total days 
* - 0.125 Points. More than 25% of the in-service training was done in the classroom. 
* - 0.125 Points. More than 50% of the in-service training was done in the classroom. 
* 
* Opportunities for teachers to come together to share ways of improving teaching: 
*   - 1 Point if such opportunities exist.

*Add in question on teach opportunities so share ways of teaching

frame change teachers

gen opportunities_teachers_share = 0 if m3sdq14_ildr!=1 & !missing(m3sdq14_ildr)
replace opportunities_teachers_share = 1 if m3sdq14_ildr==1

gen pre_training_exists = 0 if m3sdq3_tsup!=1 & !missing(m3sdq3_tsup)
replace pre_training_exists = 1 if m3sdq3_tsup==1
replace pre_training_exists = pre_training_exists/2

gen pre_training_useful =0 if m3sdq3_tsup!=1 & !missing(m3sdq3_tsup)
replace pre_training_useful =0 if m3sdq4_tsup!=1 & !missing(m3sdq4_tsup) & m3sdq3_tsup==1 
replace pre_training_useful =1 if m3sdq4_tsup==1 & m3sdq3_tsup==1 
replace pre_training_useful = pre_training_useful/2

gen pre_training_practicum =0 if m3sdq3_tsup!=1 & !missing(m3sdq3_tsup)
replace pre_training_practicum =0 if m3sdq6_tsup!=1 & !missing(m3sdq6_tsup) & m3sdq3_tsup==1 
replace pre_training_practicum =1 if m3sdq6_tsup==1 & m3sdq3_tsup==1 
replace pre_training_practicum = pre_training_practicum/2

gen pre_training_practicum_lngth = 0 if m3sdq3_tsup==0
replace pre_training_practicum_lngth = 0 if m3sdq6_tsup==2
replace pre_training_practicum_lngth = 0 if (m3sdq6_tsup==1 & (m3sdq7_tsup<3 | m3sdq8_tsup<1)) & !missing(m3sdq7_tsup) & !missing(m3sdq8_tsup)
replace pre_training_practicum_lngth = 0.5 if (m3sdq6_tsup==1 & m3sdq7_tsup>=3 & m3sdq8_tsup>=1 & !missing(m3sdq7_tsup) & !missing(m3sdq8_tsup))
replace pre_training_practicum_lngth = 0 if missing(pre_training_practicum_lngth)

gen in_service_exists = 0 if m3sdq9_tsup!=1 & !missing(m3sdq9_tsup)
replace in_service_exists = 1 if m3sdq9_tsup==1

gen in_servce_lngth = 0 if m3sdq3_tsup==0
replace in_servce_lngth = 0 if m3sdq6_tsup==2
replace in_servce_lngth = 0 if m3sdq9_tsup==1 & m3sdq10_tsup<=2 & !missing(m3sdq10_tsup)
replace in_servce_lngth = 1 if m3sdq9_tsup==1 & m3sdq10_tsup>2 & !missing(m3sdq10_tsup)
replace in_servce_lngth = 0 if missing(in_servce_lngth)

gen in_service_classroom = 0 if m3sdq9_tsup==0
replace in_service_classroom = 0 if (m3sdq9_tsup==1 & m3sdq13_tsup==1)
replace in_service_classroom = 0.5 if (m3sdq9_tsup==1 & m3sdq13_tsup==2)
replace in_service_classroom = 1 if m3sdq9_tsup==1 & m3sdq13_tsup>=3 & !missing(m3sdq13_tsup)
replace in_service_classroom = 0 if missing(in_service_classroom)

gen pre_service=pre_training_exists+pre_training_useful
gen practicum=pre_training_practicum+pre_training_practicum_lngth,
gen in_service=0.5*in_service_exists+0.25*in_servce_lngth+0.25*in_service_classroom
gen teacher_support=1+pre_service+practicum+in_service+opportunities_teachers_share
* mutate(teacher_support=if_else(teacher_support>5,5,teacher_support)) #need to fix



svyset school_code, strata($strata) singleunit(scaled) weight(school_weight)   || unique_teach_id, weight(teacher_questionnaire_weight)
svy: mean teacher_support pre_service practicum in_service opportunities_teachers_share

*********************************************
***** Teacher Teaching Evaluation ***********
*********************************************

* School survey. This policy lever measures whether there is a teacher evaluation system in place, and if so, the types of decisions that are made based on the evaluation results. Score is the sum of the following: 
*   - 1 Point. Was teacher formally evaluated in past school year? 
*   - 1 Point total. 0.2 points for each of the following: Evaluation included evaluation of attendance, knowledge of subject matter, pedagogical skills in the classroom, students' academic achievement, students' socio-emotional development 
* - 1 Point. Consequences exist if teacher receives 2 or more negative evaluations 
* - 1 Point. Rewards exist if teacher receives 2 or more positive evaluations

frame change teachers


gen formally_evaluated = 0 if m3sbq6_tmna!=1 & !missing(m3sbq6_tmna)
replace formally_evaluated = 1 if m3sbq6_tmna==1
replace formally_evaluated=. if missing(m3sbq6_tmna)

gen evaluation_content =0 if m3sbq6_tmna!=1 & !missing(m3sbq6_tmna)
replace evaluation_content =(m3sbq8_tmna_1+m3sbq8_tmna_2+ m3sbq8_tmna_3 + m3sbq8_tmna_5 + m3sbq8_tmna_6)/5 if m3sbq6_tmna==1

gen negative_consequences = 0
replace negative_consequences = . if (missing(m3sbq9_tmna_1) & missing(m3sbq9_tmna_2) & missing(m3sbq9_tmna_3) & missing(m3sbq9_tmna_4) & missing(m3sbq9_tmna_97))
replace negative_consequences = 1 if (m3sbq9_tmna_1==1 | m3sbq9_tmna_2==1 | m3sbq9_tmna_3==1 | m3sbq9_tmna_4==1 | m3sbq9_tmna_97==1)

gen positive_consequences = 0 
replace positive_consequences = . if missing(m3bq10_tmna_1) & missing(m3bq10_tmna_2) & missing(m3bq10_tmna_3) & missing(m3bq10_tmna_4) & missing(m3bq10_tmna_97)
replace positive_consequences = 1 if (m3bq10_tmna_1==1 | m3bq10_tmna_2==1 | m3bq10_tmna_3==1 | m3bq10_tmna_4==1 | m3bq10_tmna_97==1)
gen teaching_evaluation=1+formally_evaluated+evaluation_content+negative_consequences+positive_consequences

svyset school_code, strata($strata) singleunit(scaled) weight(school_weight)   || unique_teach_id, weight(teacher_questionnaire_weight)
svy: mean teaching_evaluation formally_evaluated evaluation_content negative_consequences positive_consequences

*********************************************
***** Teacher  Monitoring and Accountability ***********
*********************************************

* School Survey. This policy lever measures the extent to which teacher presence is being monitored, whether attendance is rewarded, and whether there are consequences for chronic absence. Score is the sum of the following: 
*   - 1 Point. Teachers evaluated by some authority on basis of absence. 
* - 1 Point. Good attendance is rewarded. 
* - 1 Point. There are consequences for chronic absence (more than 30% absence). 
* - 1 Point. One minus the fraction of teachers that had to miss class because of any of the following: collect paycheck, school administrative procedure, errands or request of the school district office, other administrative tasks.

frame change teachers


gen attendance_evaluated = 0 if m3sbq6_tmna!=1
replace attendance_evaluated = 0 if m3sbq6_tmna==1 & m3sbq8_tmna_1!=1
replace attendance_evaluated = 1 if m3sbq6_tmna==1 & m3sbq8_tmna_1==1
replace attendance_evaluated=. if missing(m3sbq6_tmna) 

gen attendance_rewarded = 0 if m3seq4_tatt!=1
replace attendance_rewarded = 0 if m3seq4_tatt==1 & m3seq5_tatt_1!=1
replace attendance_rewarded = 1 if m3seq4_tatt==1 & m3seq5_tatt_1==1
replace attendance_rewarded=. if missing(m3seq4_tatt) 

gen attendence_sanctions = 0 if !(missing(m3sbq2_tmna_1) & missing(m3sbq2_tmna_2) & missing(m3sbq2_tmna_3) & missing(m3sbq2_tmna_4) & missing(m3sbq2_tmna_5) & missing(m3sbq2_tmna_6) & missing(m3sbq2_tmna_97))
replace attendence_sanctions = . if missing(m3sbq2_tmna_1) & missing(m3sbq2_tmna_2) & missing(m3sbq2_tmna_3) & missing(m3sbq2_tmna_4) & missing(m3sbq2_tmna_5) & missing(m3sbq2_tmna_6) & missing(m3sbq2_tmna_97)
replace attendence_sanctions = 1 if (m3sbq2_tmna_1==1 | m3sbq2_tmna_2==1 | m3sbq2_tmna_3==1 | m3sbq2_tmna_4==1 |  m3sbq2_tmna_5 == 1 | m3sbq2_tmna_6 == 1 | m3sbq2_tmna_97==1)

gen miss_class_admin=0 if (m3sbq1_tatt_1==0 & m3sbq1_tatt_2==0 & m3sbq1_tatt_3==0 & m3sbq1_tatt_97==0)
replace miss_class_admin = 1 if (m3sbq1_tatt_1==1 | m3sbq1_tatt_2==1 | m3sbq1_tatt_3==1 | m3sbq1_tatt_97==1)


gen teacher_monitoring=1+attendance_evaluated + 1*attendance_rewarded + 1*attendence_sanctions + (1-miss_class_admin)


svyset school_code, strata($strata) singleunit(scaled) weight(school_weight)   || unique_teach_id, weight(teacher_questionnaire_weight)
svy: mean teacher_monitoring attendance_evaluated attendance_rewarded attendence_sanctions miss_class_admin

*********************************************
***** Teacher  Intrinsic Motivation ***********
*********************************************

* 
* School Survey. This lever measures whether teachers are intrinsically motivated to teach. The question(s) aim to address this 
* phenomenon by measuring the level of intrinsic motivation among teachers as well as teacher values that may be relevant for 
* ensuring that the teacher is motivated to focus on all children and not just some. Average score (1 (worst) - 5 (best)) on items 
* given to teachers on intrinsic motivation.


frame change teachers

local intrinsic_motiv_q_rev m3scq1_tinm m3scq2_tinm m3scq3_tinm m3scq4_tinm m3scq5_tinm m3scq6_tinm m3scq7_tinm m3scq10_tinm
local intrinsic_motiv_q m3scq11_tinm m3scq14_tinm
local intrinsic_motiv_q_all m3scq1_tinm m3scq2_tinm m3scq3_tinm m3scq4_tinm m3scq5_tinm m3scq6_tinm m3scq7_tinm m3scq10_tinm m3scq11_tinm m3scq14_tinm

foreach v of varlist m3scq*_tinm {
 	replace `v' = . if `v' == 99
 }
 
*(De Facto) Percent of teachers that agree or strongly agrees with It is acceptable for a teacher to be absent if the ~
gen SE_PRM_TINM_1 = 0 if m3scq1_tinm<3 & !missing(m3scq1_tinm)
replace SE_PRM_TINM_1 = 100 if m3scq1_tinm>=3 & !missing(m3scq1_tinm)
*(De Facto) Percent of teachers that agree or strongly agrees with It is acceptable for a teacher to be absent if stud~
gen SE_PRM_TINM_2 = 0 if m3scq2_tinm<3 & !missing(m3scq2_tinm) 
replace SE_PRM_TINM_2 = 100 if m3scq2_tinm>=3 & !missing(m3scq2_tinm) 
*(De Facto) Percent of teachers that agree or strongly agrees with It is acceptable for a teacher to be absent if the ~
gen SE_PRM_TINM_3 = 0 if m3scq3_tinm<3 & !missing(m3scq3_tinm) 
replace SE_PRM_TINM_3 = 100 if m3scq3_tinm>=3 & !missing(m3scq3_tinm) 
*(De Facto) Percent of teachers that agree or strongly agrees with Students deserve more attention if they attend scho~
gen SE_PRM_TINM_4 = 0 if m3scq4_tinm<3 & !missing(m3scq4_tinm)
replace SE_PRM_TINM_4 = 100 if m3scq4_tinm>=3 & !missing(m3scq4_tinm) 
*(De Facto) Percent of teachers that agree or strongly agrees with Students deserve more attention if they come to sch~
gen SE_PRM_TINM_5 = 0 if m3scq5_tinm<3 & !missing(m3scq5_tinm)
replace SE_PRM_TINM_5 = 100 if m3scq5_tinm>=3 & !missing(m3scq5_tinm) 
*(De Facto) Percent of teachers that agree or strongly agrees with Students deserve more attention if they are motivat~
gen SE_PRM_TINM_6 = 0 if m3scq6_tinm<3 & !missing(m3scq6_tinm)
replace SE_PRM_TINM_6 = 100 if m3scq6_tinm>=3 & !missing(m3scq6_tinm) 
*(De Facto) Percent of teachers that agree or strongly agrees with Students have a certain amount of intelligence and ~
gen SE_PRM_TINM_7 = 0 if m3scq7_tinm<3 & !missing(m3scq7_tinm)
replace SE_PRM_TINM_7 = 100 if m3scq7_tinm>=3 & !missing(m3scq7_tinm) 
*(De Facto) Percent of teachers that agree or strongly agrees with To be honest, students can't really change how inte~
gen SE_PRM_TINM_8 = 0 if m3scq10_tinm<3 & !missing(m3scq10_tinm)
replace SE_PRM_TINM_8 = 100 if m3scq10_tinm>=3 & !missing(m3scq10_tinm) 
*(De Facto) Percent of teachers that agree or strongly agrees with Students can always substantially change how intell~
gen SE_PRM_TINM_9 = 0 if m3scq11_tinm<3 & !missing(m3scq11_tinm)
replace SE_PRM_TINM_9 = 100 if m3scq11_tinm>=3 & !missing(m3scq11_tinm) 
*(De Facto) Percent of teachers that agree or strongly agrees with \"Students can change even their basic intelligence l~
gen SE_PRM_TINM_10 = 0 if m3scq14_tinm<3 & !missing(m3scq14_tinm)
replace SE_PRM_TINM_10 = 100 if m3scq14_tinm>=3 & !missing(m3scq14_tinm) 

foreach var in `intrinsic_motiv_q' {
gen score_temp=.
replace score_temp = 1 if `var'==1
replace score_temp = 2.33 if `var'==2
replace score_temp = 3.67 if `var'==3
replace score_temp = 5 if `var'==4
replace score_temp = . if `var'==99
replace `var'=score_temp
drop score_temp
}

foreach var in `intrinsic_motiv_q_rev' {
gen score_temp=.
replace score_temp = 1 if `var'==4
replace score_temp = 2.33 if `var'==3
replace score_temp = 3.67 if `var'==2
replace score_temp = 5 if `var'==1
replace score_temp = . if `var'==99
replace `var'=score_temp
drop score_temp
}

gen acceptable_absent = (m3scq1_tinm+ m3scq2_tinm + m3scq3_tinm)/3
gen students_deserve_attention = (m3scq4_tinm+ m3scq5_tinm + m3scq6_tinm )/3
gen growth_mindset=(m3scq7_tinm + m3scq10_tinm + m3scq11_tinm + m3scq14_tinm)/4
gen motivation_teaching = 0 if m3scq15_tinm_3>=1 & !missing(m3scq15_tinm_3)
replace motivation_teaching= 1 if ((m3scq15_tinm_3<1 & !missing(m3scq15_tinm_3)) & ((m3scq15_tinm_1>=1 & !missing(m3scq15_tinm_1)) | (m3scq15_tinm_2>=1 & !missing(m3scq15_tinm_2))| (m3scq15_tinm_4>=1 & !missing(m3scq15_tinm_4)) | (m3scq15_tinm_5>=1 & !missing(m3scq15_tinm_5))))
gen motivation_teaching_1 = 0 if m3sdq2_tmna!=1 & !missing(m3sdq2_tmna)
replace motivation_teaching_1 = 1 if m3sdq2_tmna==1
gen intrinsic_motivation=1+0.8*(0.2*acceptable_absent + 0.2*students_deserve_attention + 0.2*growth_mindset + motivation_teaching+motivation_teaching_1)

svyset school_code, strata($strata) singleunit(scaled) weight(school_weight)   || unique_teach_id, weight(teacher_questionnaire_weight)
svy: mean intrinsic_motivation acceptable_absent students_deserve_attention growth_mindset motivation_teaching motivation_teaching_1

*********************************************
***** School  Inputs and Infrastructure Standards ***********
*********************************************
*   - 1 Point. Are there standards in place to monitor blackboard and chalk, pens and pencils, basic classroom furniture, computers, textbooks, exercise books, toilets, electricity, drinking water, accessibility for those with disabilities? (partial credit available)

frame change school

egen standards_monitoring_input = rowmean(m1scq13_imon__*)
egen standards_monitoring_infra = rowmean(m1scq14_imon__*)
gen standards_monitoring=1+(standards_monitoring_input*6+standards_monitoring_infra*4)*0.4

svyset school_code, strata($strata) singleunit(scaled) weight(school_weight)
svy: mean standards_monitoring

*********************************************
***** School  Inputs and Infrastructure Monitoring ***********
*********************************************

* School Survey. This lever measures the extent to which there is a monitoring system in place to ensure that the inputs that must be available at the schools are in fact available at the schools. This set of questions will include three aspects: 
* - 1 Point. Are all input items (functioning blackboard, chalk, pens, pencils, textbooks, exercise books in 4th grade classrooms, basic classroom furniture, and at least one computer in the schools) being monitored? (partial credit available) 
* - 1 Point. Are all infrastructure items (functioning toilets, electricity, drinking water, and accessibility for people with disabilities) being monitored? (partial credit available) 
* - 1 Point. Is the community involved in the monitoring?

frame change school

replace m1scq3_imon = 1 if m1scq3_imon==1
replace m1scq3_imon = 0 if m1scq3_imon!=1 & !missing(m1scq3_imon)
replace m1scq5_imon = 0 if m1scq5_imon==0
replace m1scq5_imon = 1 if m1scq5_imon==1
replace m1scq5_imon = .5 if m1scq5_imon==2
replace m1scq5_imon = 0 if missing(m1scq5_imon)

egen monitoring_inputs_temp = rowmean(m1scq4_imon__*)
gen monitoring_inputs = monitoring_inputs_temp if m1scq1_imon==1
replace monitoring_inputs = 0 if m1scq1_imon!=1 & !missing(m1scq1_imon)

egen monitoring_infrastructure_temp = rowmean(m1scq9_imon__*)
gen monitoring_infrastructure = monitoring_infrastructure_temp if m1scq7_imon==1
replace monitoring_infrastructure = 0 if m1scq7_imon!=1 & !missing(m1scq7_imon)

gen parents_involved = 1 if m1scq3_imon==1
replace parents_involved = 0 if m1scq3_imon!=1 & !missing(m1scq3_imon)
replace parents_involved = 0 if missing(m1scq3_imon)

gen sch_monitoring=1+1.5*monitoring_inputs+1.5*monitoring_infrastructure+parents_involved


svyset school_code, strata($strata) singleunit(scaled) weight(school_weight)
svy: mean sch_monitoring

*********************************************
***** School School Management Clarity of Functions  ***********
*********************************************


frame change school
gen infrastructure_scfn = !(m7sfq15a_pknw__0==1 | m7sfq15a_pknw__98==1)
gen materials_scfn = !(m7sfq15b_pknw__0==1 | m7sfq15b_pknw__98==1)
gen hiring_scfn = !(m7sfq15c_pknw__0==1 | m7sfq15c_pknw__98==1)
gen supervision_scfn = !(m7sfq15d_pknw__0==1 | m7sfq15d_pknw__98==1)
gen student_scfn = !(m7sfq15e_pknw__0==1 | m7sfq15e_pknw__98==1)
gen principal_hiring_scfn = !(m7sfq15f_pknw__0==1 | m7sfq15f_pknw__98==1)
gen principal_supervision_scfn = !(m7sfq15g_pknw__0==1 | m7sfq15g_pknw__98==1)
gen sch_management_clarity=1+(infrastructure_scfn+materials_scfn)/2+ (hiring_scfn + supervision_scfn)/2 + student_scfn +(principal_hiring_scfn+ principal_supervision_scfn)/2

svyset school_code, strata($strata) singleunit(scaled) weight(school_weight)
svy: mean sch_management_clarity

*********************************************
***** School School Management Attraction  ***********
*********************************************

* This policy lever measures whether the right candidates are being attracted to the profession of school principals. The questions will aim to capture the provision of benefits to attract and maintain the best people to serve as principals. 
* 
* Scoring: 
*   -score is between 1-5 based on how satisfied the principal is with status in community. We will also add in component based on Principal salaries.
* For salary, based GDP per capita from 2018 World Bank  https://data.worldbank.org/indicator/NY.GDP.PCAP.CD?locations=JO.  

frame create gdp_data
frame change gdp_data

*retreive parameters from run_GEPD.do
*get data on gdp in local currency

* wbopendata, country($country)  indicator(NY.GDP.PCAP.CN) latest clear long

wbopendata, country($country)  indicator(NY.GDP.PCAP.CN) clear long
keep if year == 2022

*get latest value
su ny_gdp_pcap_cn
gl gdp_pcap `r(mean)'

frame change school

gen principal_satisfaction = . if m7shq1_satt==99
replace principal_satisfaction = 5 if m7shq1_satt==1
replace principal_satisfaction = 4 if m7shq1_satt == 2
 replace principal_satisfaction = 3 if m7shq1_satt == 3
 replace principal_satisfaction = 2 if m7shq1_satt == 4
 replace principal_satisfaction = 1 if m7shq1_satt == 5

replace m7shq2_satt=. if m7shq2_satt<0
replace m7shq2_satt=. if m7shq2_satt==999

*changing the values that seem to be reported in usd to the local currency (the exchange rate is on may 31, 2023)
replace m7shq2_satt = m7shq2_satt*285 if m7shq2_satt < 100 & !missing(m7shq2_satt)

*change the values that are too high to missing
replace m7shq2_satt = . if m7shq2_satt > 500000 & !missing(m7shq2_satt)

gen principal_salary=12*m7shq2_satt/$gdp_pcap	

gen principal_salary_score = 1 if principal_salary >=0 & principal_salary<=0.5 & !missing(principal_salary)
replace principal_salary_score = 2 if principal_salary >=0.5 & principal_salary<=0.75 & !missing(principal_salary)
replace principal_salary_score = 3 if principal_salary >=0.75 & principal_salary<=1 & !missing(principal_salary)
replace principal_salary_score = 4 if principal_salary >=1 & principal_salary<=1.5 & !missing(principal_salary)
replace principal_salary_score = 5 if principal_salary >=1.5  & !missing(principal_salary)

gen sch_management_attraction=(principal_satisfaction+principal_salary_score)/2

svyset school_code, strata($strata) singleunit(scaled) weight(school_weight)
svy: mean sch_management_attraction

*********************************************
***** School School Management Selection and Deployment  ***********
*********************************************


* This policy lever measures whether the right candidates being selected. These questions will probe what the recruitment process is like to 
* ensure that these individuals are getting the positions. The question would ultimately be based on: 1) there is a standard approach for selecting principals,
* 2) that approach relies on professional/academic requirements, and 3) those requirements are common in practice. 
* 
* Scoring: 
*   - 1 (lowest score) Most important factor is political affiliations or ethnic group. 
* - 2 Political affiliations or ethnic group is a consideration, but other factors considered as well. 
* - 3 Most important factor is years of experience, good relationship with owner/education department, and does not factor in quality teaching, demonstrated management qualities, or knowledge of local community. 
* - 4 Quality teaching, demonstrated management qualities, or knowledge of local community is a consideration in hiring, but not the most important factor 
* - 5 Quality teaching, demonstrated management qualities, or knowledge of local community is the most important factor in hiring. 


frame change school

gen sch_selection_deployment = 1 if m7sgq2_ssld==6 | m7sgq2_ssld==7
replace sch_selection_deployment = 2 if m7sgq1_ssld__6==1 | m7sgq1_ssld__7==1
replace sch_selection_deployment = 3 if (!(m7sgq2_ssld==6 | m7sgq2_ssld==7 |missing(m7sgq2_ssld)) & (m7sgq1_ssld__1==1 | m7sgq1_ssld__4==1 | m7sgq1_ssld__5==1 | m7sgq1_ssld__97==1))
replace sch_selection_deployment = 4 if !(m7sgq2_ssld==6 | m7sgq2_ssld==7 | missing(m7sgq2_ssld)) & (m7sgq1_ssld__2==1 | m7sgq1_ssld__3==1 | m7sgq1_ssld__8==1)
replace sch_selection_deployment = 5 if m7sgq2_ssld==2 | m7sgq2_ssld==3 | m7sgq2_ssld==8

svyset school_code, strata($strata) singleunit(scaled) weight(school_weight)
svy: mean sch_selection_deployment

*********************************************
***** School School Management Support  ***********
*********************************************


* This policy lever measures the extent to which principals receive training and/or exposure to other professional opportunities that could help them be better school leaders. 
* The questions aim to figure out if such programs are provided, and if they are, their level of quality. 
* 
* Scoring (sum of components below): 
*   - 1 Point. Principal has received formal training on managing school. 
* - 1/3 Point. Had management training for new principals. 
* - 1/3 Point. Had management in-service training. 
* - 1/3 Point. Had mentoring/coaching by experienced principals. 
* - 1 Point. Have used skills gained at training. 
* - 1 Point. Principals offered training at least once per year

frame change school

gen principal_trained = 0 if m7sgq3_ssup==0
replace principal_trained = 1 if m7sgq3_ssup==1

egen principal_training_temp = rowmean(m7sgq4_ssup__*)

gen principal_training = 0 if m7sgq3_ssup==0
replace principal_training = principal_training_temp if m7sgq3_ssup==1

gen principal_used_skills = 0 if m7sgq3_ssup==0
replace principal_used_skills = 1 if m7sgq5_ssup ==1 & m7sgq3_ssup==1

gen principal_offered = (m7sgq7_ssup==2 | m7sgq7_ssup==3 | m7sgq7_ssup==4 | m7sgq7_ssup==5)

gen sch_support=1+principal_trained+principal_training+principal_used_skills+principal_offered

svyset school_code, strata($strata) singleunit(scaled) weight(school_weight)
svy: mean sch_support principal_trained principal_training principal_used_skills principal_offered

*********************************************
***** School School Management Evaluation  ***********
*********************************************

* School Survey. This policy lever measures the extent to which principal performance is being monitored and enforced via accountability measures. 
* The idea is that the indicator will be based on: 1) there is a legislation outlining the need to monitor, 2) principals are being evaluated, 3) 
* principals are being evaluated on multiple things, and 4) there the accountability mechanisms in place.


frame change school

gen principal_formally_evaluated =1 if m7sgq8_sevl==1
replace principal_formally_evaluated= 0 if m7sgq8_sevl==0 

ds m7sgq10_sevl__*
local varlist `r(varlist)'
local SEVL: list varlist - m7sgq10_sevl__98

egen principal_eval_tot = rowtotal(`SEVL'), missing

gen principal_evaluation_multiple = 1 if m7sgq8_sevl==1 & principal_eval_tot>=5 & !missing(principal_eval_tot)
replace principal_evaluation_multiple = 0.666667 if m7sgq8_sevl==1 & principal_eval_tot>1 & principal_eval_tot<5 & !missing(principal_eval_tot)
replace principal_evaluation_multiple = 0.3333333 if m7sgq8_sevl==1 & principal_eval_tot==1
replace principal_evaluation_multiple = 0 if m7sgq8_sevl==0 

gen principal_evaluation_mult_dummy = 1 if m7sgq8_sevl == 1 & principal_eval_tot>=2 & !missing(principal_eval_tot) & !missing(m7sgq8_sevl)
 replace principal_evaluation_mult_dummy = 0 if m7sgq8_sevl == 1 & principal_eval_tot <= 1 & !missing(principal_eval_tot)
 replace principal_evaluation_mult_dummy = 0 if m7sgq8_sevl == 0 & !missing(m7sgq8_sevl)

gen principal_negative_consequences = (m7sgq11_sevl__1==1 | m7sgq11_sevl__2==1 | m7sgq11_sevl__3==1 | m7sgq11_sevl__4==1 | m7sgq11_sevl__97==1)
gen principal_positive_consequences = (m7sgq12_sevl__1==1 | m7sgq12_sevl__2==1 | m7sgq12_sevl__3==1 | m7sgq12_sevl__4==1 | m7sgq12_sevl__97==1)

gen principal_evaluation=1+principal_formally_evaluated+principal_evaluation_multiple+principal_negative_consequences+principal_positive_consequences



svyset school_code, strata($strata) singleunit(scaled) weight(school_weight)
svy: mean principal_evaluation


*********************************************
* Save school, teachers, fourth_grade, and first_grade dataframe to stata data files in processed_dir
*********************************************

frame change school
*Format school code:
format school_code %12.0f
save "$save_dir/school_Stata.dta", replace

********************************************************************************
frame change teachers

* Fix "__" vars which are later picked up by R code:

* m3sbq8_tmna_1 m3sbq8_tmna_2 m3sbq8_tmna_3 m3sbq8_tmna_4 m3sbq8_tmna_5 m3sbq8_tmna_6 m3sbq8_tmna_7 m3sbq8_tmna_8 m3sbq8_tmna_9 m3sbq8_tmna_10 m3sbq8_tmna_97 m3sbq8_tmna_98

ren m3sbq*_tmna_* m3sbq*_tmna__*

*Format school code:
format school_code %12.0f
save "$save_dir/teachers_Stata.dta", replace


********************************************************************************
frame change fourth_grade_assessment

*Format school code:
format school_code %12.0f
save "$save_dir/fourth_grade_Stata.dta", replace

********************************************************************************

frame change first_grade_assessment

*Format school code:
format school_code %12.0f
save "$save_dir/first_grade_Stata.dta", replace

****************************************************************************END***********************************************************************************
***************
