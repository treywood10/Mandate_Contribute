/*	*************************************************************/
/*     	File Name:	Mandate_Contribute_MD	                    */
/*     	Date:   	December 10, 2022                            */
/*      Author: 	Robert Lee Wood III				            */
/*      Purpose:	Create Dataset for Mandate_Contribute		*/
/*      Input Files: 				    						*/
/*     	Output File: 						                    */	
/*	*************************************************************/


**************
*** Set WD ***
**************

* Set global macro for working directory path *
global cd_path "/Users/treywood/Dropbox/Projects/Active_Projects/Mandate_Contribute"


* Set working directory *
cd ${cd_path}



*********************
*** Build dataset ***
*********************

* Import *
use Data_Analysis/Mandate_Cont.dta, clear



****************
*** Set Seed ***
****************

* Randomly drew a seed of 6859 with `di round(runiform(1,9999))' *
set seed 6859


**************************
*** Set Control Macros ***
**************************

global mission lag_contributors lag_re_hat lag_un_change
global mission2 lag_contributors lag_re_hat lag_un_change lag_troops_short 
global contributor lag_GDP_cont lag_dem_cont lag_all_troops lag_cont_troop_prop
global dyad lag_same_continent lag_bi_trade lag_joint_ios
global samp_res observe== 0 & lag_best_2 <= 2 & rand1_15 == 1


****************
*** Figure 1 ***
****************

* Regression to set e(sample) for histograms
nbreg troops lag_risk_ratio lag_best_2 $mission $contributor $dyad l_troops if $samp_res, cluster(ccode_cont) difficult 

* Save data to send to R for histogram *
keep if e(sample)
save Data_Analysis/R/hist.dta, replace


***************
*** Table 2 ***
***************

* Bring in original dataset.
use Data_Analysis/Mandate_Cont.dta, clear


* Model 1: Risk Ratio, bivariate * 
eststo m1: nbreg troops lag_risk_ratio lag_best_2 l_troops if $samp_res, cluster(ccode_cont) difficult nolog iterate(1000)


* Model 2: Risk Ratio * 
eststo m2: nbreg troops lag_risk_ratio lag_best_2 $mission $contributor $dyad l_troops if $samp_res , cluster(ccode_cont) difficult 


* Model 3: RR X Battle Deaths *
eststo m3: nbreg troops c.lag_risk_ratio##c.lag_best_2 $mission $contributor $dyad l_troops if $samp_res , cluster(ccode_cont) difficult 


* Model 4: Risk Ratio, shortfalls *
eststo m4: nbreg troops lag_risk_ratio lag_best_2 $mission2 $contributor $dyad l_troops if $samp_res , cluster(ccode_cont) difficult 


* Model 5: RR X Battle Deaths, shortfalls *
eststo m5: nbreg troops c.lag_risk_ratio##c.lag_best_2 $mission2 $contributor $dyad l_troops if $samp_res , cluster(ccode_cont) difficult 


esttab m1 m2 m3 m4 m5  ///
using Paper/Reg_RR_Final.tex, ///
se(%6.3f) b(%6.3f) label nodep ///
title(The Effect of Risk Ratio on Contributions \label{Table 2}) ///
interaction(##) ///
order(lag_risk_ratio lag_best_2 lag_troops_short $mission $contributor $dyad l_troops) ///
star(+ 0.10 * 0.05 ** 0.01) ///
addnotes("Dependent variable is troop counts. 15 potential contributor random sample.") ///
replace 


****************
*** Figure 2 ***
****************

* Retrieve dataset *
use Data_Analysis/Mandate_Cont.dta, clear


* Model 2 *
nbreg troops lag_risk_ratio lag_best_2 $mission $contributor $dyad l_troops if $samp_res , cluster(ccode_cont) difficult 


* Save dataset for rug plot * 
drop if !e(sample)
save "Data_Analysis/R/data/data_m2", replace


* Save coefficient and var-cov matrix *
mat betas = e(b)
mat vcovs = e(V)


* Export coefficient and covariance matrix *
preserve 
svmat betas, names(matcol)
outsheet betas* in 1 using "Data_Analysis/R/betas/betas_m2.txt", replace nolabel 
svmat vcovs, names(matcol)
outsheet vcovs* using "Data_Analysis/R/vcovs/vcovs_m2.txt", replace nolabel 
restore 


* Retrieve dataset *
use Data_Analysis/Mandate_Cont.dta, clear


* Model 4 *
nbreg troops lag_risk_ratio lag_best_2 $mission2 $contributor $dyad l_troops if $samp_res , cluster(ccode_cont) difficult 


* Save dataset for rug plot * 
drop if !e(sample)
save "Data_Analysis/R/data/data_m4", replace


* Save coefficient and var-cov matrix *
mat betas = e(b)
mat vcovs = e(V)


* Export coefficient and covariance matrix *
preserve 
svmat betas, names(matcol)
outsheet betas* in 1 using "Data_Analysis/R/betas/betas_m4.txt", replace nolabel 
svmat vcovs, names(matcol)
outsheet vcovs* using "Data_Analysis/R/vcovs/vcovs_m4.txt", replace nolabel 
restore 


****************
*** Figure 3 ***
****************

*** Model 3 ***

* Retrieve dataset *
use Data_Analysis/Mandate_Cont.dta, clear


* Set global macros. Use non-transformed battle deaths for substantive effects *
global samp_res2 observe== 0 & lag_best <= 200 & rand1_15 == 1


* Model 3: RR X Battle Deaths *
gen inter = lag_risk_ratio * lag_best
nbreg troops lag_risk_ratio lag_best inter $mission $contributor $dyad l_troops if $samp_res2 , cluster(ccode_cont) difficult 


* Save dataset for rug plot * 
drop if !e(sample)
save "Data_Analysis/R/data/data_m3", replace


* Save coefficient and var-cov matrix *
mat betas = e(b)
mat vcovs = e(V)


* Export coefficient and covariance matrix *
preserve 
svmat betas, names(matcol)
outsheet betas* in 1 using "Data_Analysis/R/betas/betas_m3.txt", replace nolabel 
svmat vcovs, names(matcol)
outsheet vcovs* using "Data_Analysis/R/vcovs/vcovs_m3.txt", replace nolabel 
restore 


*** Model 5 ***

* Retrieve dataset *
use Data_Analysis/Mandate_Cont.dta, clear


* Model 5: RR X Battle Deaths *
gen inter = lag_risk_ratio * lag_best
nbreg troops lag_risk_ratio lag_best inter $mission2 $contributor $dyad l_troops if $samp_res2 , cluster(ccode_cont) difficult 


* Save dataset for rug plot * 
drop if !e(sample)
save "Data_Analysis/R/data/data_m5", replace


* Save coefficient and var-cov matrix *
mat betas = e(b)
mat vcovs = e(V)


* Export coefficient and covariance matrix *
preserve 
svmat betas, names(matcol)
outsheet betas* in 1 using "Data_Analysis/R/betas/betas_m5.txt", replace nolabel 
svmat vcovs, names(matcol)
outsheet vcovs* using "Data_Analysis/R/vcovs/vcovs_m5.txt", replace nolabel 
restore 


****************
*** Figure 4 ***
****************

* Retrieve dataset *
use Data_Analysis/Mandate_Cont.dta, clear


* Set local macro for loop over tasks *
local tasks	l_pe_ce_mon l_buf_mon l_lia_war l_pe_ce_as ///
l_ch7 l_hr_mon l_ref_mon l_hr_pro l_chi_pro l_wo_pro ///
l_prociv l_un_pro l_demi_as l_ref_as l_ha_as l_hper_pro ///
l_bor_mon l_sec_ref_as l_pol_ref_as l_pol_mon l_pol_join ///
l_ddr_mon l_ddr_as 


* Loop *
foreach t of varlist `tasks' {
use Data_Analysis/Mandate_Cont.dta, clear


* Set local macros of controls and sample restrictions *
local controls lag_contributors lag_re_hat lag_un_change lag_GDP_cont lag_dem_cont lag_all_troops lag_cont_troop_prop lag_same_continent lag_bi_trade lag_joint_ios
local samp_res2 observe== 0 & lag_best <= 200 & rand1_15 == 1


* Generate interaction term of risk and task *
gen inter = `t' * lag_best 	


* Run model *
nbreg troops `t' lag_best inter `controls' l_troops if `samp_res2', cluster(ccode_cont) difficult 


* Save coefficient and var-cov matrix *
mat betas = e(b)
mat vcovs = e(V)


* Export coefficient and covariance matrix *
preserve
svmat betas, names(matcol)
outsheet betas* in 1 using "Data_Analysis/R/Tasks/betas_`t'.txt", replace nolabel 
svmat vcovs, names(matcol)
outsheet vcovs* using "Data_Analysis/R/Tasks/vcovs_`t'.txt", replace nolabel 
restore

}

* Export for substantive effects *
keep if e(sample)
save "Data_Analysis/R/Tasks/Task_data.dta", replace 
clear


*****************************************
*** Non-strategic mandates and troops ***
*****************************************

* Model 2: All observations *
nbreg troops lag_risk_ratio lag_best_2 $mission $contributor $dyad l_troops if $samp_res, difficult cluster(ccode_cont)


* Save coefficient and var-cov matrix *
mat betas = e(b)
mat vcovs = e(V)


* Export coefficient and covariance matrix *
preserve 
svmat betas, names(matcol)
outsheet betas* in 1 using "Data_Analysis/R/betas/betas_m2_all.txt", replace nolabel 
svmat vcovs, names(matcol)
outsheet vcovs* using "Data_Analysis/R/vcovs/vcovs_m2_all.txt", replace nolabel 
restore 


* Model 2: Pre-2000 *
nbreg troops lag_risk_ratio lag_best_2 $mission $contributor $dyad l_troops if $samp_res & year <= 1999, difficult cluster(ccode_cont)


* Save coefficient and var-cov matrix *
mat betas = e(b)
mat vcovs = e(V)


* Export coefficient and covariance matrix *
preserve 
svmat betas, names(matcol)
outsheet betas* in 1 using "Data_Analysis/R/betas/betas_m2_pre.txt", replace nolabel 
svmat vcovs, names(matcol)
outsheet vcovs* using "Data_Analysis/R/vcovs/vcovs_m2_pre.txt", replace nolabel 
restore 


* Model 2: Post-2000 *
nbreg troops lag_risk_ratio lag_best_2 $mission $contributor $dyad l_troops if $samp_res & year > 1999, difficult cluster(ccode_cont)


* Save coefficient and var-cov matrix *
mat betas = e(b)
mat vcovs = e(V)


* Export coefficient and covariance matrix *
preserve 
svmat betas, names(matcol)
outsheet betas* in 1 using "Data_Analysis/R/betas/betas_m2_post.txt", replace nolabel 
svmat vcovs, names(matcol)
outsheet vcovs* using "Data_Analysis/R/vcovs/vcovs_m2_post.txt", replace nolabel 
restore 









*** Try suest ***

* Model 2 *
nbreg troops lag_risk_ratio lag_best_2 $mission $contributor $dyad l_troops if $samp_res & year <= 1999, difficult 
estimates title: "Pre-2000"
estimates store pre00

nbreg troops lag_risk_ratio lag_best_2 $mission $contributor $dyad l_troops if $samp_res & year > 1999, difficult 
estimates title: "Post-2000"
estimates store post00

suest pre00 post00, vce(cluster ccode_cont)
test [pre00_troops]lag_risk_ratio==[post00_troops]lag_risk_ratio


* Model 4 *
gen inter = lag_risk_ratio * lag_best_2
nbreg troops lag_risk_ratio lag_best_2 inter $mission $contributor $dyad l_troops if $samp_res & year <= 1999, difficult 
estimates title: "Pre-2000 Interaction"
estimates store pre00_int

nbreg troops lag_risk_ratio lag_best_2 inter $mission $contributor $dyad l_troops if $samp_res & year > 1999, difficult 
estimates title: "Post-2000 Interaction"
estimates store post00_int

suest pre00_int post00_int, vce(cluster ccode_cont)
test [pre00_int_troops]lag_risk_ratio==[post00_int_troops]lag_risk_ratio
test [pre00_int_troops]inter==[post00_int_troops]inter





************************
*** Appendix Table 1 ***
************************

* Retrieve dataset *
use Data_Analysis/Mandate_Cont.dta, clear


*** All Battle Deaths ***

* Model 6: Risk Ratio * 
eststo m6: nbreg troops lag_risk_ratio lag_best_2 $mission $contributor $dyad l_troops if observe== 0 & rand1_15 == 1, cluster(ccode_cont) difficult nolog iterate(1000)


* Model 7: RR X Battle Deaths *
eststo m7: nbreg troops c.lag_risk_ratio##c.lag_best_2 $mission $contributor $dyad l_troops if observe== 0 & rand1_15 == 1, cluster(ccode_cont) difficult nolog iterate(1000)


*** Include Observer Missions ***

* Model 8: Risk Ratio, Observer * 
eststo m8: nbreg troops lag_risk_ratio lag_best_2 $mission $contributor $dyad l_troops if lag_best_2 <= 2 & rand1_15 == 1, cluster(ccode_cont) difficult nolog iterate(1000)


* Model 9: RR X Battle Deaths, Observer *
eststo m9: nbreg troops c.lag_risk_ratio##c.lag_best_2 $mission $contributor $dyad l_troops if lag_best_2 <= 2 & rand1_15 == 1, cluster(ccode_cont) difficult nolog iterate(1000)


*** 30 Contributor Sample *** 

* Model 10: Risk Ratio * 
eststo m10: nbreg troops lag_risk_ratio lag_best_2 $mission $contributor $dyad l_troops if observe== 0 & lag_best_2 <= 2 & rand1_30 == 1, cluster(ccode_cont) difficult nolog iterate(1000)


* Model 11: RR X Battle Deaths *
eststo m11: nbreg troops c.lag_risk_ratio##c.lag_best_2 $mission $contributor $dyad l_troops if observe== 0 & lag_best_2 <= 2 & rand1_30 == 1, cluster(ccode_cont) difficult nolog iterate(1000)


*** Same Continent, MP Sample ***

* Remove same continent variable for the sample * 
global dyad_2 lag_bi_trade lag_joint_ios

* Model 12: Risk Ratio *
eststo m12: nbreg troops lag_risk_ratio lag_best_2 $mission $contributor $dyad_2 l_troops if observe== 0 & lag_best_2 <= 2 & samp_contin_MP == 1, cluster(ccode_cont) difficult nolog iterate(1000)


* Model 13: RR X Battle Deaths *
eststo m13: nbreg troops c.lag_risk_ratio##c.lag_best_2 $mission $contributor $dyad_2 l_troops if observe== 0 & lag_best_2 <= 2 & samp_contin_MP == 1, cluster(ccode_cont) difficult nolog iterate(1000)


*** Ever Sent Sample ***

* Model 14: RR *
eststo m14: nbreg troops lag_risk_ratio lag_best_2 $mission $contributor $dyad l_troops if observe== 0 & lag_best_2 <= 2 & ever_sent == 1, cluster(ccode_cont) difficult nolog iterate(1000)


* Model 15: RR X Battle Deaths *
eststo m15: nbreg troops c.lag_risk_ratio##c.lag_best_2 $mission $contributor $dyad l_troops if observe== 0 & lag_best_2 <= 2 & ever_sent == 1, cluster(ccode_cont) difficult nolog iterate(1000)


esttab m6 m7 m8 m9 m10 m11 m12 m13 m14 m15 ///
using Paper/Reg_All_Robust_Final.tex, ///
se(%6.3f) b(%6.3f) label nodep ///
title(Model Robustness Checks) ///
interaction(##) ///
star(+ 0.10 * 0.05 ** 0.01) ///
addnotes("Dependent variable is troop counts.") ///
replace 


*** ZINB ***

* Model 16: Risk Ratio *
eststo m16: zinb troops lag_risk_ratio lag_best_2 $mission $contributor $dyad l_troops if observe== 0 & lag_best_2 <= 2, cluster(ccode_cont) iterate(50) inflate(lag_contributors lag_GDP_cont lag_dem_cont lag_same_continent lag_bi_trade lag_joint_ios) tech(nr) diff


* Model 17: RR X Battle Deaths *
eststo m17: zinb troops c.lag_risk_ratio##c.lag_best_2 $mission $contributor $dyad l_troops if observe== 0 & lag_best_2 <= 2, cluster(ccode_cont) iterate(50) inflate(lag_contributors lag_GDP_cont lag_dem_cont lag_same_continent lag_bi_trade lag_joint_ios) diff


esttab m16 m17 ///
using Paper/ZINB_Final.tex, ///
se(%6.3f) b(%6.3f) label nodepvars ///
title(The Effect of Risk Ratio on Contributions, Zero Inflated Models) ///
star (+ 0.10 * 0.05 ** 0.01) ///
addnotes("Dependent variables is troop counts.") ///
replace


*************************
*** Appendix Figure 1 ***
*************************

*** Model 13 ***

* Retrieve dataset *
use Data_Analysis/Mandate_Cont.dta, clear


* Set global macros *
global mission lag_contributors lag_re_hat lag_un_change
global mission2 lag_contributors lag_re_hat lag_un_change lag_troops_short 
global contributor lag_GDP_cont lag_dem_cont lag_all_troops lag_cont_troop_prop
global dyad_2 lag_bi_trade lag_joint_ios


* Model 13: RR X Battle Deaths *
gen inter = lag_risk_ratio * lag_best
nbreg troops lag_risk_ratio lag_best inter $mission $contributor $dyad_2 l_troops if observe== 0 & lag_best_2 <= 2 & samp_contin_MP == 1, cluster(ccode_cont) difficult nolog iterate(1000)


* Save dataset for rug plot * 
drop if !e(sample)
save "Data_Analysis/R/data/data_m13", replace


* Save coefficient and var-cov matrix *
mat betas = e(b)
mat vcovs = e(V)


* Export coefficient and covariance matrix *
preserve 
svmat betas, names(matcol)
outsheet betas* in 1 using "Data_Analysis/R/betas/betas_m13.txt", replace nolabel 
svmat vcovs, names(matcol)
outsheet vcovs* using "Data_Analysis/R/vcovs/vcovs_m13.txt", replace nolabel 
restore 


*****************************
*** Retrive original data ***
*****************************

* Bring in original dataset.
use Data_Analysis/Mandate_Cont.dta, clear


* Reset global macros for sets of controls 
global mission lag_contributors lag_re_hat lag_un_change
global contributor lag_GDP_cont lag_dem_cont lag_all_troops lag_cont_troop_prop
global dyad lag_same_continent lag_bi_trade lag_joint_ios


***************************************
*** Appendix Table 3: Meta Analysis ***
***************************************

**************
*** RR, 15 ***
**************

* Loop over each random sample *
local num 1 2 3 4 5 6 7 8 9 10 
foreach n of numlist `num' {
	statsby risk_beta = _b[lag_risk_ratio] risk_se = _se[lag_risk_ratio] size = e(N), by(rand`n'_15) saving(Data_Analysis/META/META_`n'_15, replace): nbreg troops lag_risk_ratio lag_best_2 $mission $contributor $dyad l_troops if observe== 0 & lag_best_2 <= 2 & rand`n'_15 == 1, cluster(ccode_cont) difficult nolog iterate(1000)
}
clear


* Append smaller datasets *
append using Data_Analysis/META/META_1_15 Data_Analysis/META/META_2_15 Data_Analysis/META/META_3_15 Data_Analysis/META/META_4_15 Data_Analysis/META/META_5_15 Data_Analysis/META/META_6_15 Data_Analysis/META/META_7_15 Data_Analysis/META/META_8_15 Data_Analysis/META/META_9_15 Data_Analysis/META/META_10_15
drop rand*
gen ID = _n
save "Data_Analysis/META/META_15.dta", replace


* Erase smaller datasets *
local met META_1_15 META_2_15 META_3_15 META_4_15 META_5_15 META_6_15 META_7_15 META_8_15 META_9_15 META_10_15
foreach x in `met' {
	erase ${cd_path}/Data_Analysis/META/`x'.dta
}

* Set meta analysis data *
meta set risk_beta risk_se, common studylabel(ID) studysize(size)


* Get overall effect *
meta summarize, common(invvariance)


**************
*** RR, 30 ***
**************

* Bring in original dataset *
use Data_Analysis/Mandate_Cont.dta, clear


* Loop over each random sample *
local num 1 2 3 4 5 6 7 8 9 10 
foreach n of numlist `num' {
statsby risk_beta = _b[lag_risk_ratio] risk_se = _se[lag_risk_ratio] size = e(N), by(rand`n'_30) saving(Data_Analysis/META/META_`n'_30, replace): nbreg troops lag_risk_ratio lag_best_2 $mission $contributor $dyad l_troops if observe== 0 & lag_best_2 <= 2 & rand`n'_30 == 1, cluster(ccode_cont) difficult nolog iterate(1000)
}
clear


* Append smaller datasets *
append using Data_Analysis/META/META_1_30 Data_Analysis/META/META_2_30 Data_Analysis/META/META_3_30 Data_Analysis/META/META_4_30 Data_Analysis/META/META_5_30 Data_Analysis/META/META_6_30 Data_Analysis/META/META_7_30 Data_Analysis/META/META_8_30 Data_Analysis/META/META_9_30 Data_Analysis/META/META_10_30
drop rand*
gen ID = [_n]
save "Data_Analysis/META/META_30.dta", replace


* Erase smaller datasets *
local met META_1_30 META_2_30 META_3_30 META_4_30 META_5_30 META_6_30 META_7_30 META_8_30 META_9_30 META_10_30
foreach x in `met' {
	erase ${cd_path}/Data_Analysis/META/`x'.dta
}


* Set meta analysis data *
meta set risk_beta risk_se, common studylabel(ID) studysize(size)


* Get overall effect *
meta summarize, common(invvariance)


***********************
*** Interaction, 15 ***
***********************

* Bring in original dataset.
use Data_Analysis/Mandate_Cont.dta, clear


* Generate interaction term *
gen inter = lag_risk_ratio * lag_best_2


* Loop over each random sample *
local num 1 2 3 4 5 6 7 8 9 10 
foreach n of numlist `num' {
statsby risk_beta = _b[lag_risk_ratio] risk_se = _se[lag_risk_ratio] risk_inter_beta = _b[inter] risk_inter_se = _se[inter] best_beta = _b[lag_best_2] best_se = _se[lag_best_2] size = e(N), by(rand`n'_15) saving(Data_Analysis/META/META_`n'_15_inter, replace): nbreg troops lag_risk_ratio lag_best_2 inter $mission $contributor $dyad l_troops if observe== 0 & lag_best_2 <= 2 & rand`n'_15 == 1, cluster(ccode_cont) difficult nolog iterate(1000)
}
clear


* Append smaller datasets *
append using Data_Analysis/META/META_1_15_inter Data_Analysis/META/META_2_15_inter Data_Analysis/META/META_3_15_inter Data_Analysis/META/META_4_15_inter Data_Analysis/META/META_5_15_inter Data_Analysis/META/META_6_15_inter Data_Analysis/META/META_7_15_inter Data_Analysis/META/META_8_15_inter Data_Analysis/META/META_9_15_inter Data_Analysis/META/META_10_15_inter
drop rand*
gen ID = _n
save "Data_Analysis/META/META_15_inter.dta", replace


* Erase smaller datasets *
local met META_1_15_inter META_2_15_inter META_3_15_inter META_4_15_inter META_5_15_inter META_6_15_inter META_7_15_inter META_8_15_inter META_9_15_inter META_10_15_inter
foreach x in `met' {
	erase ${cd_path}/Data_Analysis/META/`x'.dta
}

* Set meta analysis data *
meta set risk_beta risk_se, common studylabel(ID) studysize(size)


* Get overall effect of risk *
meta summarize, common(invvariance)


* Set meta analysis data *
meta set best_beta best_se, common studylabel(ID) studysize(size)


* Get overall effect of battle deaths *
meta summarize, common(invvariance)


* Set meta analysis data *
meta set risk_inter_beta risk_inter_se, common studylabel(ID) studysize(size)


* Get overall effect of interaction term *
meta summarize, common(invvariance)


*****************
*** Inter, 30 ***
*****************

* Bring in original dataset *
use Data_Analysis/Mandate_Cont.dta, clear


* Generate interaction term *
gen inter = lag_risk_ratio * lag_best_2


* Loop over each random sample *
local num 1 2 3 4 5 6 7 8 9 10 
foreach n of numlist `num' {
statsby risk_beta = _b[lag_risk_ratio] risk_se = _se[lag_risk_ratio] risk_inter_beta = _b[inter] risk_inter_se = _se[inter] best_beta = _b[lag_best_2] best_se = _se[lag_best_2] size = e(N), by(rand`n'_30) saving(Data_Analysis/META/META_`n'_30_inter, replace): nbreg troops lag_risk_ratio lag_best_2 inter $mission $contributor $dyad l_troops if observe== 0 & lag_best_2 <= 2 & rand`n'_30 == 1, cluster(ccode_cont) difficult nolog iterate(1000)
}
clear


* Append smaller datasets *
append using Data_Analysis/META/META_1_30_inter Data_Analysis/META/META_2_30_inter Data_Analysis/META/META_3_30_inter Data_Analysis/META/META_4_30_inter Data_Analysis/META/META_5_30_inter Data_Analysis/META/META_6_30_inter Data_Analysis/META/META_7_30_inter Data_Analysis/META/META_8_30_inter Data_Analysis/META/META_9_30_inter Data_Analysis/META/META_10_30_inter
drop rand*
gen ID = _n
save "Data_Analysis/META/META_30_inter.dta", replace


* Erase smaller datasets *
local met META_1_30_inter META_2_30_inter META_3_30_inter META_4_30_inter META_5_30_inter META_6_30_inter META_7_30_inter META_8_30_inter META_9_30_inter META_10_30_inter
foreach x in `met' {
	erase ${cd_path}/Data_Analysis/META/`x'.dta
}


* Set meta analysis data *
meta set risk_beta risk_se, common studylabel(ID) studysize(size)


* Get overall effect of risk *
meta summarize, common(invvariance)


* Set meta analysis data *
meta set best_beta best_se, common studylabel(ID) studysize(size)


* Get overall effect of battle deaths *
meta summarize, common(invvariance)


* Set meta analysis data *
meta set risk_inter_beta risk_inter_se, common studylabel(ID) studysize(size)


* Get overall effect of interaction term *
meta summarize, common(invvariance)


*************************************************
*** Appendix Table 4: Predicting Mandate Risk ***
*************************************************

* Bring in original dataset *
use Data_Analysis/Mandate_Cont.dta, clear


* Collapse dataset for mission month unit of analysis *
collapse (first) risk_ratio lag_best_2 observe lag_outcome lag_low lag_l_duration lag_mis_change lag_un_change lag_re_hat lag_GDP_host lag_host_size lag_dem_host lag_month_total lag_month_malicious lag_contributors, by(mission year month)


* Label variables for table *
label var risk_ratio "Risk Ratio"
label var lag_best_2 "Battle Deaths (Hundreds)"
label var lag_outcome "Conflict Termination"
label var lag_low "Low Activity"
label var lag_l_duration "Conflict Duration (Logged)"
label var lag_un_change "Previous UN Mission"
label var lag_re_hat "Re-hatted"
label var lag_GDP_host "Host GDP per Capita (Thousands)"
label var lag_host_size "Host Size (Million Sq. Km)"
label var lag_dem_host "Host Democracy"
label var lag_contributors "Number of Contributors"


* Model 18: Naive regression * 
eststo m18: fracreg logit risk_ratio lag_best_2 if observe == 0 & lag_best_2 <= 2, vce(cluster mission)


* Model 19: Add mission controls
eststo m19: fracreg logit risk_ratio lag_best_2 lag_contributors lag_re_hat lag_un_change lag_GDP_host lag_dem_host lag_host_size lag_outcome if observe == 0 & lag_best_2 <= 2, vce(cluster mission)


esttab m18 m19 ///
using Paper/Reg_Frac_Final.tex, ///
se(%6.3f) b(%6.3f) label nodepvars ///
title(Predicting Mandate Risk with Conflict Dynamics\label{Fraq}) ///
star(+ 0.10 * 0.05 ** 0.01) ///
addnotes("Dependent variable is risk ratio.") ///
replace 




