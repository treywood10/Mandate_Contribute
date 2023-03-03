/*	*************************************************************/
/*     	File Name:	Mandate_Contribute_MD	                    */
/*     	Date:   	November 3, 2022                            */
/*      Author: 	Robert Lee Wood III				            */
/*      Purpose:	Create Dataset for Mandate_Contribute		*/
/*      Input Files: Multiple		    						*/
/*     	Output File: Mandate_cont.dta			                */	
/*	*************************************************************/


**************
*** Set WD ***
**************

* Clear all *
clear all
frame reset


* Set global macro for working directory path *
global cd_path "/Users/treywood/Dropbox/Projects/Active_Projects/Mandate_Contribute/Make_Data"


* Set global macro for data analysis 
global da_path "/Users/treywood/Dropbox/Projects/Active_Projects/Mandate_Contribute/Data_Analysis"

* Set working directory *
cd ${cd_path}



*******************
*** IPI Dataset ***
*******************

* Flip data frames *
frame create IPI
frame change IPI


* Import IPI monthly contribution dataset *
import delimited "IPI/full_data_2020.csv", clear 


* Destring variables *
destring troops, ignore(NA) replace
replace troops = 0 if troops == .

destring civilian_police, ignore(NA) replace
replace civilian_police = 0 if civilian_police == .

destring observers, ignore(NA) replace 
replace observers = 0 if observers == .

destring total, ignore(NA) replace
replace total = 0 if total == .


* Keep variables *
keep date contributor contributor_iso3 contributor_continent contributor_region contributor_p5g4a3 mission mission_country mission_country_iso3 mission_hq mission_continent mission_region civilian_police troops observers total


* Split Date *
split date, parse(-) 
drop date
order date1 date2 date3
drop date3 // it's the day number
destring date2, replace
rename date2 month
destring date1, replace
rename date1 year

* Fix South Sudan in UNMISS *
replace mission_country = "South Sudan" if mission_country == "South Sudan'"


* Fix UNSMIL ISO to LYB *
replace mission_country_iso3 = "LBY" if mission == "UNSMIL"


* Count contributors per month 8
sort mission year month
egen contributors = count(contributor), by(mission year month)
rename contributors val
gen contributors = val/10
drop val


* Add mission COW *
kountry mission_country_iso3, from(iso3c) to(cown)
rename _COWN_ ccode_host
replace ccode_host = 626 if mission_country == "South Sudan"
replace ccode_host = 600 if mission_country == "Western Sahara"


* Add contributor COW *
kountry contributor_iso3, from(iso3c) to(cown)
rename _COWN_ ccode_cont


*** Fix Czech Repulibc ****
replace ccode_cont = 315 if contributor == "Czech Republic" & year <= 1992


* Save IPI *
save IPI.dta, replace


* Drop frame *
frame change default
frame drop IPI


************************************
*** Make Mission ID for matching ***
************************************

* Create frame *
frame create mis_ID
frame change mis_ID


* Get IPI data for missions *
use IPI.dta, clear


* Keep only unique mission *
collapse (sum) troops (first) mission_country mission_country_iso3 contributors , by(mission)
drop troops


* Generate Mission ID *
sort mission
gen mis_ID = _n


* Save mission ID *
save mis_ID.dta, replace


* Drop frame *
frame change default 
frame drop mis_ID


***********************************************
*** Get all potential mission contributions *** 
***********************************************

* Create frame *
frame create get
frame change get

* Get state month data *
use R/COW_months.dta, clear


* Expand every observation by every possible mission *
gen mis_ID = 1
gen N1 = 85
expand N1, gen(expobs)
sort ccode year month mis_ID expobs
bysort ccode year month: replace mis_ID = mis_ID[_n-1] + 1 if expobs == 1
drop N1 expobs


* Merge on mis_ID *
merge m:1 mis_ID using "mis_ID.dta"
drop _merge


* Rename ccode for contributor *
rename ccode ccode_cont


* Save *
save all_potential.dta, replace


* Drop frame *
frame change default
frame drop get


*****************************
*** Merge on TAMM Dataset *** // Use this to filter out missions that are already over
*****************************

* Create frame *
frame create TAMM
frame change TAMM


* Import TAMM dataset *
import excel "TAMM/TAMM+mission-month+v2_1.xls", sheet("Sheet1") firstrow 

* Rename ccode *
rename ccode ccode_host


* Give UNTSO a ccode_host. It will be Israel *
replace ccode_host = 666 if mission == "UNTSO"


* Give mis_ID for matching *
merge m:1 mission using "mis_ID.dta"
drop _merge
drop if mis_ID == .

* Save dataset *
save TAMM.dta, replace


* Drop frame *
frame change default
frame drop TAMM


* Open all_potential and merge *
use all_potential.dta, clear
merge m:m mis_ID year month using "TAMM.dta"
drop _merge


* Drop extra observations *
drop if yearmon == .


* Change ccode variable name *
*rename ccode ccode_cont


* Save dataset *
save all_potential.dta, replace


*******************************
*** Merge Contribution data ***
*******************************

* Merge dataset *
merge m:m ccode_cont mission year month using "IPI.dta"
drop _merge


* Remove observations outside of 1990 - 2014 *
drop if year < 1990
drop if year > 2014


*** Fix UNMIK/Serbia ***
replace ccode_host = 345 if ccode_host == 347
replace ccode_host = 347 if mission == "UNMIK" & year >= 2008


* Fix UNMEE *
replace ccode_host = 531 if ccode_host == 530


* Fix ONUCA 8
replace ccode_host = 90 if mission == "ONUCA"


* Save dataset *
save all_potential.dta, replace


*********************
*** Troop Quality ***
*********************

* Create frame *
frame create cinc
frame change cinc

* Import CINC data *
use CINC/NMC-60-abridged.dta, clear
drop if year < 1990
drop if year > 2014


* Recode -9's into missing *
recode milex (-9 = .)
recode milper (-9 = .)


* Make military expenditure into billions *
gen milex_2 = milex / 1000000
drop milex
rename milex_2 milex


* Create force quality *
gen qual = milex / milper
label var qual "Troop Quality (Billions)"
replace qual = 0 if milex == 0 & milper == 0


* Assume missing as 0 *
replace qual = 0 if qual == .


* Remove uneeded variables *
drop stateabb irst pec tpop upop cinc version milex


* Rename ccode for merge *
rename ccode ccode_cont


* Rename milper for contributor *
rename milper milper_cont
label var milper_cont "Contributor Military Personnel"


* Save dataset *
save troop_qual.dta, replace


* Drop frame *
frame change default
frame drop cinc


* Merge all potential and troop quality *
merge m:m ccode_cont year using "troop_qual.dta"
drop _merge 


* Lag variable *
bysort ccode_cont mission (year month): gen lag_milper_cont = milper_cont[_n-1] 
drop milper_cont 
label var lag_milper_cont "Contributor Military Size"


* Drop extra observations *
drop if ccode_cont == . 
drop if yearmon == .


*************************************
*** Conflict Outcome and Duration ***
*************************************

*** Add Conflict Outcome ***
// Had to hand code it since UCDP data is difficult. 

drop if year == 2015 // The outcomes database only goes to 2014

sort ccode_host year month

gen outcome = .
gen duration = .
gen startmonth = .
gen startyear = .
gen endmonth = .
gen endyear = .

// Remember, only use data from 1990 - 2014

// Haiti, 41

replace outcome = 0 if ccode_host == 41 & year < 2004 & month <= 12
replace outcome = 5 if ccode_host == 41 & year >= 2004
replace startmonth = 4 if ccode_host == 41
replace startyear = 1989 if ccode_host == 41
replace endmonth = 12 if ccode_host == 41
replace endyear = 2004 if ccode_host == 41
replace duration = (year - startyear) if year <= endyear & ccode_host == 41
replace duration = 15 if year >= endyear & ccode_host == 41

// Guatemala, 90

replace outcome = 0 if ccode_host == 90 & year < 1995 
replace outcome = 1 if ccode_host == 90 & year >= 1995
replace startmonth = 3 if ccode_host == 90
replace startyear = 1982 if ccode_host == 90
replace endmonth = 12 if ccode_host == 90
replace endyear = 1995 if ccode_host == 90
replace duration = (endyear - startyear) if ccode_host == 90

// El Salvador, 92

replace outcome = 0 if ccode_host == 92 & year <= 1991 & month <= 10
replace outcome = 1 if outcome == . & ccode_host == 92
replace startmonth = 5 if ccode_host == 92
replace startyear = 1980 if ccode_host == 92
replace endmonth = 11 if ccode_host == 92
replace endyear = 1991 if ccode_host == 92
replace duration = (year - startyear) if year <= 1991 & ccode_host == 92
replace duration = 11 if ccode_host == 92 & year >= 1992


// Macedonia, 343

replace outcome = 0 if ccode_host == 343 & year <= 2000
replace startmonth = 4 if ccode_host == 343
replace startyear = 1992 if ccode_host == 343
replace endmonth = 8 if ccode_host == 343
replace endyear = 2001 if ccode_host == 343
replace duration = (year - startyear) if ccode_host == 343

// Croatia, 344

replace outcome = 2 if ccode_host == 344 & year <= 1993
replace outcome = 1 if ccode_host == 344 & year > 1993
replace startyear = 1992 if ccode_host == 344
replace startmonth = 1 if ccode_host == 344
replace endmonth = 12 if ccode_host == 344
replace endyear = 1995 if ccode_host == 344
replace duration = (year - startyear) if ccode_host == 344 & year <= 1995
replace duration = 3 if ccode_host == 344 & year > 1995

// Bosnia and Herzegovina, 346

replace outcome = 3 if ccode_host == 346
replace startyear = 1992 if ccode_host == 346
replace startmonth = 10 if ccode_host == 346
replace endmonth = 8 if ccode_host == 346
replace endyear = 1995 if ccode_host == 346
replace duration = (endyear - startyear) if ccode_host == 346

// Serbia, 345. Gonna give it the Yugoslavia (345 data)

replace outcome = 1 if ccode_host == 345
replace startyear = 1996 if ccode_host == 345
replace startmonth = 4 if ccode_host == 345
replace endmonth = 6 if ccode_host == 345
replace endyear = 1999 if ccode_host == 345
replace duration = (endyear - startyear) if ccode_host == 345
replace duration = 3 if ccode_host == 347
replace outcome = 1 if ccode_host == 347


// Cyprus, 352. Following UN website, there is no formal resolution. The conflict began in 1960 (https://www.jstor.org/stable/j.ctt155j6v7.10)

replace outcome = 0 if ccode_host == 352
replace startyear = 1960 if ccode_host == 352
replace startmonth = 1 if ccode_host == 352
replace endmonth = 12 if ccode_host == 352 // It's still going on 
replace endyear = 2015 if ccode_host == 352 // It's still going on 
replace duration = (year - startyear) if ccode_host == 352

// Georgia, 372

replace outcome = 2 if ccode_host == 372
replace startyear = 1991 if ccode_host == 372
replace startmonth = 12 if ccode_host == 372
replace endmonth = 8 if ccode_host == 372
replace endyear = 2008 if ccode_host == 372
replace duration = (year - startyear) if ccode_host == 372 & year < 2008
replace duration = 16 if ccode_host == 372 & year >= 2008

// Mali, 432. Begin in 1990 and use outcome of 4. THat was the most recent outcome that maps onto the data here. Start year is also 1990 as it is the best year that maps onto the data

replace outcome = 4 if ccode_host == 432
replace startyear = 1990 if ccode_host == 432
replace startmonth = 6 if ccode_host == 432
replace endmonth = 12 if ccode_host == 432
replace endyear = 2014 if ccode_host == 432
replace duration = (year - startyear) if ccode_host == 432

// Cote d Ivoire, 437

replace outcome = 1 if ccode_host == 437 & year < 2011
replace outcome = 3 if ccode_host == 437 & year >=2011
replace startyear = 2004 if ccode_host == 437 & year < 2011
replace startyear = 2011 if ccode_host == 437 & year >= 2011
replace startmonth = 6 if ccode_host == 437 & year < 2011
replace startmonth = 3 if ccode_host == 437 & year >= 2011
replace endyear = 2004 if ccode_host == 437 & year < 2011
replace endyear = 2011 if ccode_host == 437 & year >= 2011
replace endmonth = 11 if ccode_host == 437 & year < 2011
replace endmonth = 4 if ccode_host == 437 & year >= 2011
replace duration = 1 if ccode_host == 437 

// Liberia, 450 

replace outcome = 1 if ccode_host == 450 
replace startyear = 1980 if ccode_host == 450 & year < 2000
replace startyear = 2000 if ccode_host == 450 & year >= 2000
replace startmonth = 4 if ccode_host == 450 & year < 2000
replace startmonth = 5 if ccode_host == 450 & year >= 2000
replace endyear = 1990 if ccode_host == 450 & year < 2000
replace endyear = 2003 if ccode_host == 450 & year >= 2000
replace endmonth = 12 if ccode_host == 450 & year < 2000
replace endmonth = 11 if ccode_host == 450 & year >= 2000
replace duration = 10 if ccode_host == 450 & year < 2000
replace duration = 3 if ccode_host == 450 & year >= 2001

// Sierra Leone, 451

replace outcome = 1 if ccode_host == 451
replace startyear = 1991 if ccode_host == 451
replace startmonth = 3 if ccode_host == 451
replace endyear = 2001 if ccode_host == 451
replace endmonth = 12 if ccode_host == 451
replace duration = (year - startyear) if ccode_host == 451 & year <= 2001
replace duration = 10 if ccode_host == 451 & year > 2001

// Central African Republic, 482. More info on the first UN mission to CAR https://www.britannica.com/place/Central-African-Republic/Authoritarian-rule-under-Kolingba

replace outcome = 1 if ccode_host == 482 & year <= 2002
replace outcome = 4 if ccode_host == 482 & year <= 2006 & year > 2003
replace outcome = 1 if ccode_host == 482 & year > 2007
replace outcome = 5 if ccode_host == 482 & year > 2013
replace startyear = 1996 if ccode_host == 482 & year <= 2002
replace startyear = 2002 if ccode_host == 482 & year > 2003 & year <= 2006
replace startyear = 2006 if ccode_host == 482 & year >= 2007
replace startmonth = 1 if ccode_host == 482 & year <= 2000
replace startmonth = 5 if ccode_host == 482 & year >= 2014
replace endyear = 1997 if ccode_host == 482 & year <= 2002
replace endyear = 2013 if ccode_host == 482 & year >= 2013
replace endmonth = 1 if ccode_host == 482 & year <= 2002
replace endmonth = 12 if ccode_host == 482 & year >= 2013
replace duration = 1 if ccode_host == 482 & year <= 2000
replace duration = 12 if ccode_host == 482 & year >= 2014

// Chad, 483 

replace outcome = 5 if ccode_host == 483 
replace startyear = 2007 if ccode_host == 483
replace startmonth = 12 if ccode_host == 483
replace endyear = 2010 if ccode_host == 483
replace endmonth = 4 if ccode_host == 483
replace duration = (year - startyear) if ccode_host == 483 & year <= 2010
replace duration = 5 if ccode_host == 483 & year > 2011

// DR Congo, 490. Start 1998 since this was the first year of conflict (earliest year). End in 2014 since there has been consistent fighting till 2014, based on UCDP. Outcome is 1 as this was the last outcome in terms of time. 

replace outcome = 0 if ccode_host == 490 & year <= 2001 & month < 9
replace outcome = 0 if ccode_host == 490 & year == 1999
replace outcome = 0 if ccode_host == 490 & year == 2000
replace outcome = 1 if outcome == . & ccode_host == 490
replace startyear = 1998 if ccode_host == 490
replace startmonth = 8 if ccode_host == 490
replace endmonth = 12 if ccode_host == 490 
replace endyear = 2014 if ccode_host == 490
replace duration = (year - startyear) if ccode_host == 490

// Uganda, 500. End at 2014 since that's where UCDP runs out. 

replace outcome = 0 if ccode_host == 500 & month < 11
replace outcome = 0 if ccode_host == 500 &  year <= 2011
replace startyear = 1971 if ccode_host == 500 
replace startmonth = 1 if ccode_host == 500
replace endmonth = 12 if ccode_host == 500
replace endyear = 2014 if ccode_host == 500
replace duration = (year - startyear) if ccode_host == 500

// Burudni, 516. 

replace outcome = 0 if ccode_host == 516 & year <= 2006 & month < 10
replace outcome = 0 if ccode_host == 516 & year == 2004
replace outcome = 0 if ccode_host == 516 & year == 2005
replace outcome = 1 if ccode_host == 516 & outcome == . 
replace startyear = 1997 if ccode_host == 516 
replace startmonth = 3 if ccode_host == 516
replace endmonth = 8 if ccode_host == 516
replace endyear = 2008 if ccode_host == 516
replace duration = (year - startyear) if ccode_host == 516 & year <= 2008
replace duration = 11 if ccode_host == 516 & year > 2008

// Rwanda, 517 

replace outcome = 0 if ccode_host == 517 & year == 1993
replace outcome = 0 if ccode_host == 517 & year == 1994 & month <= 6
replace outcome = 4 if ccode_host == 517 & year == 1994 & outcome == .
replace outcome = 4 if ccode_host == 517 & year >=1995 & year <= 2000
replace startyear = 1990 if ccode_host == 517 
replace startmonth = 10 if ccode_host == 517 
replace endmonth = 7 if ccode_host == 517
replace endyear = 1994 if ccode_host == 517
replace duration = (year - startyear) if ccode_host == 517 & year <= 1994
replace duration = 4 if ccode_host == 517 & duration == . 

// Somalia, 520

replace outcome = 0 if ccode_host == 520 & year <= 1996
replace startyear = 1991 if ccode_host == 520
replace startmonth = 9 if ccode_host == 520
replace endmonth = 12 if ccode_host == 520
replace endyear = 1996 if ccode_host == 520
replace duration = (year - startyear) if ccode_host == 520

// Eritrea, 531

replace outcome = 0 if ccode_host == 531 & year <= 2003
replace outcome = 5 if ccode_host == 531 & year == 2003 & month >= 8
replace outcome = 5 if ccode_host == 531 & year >= 2004
replace startyear = 1993 if ccode_host == 531 
replace startmonth = 12 if ccode_host == 531
replace endmonth = 8 if ccode_host == 531
replace endyear = 2003 if ccode_host == 531
replace duration = (year - startyear) if ccode_host == 531 & year <= 2003
replace duration = 10 if ccode_host == 531 & year >= 2004

// Angola, 540. Call it consistent fighting until 2002. 

replace outcome = 0 if ccode_host == 540
replace startyear = 1975 if ccode_host == 540
replace startmonth = 11 if ccode_host == 540
replace endmonth = 4 if ccode_host == 540
replace endyear = 2002 if ccode_host == 540
replace duration = (year - startyear) if ccode_host == 540

//Mozambique, 541

replace outcome = 1 if ccode_host == 541
replace startyear = 1977 if ccode_host == 541
replace startmonth = 12 if ccode_host == 541
replace endmonth = 10 if ccode_host == 541
replace endyear = 1992 if ccode_host == 541
replace duration = (endyear - startyear) if ccode_host == 541

// Western Sahara/Morocco, 600

replace outcome = 5 if ccode_host == 600
replace startyear = 1975 if ccode_host == 600
replace startmonth = 9 if ccode_host == 600
replace endmonth = 11 if ccode_host == 600
replace endyear = 1989 if ccode_host == 600 
replace duration = (endyear - startyear) if ccode_host == 600

// Sudan, 625. 2005 - 2014

replace outcome = 1 if ccode_host == 625
replace startyear = 1983 if ccode_host == 625
replace startmonth = 6 if ccode_host == 625
replace endmonth = 1 if ccode_host == 625
replace endyear = 2005 if ccode_host == 625
replace duration = (endyear - startyear) if ccode_host == 625

// South Sudan, 626. 

replace outcome = 0 if ccode_host == 626
replace startyear = 2011 if ccode_host == 626
replace startmonth = 8 if ccode_host == 626
replace endmonth = 12 if ccode_host == 626
replace endyear = 2014 if ccode_host == 626
replace duration = (year - startyear) if ccode_host == 626

// Iran, 630. 1990 - 1991

replace outcome = 5 if ccode_host == 630
replace startyear = 1972 if ccode_host == 630
replace startmonth = 5 if ccode_host == 630
replace endmonth = 4 if ccode_host == 630 
replace endyear = 1991 if ccode_host == 630
replace duration = (year - startyear) if ccode_host == 630

// Iraq, 1991 - 2003. This if for Iraq-Kuwait. Begin in 1991 with the conflict. Ended in April 1991 with the peace agreement. Started august 1990. 1 year of conflict

replace outcome = 1 if ccode_host == 645
replace startyear = 1990 if ccode_host == 645
replace startmonth = 8 if ccode_host == 645
replace endmonth = 4 if ccode_host == 645
replace endyear = 1991 if ccode_host == 645
replace duration = 1 if ccode_host == 645

// Syrain Arab. This is in response to the Yom Kipper war. I will code it as such. Peace agreement. Began October 1973. Ended May 1974. 

replace outcome = 1 if ccode_host == 652
replace startyear = 1973 if ccode_host == 652
replace startmonth = 10 if ccode_host == 652
replace endmonth = 5 if ccode_host == 652
replace endyear = 1974 if ccode_host == 652
replace duration = 1 if ccode_host == 652

// Lebanon, 660. Lebanon vs. Israel. Began March 1978. No agreement made

replace outcome = 0 if ccode_host == 660 
replace startyear = 1978 if ccode_host == 660
replace startmonth = 3 if ccode_host == 660
replace endyear = 2014 if ccode_host == 660
replace endmonth = 12 if ccode_host == 660
replace duration = (year - startyear) if ccode_host == 660

// Israel, 666. 

replace outcome = 0 if ccode_host == 666 & year <= 2012
replace outcome = 2 if ccode_host == 666 & year >= 2013
replace startyear = 1948 if ccode_host == 666
replace startmonth = 5 if ccode_host == 666
replace endmonth = 12 if ccode_host == 666
replace endyear = 2012 if ccode_host == 666
replace duration = (year - startyear) if ccode_host == 666 & year <= 2012
replace duration = 64 if ccode_host == 666 & year >= 2013

// Tajikistan, 702. 1994 - 2000

replace outcome = 0 if ccode_host == 702 & year <= 1998 
replace outcome = 3 if ccode_host == 702 & year == 1998 & month == 12
replace outcome = 3 if ccode_host == 702 & year >= 1999
replace startyear = 1992 if ccode_host == 702 & year <= 2000
replace startmonth = 5 if ccode_host == 702
replace endmonth = 11 if ccode_host == 702
replace endyear = 1998 if ccode_host == 702
replace duration = (year - startyear) if ccode_host == 702 & year <= 1998
replace duration = 6 if ccode_host == 702 & year >= 1999

// Pakistan , 770. 1990 - 2014. Following Shucksmith and White from Koops, et al 2015, ceasefire, start is august 1965, end is 7 1972

replace outcome = 2 if ccode_host == 770
replace startyear = 1965 if ccode_host == 770
replace startmonth = 8 if ccode_host == 770
replace endmonth = 7 if ccode_host == 770
replace endyear = 1972 if ccode_host == 770
replace duration = (endyear - startyear) if ccode_host == 770

// Cambodia, 811. 1991 - 1993

replace outcome = 3 if ccode_host == 811
replace startyear = 1967 if ccode_host == 811
replace startmonth = 4 if ccode_host == 811
replace endmonth = 10 if ccode_host == 811
replace endyear = 1998 if ccode_host == 811
replace duration = (year - startyear) if ccode_host == 811

// Timor-Leste, 860.  1999 - 2012. Independence from Indonesia will be a peace agreement. https://peacekeeping.un.org/mission/past/unmit/background.shtml

replace outcome = 1 if ccode_host == 860 & year <= 2005
replace startyear = 1975 if ccode_host == 860 & year <= 2005
replace startmonth = 1 if ccode_host == 860 & year <= 2005
replace endmonth = 5 if ccode_host == 860 & year <= 2005
replace endyear = 1999 if ccode_host == 860 & year <= 2005
replace duration = (endyear - startyear) if ccode_host == 860 & year <= 2005

replace outcome = 5 if ccode_host == 860 & year >= 2006
replace startyear = 2006 if ccode_host == 860 & year >= 2006
replace startmonth = 4 if ccode_host == 860 & year >= 2006
replace endmonth = 6 if ccode_host == 860 & year >= 2006
replace endyear = 2006 if ccode_host == 860 & year >= 2006
replace duration = 1 if ccode_host == 860 & year >= 2006

drop if month == . 

* Remove what I don't need right now

drop startmonth startyear endmonth endyear


*******************************************
*** Clean Dataset for mising and extras ***
*******************************************

* Drop variables *
drop ccode2 ccode3 ccode4 ccode5

* Fill in 0's *
replace troops = 0 if troops == .
replace civilian_police = 0 if civilian_police == .
replace observers = 0 if observers == .
replace total = 0 if total == .


****************
*** Outcomes ***
****************

* Currently in conflict
gen curr = 0
replace curr = 1 if outcome == 0


* Peace agreement
gen peace = 0
replace peace = 1 if outcome == 1


* Ceasefire
gen cease = 0
replace cease = 1 if outcome == 2


* Military Victory 
gen victory = 0
replace victory = 1 if outcome == 3
replace victory = 1 if outcome == 4


* Low Activity
gen low = 0
replace low = 1 if outcome == 5


*********************
*** Battle Deaths ***
*********************

* Create frame *
frame create bd
frame change bd

* Import GED data *
use GED/GEDEvent_v22_1.dta, clear


* Drop waht I don't need *
keep year country country_id date_start date_end deaths_a deaths_b deaths_civilians deaths_unknown best high low gwnoa gwnob side_a side_b


* Code by end date *
drop date_start
split date_end, parse(-)
drop date_end3
destring date_end2, replace
destring date_end1, replace
destring year, replace


* Set up variables for matching
drop year // use date end year for matching
rename date_end1 year
rename date_end2 month
order year month
drop date_end
destring country_id, replace


* Take country_id to ccode_host *
do http://www.uky.edu/~clthyn2/replace_ccode_country.do
replace ccode = 580 if country == "Madagascar (Malagasy)"
replace ccode = 572 if country == "Kingdom of eSwatini (Swaziland)"
rename ccode ccode_host

* Drop variables *
drop ccode_polity ccode_gw


* Destring gwnoa *
destring gwnoa, replace force


* Destring deaths *
destring deaths_a, replace
destring deaths_b, replace
destring deaths_civilians, replace
destring deaths_unknown, replace
destring best, replace
destring high, replace 
destring low, replace 


* Government deaths *
gen gov_death_1 = 0
replace gov_death_1 = deaths_a if gwnoa != .
gen gov_death_2 = 0
replace gov_death_2 = deaths_b if gwnob != .
gen gov_death = gov_death_1 + gov_death_2
drop gov_death_1 gov_death_2


* Rebel deaths * 
gen non_gov_death_1 = 0
replace non_gov_death_1 = deaths_a if gwnoa == .
gen non_gov_death_2 = 0
replace non_gov_death_2 = deaths_b if gwnob == . 
gen non_gov_death = non_gov_death_1 + non_gov_death_2 
drop non_gov_death_1  non_gov_death_2


* Collapse to month *
collapse (sum) deaths_civilians deaths_unknown best gov_death non_gov_death, by(ccode_host year month) 


* Drop excess observations *
drop if year < 1990
drop if year > 2014


* Save dataset * 
save GED.dta, replace


* Drop frame *
frame change default
frame drop bd 


* Merge to all_potential.dta * 
merge m:m ccode_host year month using "GED.dta"
drop _merge
drop if mis_ID == .


* Fill in 0's *
replace deaths_civilians = 0 if deaths_civilians == .
replace deaths_unknown = 0 if deaths_unknown == .
replace best = 0 if best == .
replace gov_death = 0 if gov_death == .
replace non_gov_death = 0 if non_gov_death == . 


* Move deical for best *
gen best_2 = best/100
label var best_2 "Battle Deaths (Hundreds)"


* Natural log of duration *
gen l_duration = log(duration)
drop duration

* Save dataset *
save all_potential.dta, replace


*************************
*** UN GDP per Capita *** 
*************************

* Create frame *
frame create gdp
frame change gdp


* Import dataset *
import delimited "GDP_p_cap/UNdata_Export_20211104_024755826.csv", clear // Change when change folder location
drop tablecode item


* Rename country or area for ccode *
rename countryorarea country


* Add ccodes * 
do http://www.uky.edu/~clthyn2/replace_ccode_country.do


* Manually add some codes *
replace ccode = 316 if country == "Czechia"
replace ccode = 315 if country == "Former Czechoslovakia"
replace ccode = 530 if country == "Former Ethiopia"
replace ccode = 437 if country == "CĂ´te d'Ivoire"
replace ccode = 678 if country == "Yemen: Former Yemen Arab Republic"
replace ccode = 680 if country == "Yemen: Former Democratic Yemen"
replace ccode = 625 if country == "Former Sudan"
replace ccode = 572 if country == "Kingdom of Eswatini"
replace ccode = 365 if country == "Former USSR"
replace ccode = 510 if country == "United Republic of Tanzania: Zanzibar"
replace ccode = 345 if country == "Former Yugoslavia"



* Drop Territories/Microstates *
drop if country == "Anguilla" // British Territory 
drop if country == "Aruba" // Microstate without COW
drop if country == "Bermuda" // British Territory
drop if country == "British Virgin Islands" // British Territory
drop if country == "Cayman Islands" // British Territory
drop if country == "China, Macao Special Administrative Region" // Autonomous region of China 
drop if country == "China, Hong Kong SAR" // Chinese autonomous region
drop if country == "Cook Islands" // British Territory 
drop if country == "CuraĂ§ao" // Microstate
drop if country == "Former Netherlands Antilles" // Dutch Territories
drop if country == "French Polynesia" // Microstates
drop if country == "State of Palestine" // Unrecognized in COW
drop if country == "Greenland" // Territory 
drop if country == "Montserrat" // British Territory 
drop if country == "Sint Maarten (Dutch part)" // Dutch Territory
drop if country == "New Caledonia" // French Territory 
drop if country == "Turks and Caicos Islands" // British Territory 


* Make ccode_cont and ccode_host *
gen ccode_cont = ccode 
gen ccode_host = ccode


* Save dataset *
save UN_GDP_Per_Cap.dta, replace


* Change frame *
frame change default
frame drop gdp


* Merge for contributor GDP *
merge m:m year ccode_cont using "UN_GDP_Per_Cap.dta"
drop if month == .
gen GDP_cont = value/10000
label var GDP_cont "Contributor GDP per Capita (Ten Thousand)"
drop countryorareacode country itemcode value ccode ccode_polity ccode_gw _merge


* Merge for host GDP *
merge m:m year ccode_host using "UN_GDP_Per_Cap.dta"
drop if month == . 
gen GDP_host = value/1000
label var GDP_host "Host GDP per Capita (Thousand)"
drop countryorareacode country itemcode value ccode ccode_polity ccode_gw _merge


* Save dataset *
save all_potential.dta, replace


*****************
*** Host Size ***
*****************

* Create frame *
frame create size
frame change size


* Import host size data *
import excel "Host_Size/Host_Size.xlsx", sheet("Data") firstrow clear // Change when change folder location


* Drop unneeded *
drop TimeCode GDPpercapitacurrentUSNY


* Prep for merge *
rename Time year
rename CountryName country


* Get ccodes *
do http://www.uky.edu/~clthyn2/replace_ccode_country.do


* Drop unneeded countries or territories *
drop if country == "American Samoa"
drop if country == "Aruba"
drop if country == "Bermuda"
drop if country == "British Virgin Islands"
drop if country == "Cayman Islands"
drop if country == "Channel Islands"
drop if country == "French Polynesia"
drop if country == "Gibraltar"
drop if country == "Greenland"
drop if country == "Guam"
drop if country == "Hong Kong SAR, China"
drop if country == "Isle of Man"
drop if country == "New Caledonia"
drop if country == "Virgin Islands (U.S.)"


* Others are region incomes *
drop if ccode == .


* Rename ccode for host *
rename ccode ccode_host 


* Save dataset *
save Host_Size.dta, replace


* Frame change *
frame change default
frame drop size


* Merge in host size *
merge m:m year ccode_host using "Host_Size.dta"
drop if month == .
drop _merge country
rename LandareasqkmAGLNDTOTL size
destring size, replace
gen host_size = size/1000000
drop size
label var host_size "Host Size (Thousand km)"


* save dataset *
save all_potential.dta, replace


*************
*** V-Dem ***
*************

* Create frame *
frame create dem 
frame change dem 


* Import V-Dem *
use V-Dem/V-Dem-CY-Core-v11.1.dta, clear


* Drop extra observations *
drop if year < 1990 
drop if year > 2014 


* Keep variables *
keep country_name country_text_id year COWcode v2x_polyarchy



* Fix Czech Republic *
replace COWcode = 316 if country_name == "Czech Republic" & year == 1990
replace COWcode = 316 if country_name == "Czech Republic" & year == 1991
replace COWcode = 316 if country_name == "Czech Republic" & year == 1992


* Prep for merge *
gen ccode_host = COWcode
gen ccode_cont = COWcode
drop COWcode


* Save dataset *
save V-Dem.dta, replace


* Frame change *
frame change default
frame drop dem 


* Merge dataset *
merge m:m ccode_host year using "V-Dem.dta"
drop if troops == .
rename v2x_polyarchy dem_host
drop _merge country_text_id country_name
drop if dem_host == .

merge m:m ccode_cont year using "V-Dem.dta"
drop if month == .
rename v2x_polyarchy dem_cont
drop country_name country_text_id _merge
drop if dem_cont == . // removes small state contributorss


* Drop other variables *
drop CountryCode ccode_polity ccode_gw 

* Save dataset *
save all_potential.dta, replace


**********************
*** Same Continent ***
**********************


* Get host continent *
kountry ccode_host, from(cown) geo(marc)


* kountry did not like Serbia or the Sudans *
replace GEO = "Europe" if ccode_host == 347
replace GEO = "Africa" if ccode_host == 626
rename GEO geo_host
drop NAMES_STD


* Get contributor continent *
kountry ccode_cont, from(cown) geo(marc)


* kountry did not like some countries *
replace GEO = "Europe" if ccode_cont == 347
replace GEO = "Africa" if ccode_cont == 626
replace GEO = "Europe" if ccode_cont == 341
replace GEO = "South America" if ccode_cont == 115
replace GEO = "Europe" if ccode_cont == 265
replace GEO = "Europe" if ccode_cont == 315
replace GEO = "Africa" if ccode_cont == 434
replace GEO = "Asia" if ccode_cont == 678
replace GEO = "Asia" if ccode_cont == 680
replace GEO = "Asia" if ccode_cont == 713
replace GEO = "Asia" if ccode_cont == 775
rename GEO geo_cont 
drop NAMES_STD


* Generate indicator *
gen same_continent = 0
replace same_continent = 1 if geo_host == geo_cont


* Save dataset *
save all_potential.dta, replace


****************
*** S-Scores ***
****************


* Prep all_potential.dta for merge *
gen ccode_host_2 = ccode_host 
gen ccode_cont_2 = ccode_cont 


* Fix Timor-Leste *
replace ccode_host_2 = 850 if ccode_host == 860 & year < 2002
replace ccode_cont_2 = 850 if ccode_cont == 860 & year < 2002


*** Serbia: 1999 - 2007 was altered to Yugoslavia for S-scores ***
replace ccode_cont_2 = 347 if ccode_cont == 345 & year == 1999
replace ccode_cont_2 = 347 if ccode_cont == 345 & year == 2000
replace ccode_cont_2 = 347 if ccode_cont == 345 & year == 2001
replace ccode_cont_2 = 347 if ccode_cont == 345 & year == 2002
replace ccode_cont_2 = 347 if ccode_cont == 345 & year == 2003
replace ccode_cont_2 = 347 if ccode_cont == 345 & year == 2004
replace ccode_cont_2 = 347 if ccode_cont == 345 & year == 2005
replace ccode_cont_2 = 347 if ccode_cont == 345 & year == 2006
replace ccode_cont_2 = 347 if ccode_cont == 345 & year == 2007

replace ccode_host_2 = 347 if ccode_host == 345 & year == 1999
replace ccode_host_2 = 347 if ccode_host == 345 & year == 2000
replace ccode_host_2 = 347 if ccode_host == 345 & year == 2001
replace ccode_host_2 = 347 if ccode_host == 345 & year == 2002
replace ccode_host_2 = 347 if ccode_host == 345 & year == 2003
replace ccode_host_2 = 347 if ccode_host == 345 & year == 2004
replace ccode_host_2 = 347 if ccode_host == 345 & year == 2005
replace ccode_host_2 = 347 if ccode_host == 345 & year == 2006
replace ccode_host_2 = 347 if ccode_host == 345 & year == 2007

*** Czech Republic is Czechoslovakia from 1990 - 1992 *** 
replace ccode_cont_2 = 315 if ccode_cont == 316 & year == 1990
replace ccode_cont_2 = 315 if ccode_cont == 316 & year == 1991
replace ccode_cont_2 = 315 if ccode_cont == 316 & year == 1992

replace ccode_host_2 = 315 if ccode_host == 316 & year == 1990
replace ccode_host_2 = 315 if ccode_host == 316 & year == 1991
replace ccode_host_2 = 315 if ccode_host == 316 & year == 1992


* Create frame *
frame create s
frame change s


* Import data *
use S-Score/atop-sscorev5.dta, clear


* Rename cow codes *
rename ccode1 ccode_cont
rename ccode2 ccode_host 


* Fix ccodes for Serbia *
replace ccode_cont = 347 if ccode_cont == 345 & year >= 1999 & year <=2007
replace ccode_host = 347 if ccode_host == 345 & year >= 1999 & year <=2007


* Make S-Scores into directed dyads *
expand 2, gen(dup)

gen ccode_cont_2 = ccode_cont if dup == 0
gen ccode_host_2 = ccode_host if dup == 0
replace ccode_cont_2 = ccode_host if dup == 1
replace ccode_host_2 = ccode_cont if dup == 1

drop ccode_cont ccode_host

rename ccode_host_2 ccode_host
rename ccode_cont_2 ccode_cont 


*** TLE gets indonesia S-scores untill 2002 ***

gen ccode_host_2 = ccode_host 
replace ccode_host_2 = 850 if ccode_host == 860 & year < 2002

gen ccode_cont_2 = ccode_cont
replace ccode_cont_2 = 850 if ccode_cont == 860 & year < 2002


*** Czech Republic 1990 - 1992
replace ccode_cont_2 = 315 if ccode_cont == 316 & year == 1990
replace ccode_cont_2 = 315 if ccode_cont == 316 & year == 1991
replace ccode_cont_2 = 315 if ccode_cont == 316 & year == 1992

replace ccode_host_2 = 315 if ccode_host == 316 & year == 1990
replace ccode_host_2 = 315 if ccode_host == 316 & year == 1991
replace ccode_host_2 = 315 if ccode_host == 316 & year == 1992


*** Serbia 1999-2007 ***
replace ccode_cont_2 = 347 if ccode_cont == 345 & year == 1999
replace ccode_cont_2 = 347 if ccode_cont == 345 & year == 2000
replace ccode_cont_2 = 347 if ccode_cont == 345 & year == 2001
replace ccode_cont_2 = 347 if ccode_cont == 345 & year == 2002
replace ccode_cont_2 = 347 if ccode_cont == 345 & year == 2003
replace ccode_cont_2 = 347 if ccode_cont == 345 & year == 2004
replace ccode_cont_2 = 347 if ccode_cont == 345 & year == 2005
replace ccode_cont_2 = 347 if ccode_cont == 345 & year == 2006
replace ccode_cont_2 = 347 if ccode_cont == 345 & year == 2007

replace ccode_host_2 = 347 if ccode_host == 345 & year == 1999
replace ccode_host_2 = 347 if ccode_host == 345 & year == 2000
replace ccode_host_2 = 347 if ccode_host == 345 & year == 2001
replace ccode_host_2 = 347 if ccode_host == 345 & year == 2002
replace ccode_host_2 = 347 if ccode_host == 345 & year == 2003
replace ccode_host_2 = 347 if ccode_host == 345 & year == 2004
replace ccode_host_2 = 347 if ccode_host == 345 & year == 2005
replace ccode_host_2 = 347 if ccode_host == 345 & year == 2006
replace ccode_host_2 = 347 if ccode_host == 345 & year == 2007


* Save dataset *
save S-Scores.dta, replace


* Frame change *
frame change default 
frame drop s


* Drop states that also host *
drop if ccode_cont == ccode_host


* Merge datasets *
merge m:m year ccode_cont_2 ccode_host_2 using S-Scores.dta
drop if best == . 
drop _merge dup versionnmc versionatop versioncow cabb2 cabb1 dyad


* Save dataset *
save all_potential.dta, replace


***********************
*** Bilateral Trade ***
***********************

* Timor-Leste gets trade in 2002. Part of indonesia until 2002. Give LTE indonesia's trade until 2002 *

replace ccode_host_2 = 850 if ccode_host == 860 & year < 2002

replace ccode_cont_2 = 850 if ccode_cont == 860 & year < 2002

* Serbia: 1999 - 2007 was altered to Yugoslavia for trade *

replace ccode_cont_2 = 347 if ccode_cont == 345 & year == 1999
replace ccode_cont_2 = 347 if ccode_cont == 345 & year == 2000
replace ccode_cont_2 = 347 if ccode_cont == 345 & year == 2001
replace ccode_cont_2 = 347 if ccode_cont == 345 & year == 2002
replace ccode_cont_2 = 347 if ccode_cont == 345 & year == 2003
replace ccode_cont_2 = 347 if ccode_cont == 345 & year == 2004
replace ccode_cont_2 = 347 if ccode_cont == 345 & year == 2005
replace ccode_cont_2 = 347 if ccode_cont == 345 & year == 2006
replace ccode_cont_2 = 347 if ccode_cont == 345 & year == 2007

replace ccode_host_2 = 347 if ccode_host == 345 & year == 1999
replace ccode_host_2 = 347 if ccode_host == 345 & year == 2000
replace ccode_host_2 = 347 if ccode_host == 345 & year == 2001
replace ccode_host_2 = 347 if ccode_host == 345 & year == 2002
replace ccode_host_2 = 347 if ccode_host == 345 & year == 2003
replace ccode_host_2 = 347 if ccode_host == 345 & year == 2004
replace ccode_host_2 = 347 if ccode_host == 345 & year == 2005
replace ccode_host_2 = 347 if ccode_host == 345 & year == 2006
replace ccode_host_2 = 347 if ccode_host == 345 & year == 2007

* Czech Republic is Czechoslovakia from 1990 - 1992 for trade *

replace ccode_cont_2 = 315 if ccode_cont == 316 & year == 1990
replace ccode_cont_2 = 315 if ccode_cont == 316 & year == 1991
replace ccode_cont_2 = 315 if ccode_cont == 316 & year == 1992

replace ccode_host_2 = 315 if ccode_host == 316 & year == 1990
replace ccode_host_2 = 315 if ccode_host == 316 & year == 1991
replace ccode_host_2 = 315 if ccode_host == 316 & year == 1992


* Create frame *
frame create trade
frame change trade


* Import dataset *
import delimited "Trade/Dyadic_COW_4.0.csv", clear // Change when change folder location


* Drop unneeded years *
drop if year < 1990
rename ccode1 ccode_cont
rename ccode2 ccode_host 


* Need to make undirected dyads *
expand 2, gen(dup)

gen ccode_cont_2 = ccode_cont if dup == 0
gen ccode_host_2 = ccode_host if dup == 0
replace ccode_cont_2 = ccode_host if dup == 1
replace ccode_host_2 = ccode_cont if dup == 1

drop ccode_cont ccode_host

rename ccode_host_2 ccode_host
rename ccode_cont_2 ccode_cont 

* Prep to merge to fix the below issues with a few cases

* Timor-Leste gets trade in 2002. Part of indonesia until 2002. Give LTE indonesia's trade until 2002 *

gen ccode_host_2 = ccode_host 
replace ccode_host_2 = 850 if ccode_host == 860 & year < 2002

gen ccode_cont_2 = ccode_cont
replace ccode_cont_2 = 850 if ccode_cont == 860 & year < 2002

* Serbia: 2002 - 2007 was altered to Yugoslavia for trade *
replace ccode_cont_2 = 347 if ccode_cont == 345 & year == 1999
replace ccode_cont_2 = 347 if ccode_cont == 345 & year == 2000
replace ccode_cont_2 = 347 if ccode_cont == 345 & year == 2001
replace ccode_cont_2 = 347 if ccode_cont == 345 & year == 2002
replace ccode_cont_2 = 347 if ccode_cont == 345 & year == 2003
replace ccode_cont_2 = 347 if ccode_cont == 345 & year == 2004
replace ccode_cont_2 = 347 if ccode_cont == 345 & year == 2005
replace ccode_cont_2 = 347 if ccode_cont == 345 & year == 2006
replace ccode_cont_2 = 347 if ccode_cont == 345 & year == 2007

replace ccode_host_2 = 347 if ccode_host == 345 & year == 1999
replace ccode_host_2 = 347 if ccode_host == 345 & year == 2000
replace ccode_host_2 = 347 if ccode_host == 345 & year == 2001
replace ccode_host_2 = 347 if ccode_host == 345 & year == 2002
replace ccode_host_2 = 347 if ccode_host == 345 & year == 2003
replace ccode_host_2 = 347 if ccode_host == 345 & year == 2004
replace ccode_host_2 = 347 if ccode_host == 345 & year == 2005
replace ccode_host_2 = 347 if ccode_host == 345 & year == 2006
replace ccode_host_2 = 347 if ccode_host == 345 & year == 2007


* Czech Republic is Czechoslovakia from 1990 - 1992 for trade *
replace ccode_cont_2 = 315 if ccode_cont == 316 & year == 1990
replace ccode_cont_2 = 315 if ccode_cont == 316 & year == 1991
replace ccode_cont_2 = 315 if ccode_cont == 316 & year == 1992

replace ccode_host_2 = 315 if ccode_host == 316 & year == 1990
replace ccode_host_2 = 315 if ccode_host == 316 & year == 1991
replace ccode_host_2 = 315 if ccode_host == 316 & year == 1992


* Drop unneeded variables *
drop dup version source2 source1 china_alt_flow2 china_alt_flow1 bel_lux_alt_flow2 bel_lux_alt_flow1 tradedip trdspike dip2 dip1 spike2 spike1 smoothflow1 smoothflow2 flow1 flow2
rename smoothtotrade bi_trade


* Save dataset *
save trade.dta, replace


* Change frame *
frame change default
frame drop trade 


* Merge dataset *
merge m:m year ccode_cont_2 ccode_host_2 using "trade.dta"
drop if month == .
drop _merge 


* Move decimal of bi-trade *
gen bi_trade2 = bi_trade/1000
drop bi_trade
rename bi_trade2 bi_trade
label var bi_trade "Trade in Millions"


**********************
*** Drop Variables ***
**********************

drop version importer1 importer2 au_coop eu_coop undp_coop ecowas_coop jmc_coop othermission_coop oas_coop osce_coop cis_coop coop_other ccode_host_2 ccode_cont_2 pkratio vlimratio pbratio factor1 factor2 factor3 contributor_continent mission_continent outcome s_wt_atop kappa_atop pi_atop mis_ID


******************
*** Risk Ratio ***
******************

* Risky count *
gen risky_count = peaceag_cease_monitor + buffer_monitor + liaise_warpart + peaceag_cease_assist + humrts_monitor + refugees_monitor + humrts_protect + children_protect + women_protect + prociv + unpersonnel_protect + demining_assist + refugees_assist + humaid_assist + humpersonnel_protect + borders_monitor + ch7 + securitysectorreform_assist + policereform_assist + police_monitor + police_jointpatrols + ddr_monitor + ddr_assist


* Less risky count *
gen less_risky_count = weaponstrade_monitor + weaponsembargo_monitor + goodoffices + cargoinspections + resources_monitor + election_monitor + election_security + election_assist + govcap_assist + govpolicies_assist + cultural_pres + qip_assist + justice_assist + reconciliation + justice_warcrim + mission_pr + freepress


* Risk ratio *
gen risk_ratio = risky_count/(less_risky_count + risky_count)


* Less risk ratio *
gen less_risk_ratio = less_risky_count / (less_risky_count + risky_count)


* Drop variables *
drop risky_count less_risky_count


*********************************
*** Make Continent, MP Sample ***
*********************************

* Major Power Dummy *
gen MP = 0
replace MP = 1 if ccode_cont == 2
replace MP = 1 if ccode_cont == 200
replace MP = 1 if ccode_cont == 220
replace MP = 1 if ccode_cont == 255 & year >= 1991
replace MP = 1 if ccode_cont == 365 
replace MP = 1 if ccode_cont == 710 
replace MP = 1 if ccode_cont == 740 & year >= 1991


* Sample Dummy * 
gen samp_contin_MP = 0 
replace samp_contin_MP = 1 if same_continent == 1
replace samp_contin_MP = 1 if MP == 1
label var samp_contin_MP "Continent, MP, Cont. Sample"
drop MP


*********************************
*** Mark UN Observer Missions ***
*********************************

// Observer missions based on their name and mandate 

gen observe = 0

// BINUB was a special political mission
replace observe = 1 if mission == "BINUB"

// MINUCI was a special political mission 
replace observe = 1 if mission == "MINUCI"

// MINUGUA was a small verification mission
replace observe = 1 if mission == "MINUGUA"

// Always an observer mission 
replace observe = 1 if mission == "MIPONUH"

// MONUA was always an observer mission 
replace observe = 1 if mission == "MONUA"

// MONUC was an observer mission, but had a rapidly increasing mandate
// that led to MONUSCO
// Began as an observer mission in 1999, but expanded in February 2000
replace observe = 1 if mission == "MONUC" & year == 1999
replace observe = 1 if mission == "MONUC" & year == 2000 & month < 2

// Always an observer mission 
replace observe = 1 if mission == "ONUSAL"

// Always an observer mission 
replace observe = 1 if mission == "UNOMSIL"

// UNAVEM II was an observer/small mission 
replace observe = 1 if mission == "UNAVEM II"

// UNIIMOG was an observer mission 
replace observe = 1 if mission == "UNIIMOG"

// Began as an observer mission, but had a military authorization beginning
// in February 1993
replace observe = 1 if mission == "UNIKOM" & year <= 1992
replace observe = 1 if mission == "UNIKOM" & year == 1993 & month < 2

// UNMIBH is an observer mission 
replace observe = 1 if mission == "UNMIBH"

// Always an observer mission 
replace observe = 1 if mission == "UNMIK"

// UNMIT was an observer mission 
replace observe = 1 if mission == "UNMIT"

// Always an observer mission 
replace observe = 1 if mission == "UNMOP"

// Always an observer mission
replace observe = 1 if mission == "UNMOT"

// Always an observer mission 
replace observe = 1 if mission == "UNOMIG"

// Always an observer mission
replace observe = 1 if mission == "UNOMIL"

// Always an observer mission 
replace observe = 1 if mission == "UNOMSIL"

// Always an observer mission 
replace observe = 1 if mission == "UNOMUR"

// Always an observer mission 
replace observe = 1 if mission == "UNPSG"

// Always an observer mission 
replace observe = 1 if mission == "UNSMIS"


*********************************
*** Collapse Conflict Outcome ***
*********************************

* Peace Agreement, Ceasefire, and Victory Have Equal Coefficients. Collapse *
gen outcome = 0
bysort ccode_cont mission (year month): replace outcome = 1 if peace == 1
bysort ccode_cont mission (year month): replace outcome = 1 if cease == 1
bysort ccode_cont mission (year month): replace outcome = 1 if victory == 1
label var outcome "Conflict Termination"
drop peace cease victory


* Collapse into not current and current conflicts *
gen ended = 0
bysort ccode_cont mission (year month): replace ended = 1 if outcome == 1
bysort ccode_cont mission (year month): replace ended = 1 if low == 1
label var ended "Conflict Termination"



* Save dataset *
save all_potential.dta, replace

*************************
*** Direct Contiguity ***
*************************

* Create frame *
frame create border 
frame change border 


* Import dataset *
use Contiguity/contdird.dta, clear


* Drop variables *
drop version state1ab state2ab dyad


* Rename for merging *
rename state1no ccode_cont 
rename state2no ccode_host


* Save dataset *
save dir_cont.dta, replace


* Frame change *
frame change default
frame drop border


* Merge datasets *
merge m:m ccode_cont ccode_host year using "dir_cont.dta"
drop _merge 
drop if month == .


* Create border indicator *
gen border = 0
replace border = 1 if conttype == 1
replace border = 1 if conttype == 2
replace border = 1 if conttype == 3
drop conttype


*****************************************
*** Peacekeeper Deaths by Contributor ***
*****************************************

* Create frame *
frame create pko 
frame change pko 


* Import data *
use PKO_Deaths/Contigent-mission-month_data.dta, clear


* Rename variables for merge *
rename Cowcontr ccode_cont 
rename Year year
rename Month month 
rename Mission mission 


* Save dataset *
save PKO_deaths.dta, replace


* Frame change *
frame change default 
frame drop pko


* Fix for merge *
gen mission2 = mission
replace mission2 = "UNAVEM" if mission == "UNAVEM I"
replace mission2 = "UNVAEM" if mission == "UNAVEM II"
rename mission mission_orig
rename mission2 mission 


* Merge dataset *
merge m:m year month mission ccode_cont using "PKO_deaths.dta"
drop _merge


* Drop observations *
drop if year < 1990
drop if year > 2014


* Drop extras from non-included misisons *
drop if ccode_cont == .
drop if ccode_host == .


* Fix missions *
drop mission
rename mission_orig mission


* Fill missings with 0's *
local fats Illness Accident Malicious Other Total Mil Obs Police Local International Otherstaff
foreach x of varlist `fats' {
	replace `x' = 0 if `x' == .
}


* Drop other variable *
drop Nationality


* Rename capitals *
rename Illness illness
rename Accident accident
rename Malicious malicious
rename Other other 
rename Total total_f
rename Mil mil 
rename Obs obs 
rename Police police 
rename Local locals
rename International international 
rename Otherstaff otherstaff


* Save dataset *
save all_potential.dta, replace

local fats illness accident malicious other total_f mil obs police locals international otherstaff
foreach x of varlist `fats' {
	replace `x' = 0 if `x' == .
}


*** Loop to get fatalities info ***
cd ${cd_path} 

local i = 2

while `i' <= 990 {
	use all_potential.dta, clear // Change when you change folder locations
	drop if ccode_cont != `i'
	keep year month mission contributor ccode_cont contributor_iso3 illness accident malicious other total_f mil obs police locals international otherstaff
	if _N > 0 {
	local PKO_fats illness accident malicious other total_f mil obs police locals international otherstaff
	foreach x of varlist `PKO_fats' {
		*** Local for lags 1 - 6 ***
		local ord 1 2 3 4 5 6
		
		*** Make lags ***
		foreach t in `ord' {
		bysort ccode_cont mission (year month): gen lag_`t'_`x' = `x'[_n-`t']
		label var lag_`t'_`x' "Lag `x' T - `t'"
		}
		
		*** Make the 1 month total of all missions ***
		bysort ccode_cont year month: egen lag_month_`x' = total(lag_1_`x')	
		bysort ccode_cont year month: replace lag_month_`x' = . if lag_1_`x' == .
		label var lag_month_`x' "Monthly Contributor Fatalities for `x'"
		
		*** Sum fatalities to make the monthly total variables ***
		bysort ccode_cont mission (year month): gen sum_1_3_lag_`x' = lag_1_`x' + lag_2_`x' + lag_3_`x'
		bysort ccode_cont mission (year month): gen sum_1_6_lag_`x' = lag_1_`x' + lag_2_`x' + lag_3_`x' + lag_4_`x' + lag_5_`x' + lag_6_`x'
		
		*** Make total fatalities variable for 3 months *** 
		bysort ccode_cont year month: egen lag_three_month_`x' = total(sum_1_3_lag_`x')
		bysort ccode_cont year month: replace lag_three_month_`x' = . if lag_3_`x' == . 
		label var lag_three_month_`x' "Three Month Contributor Fatalities for `x'"
		
		*** Make totat fatalities variable for 6 months *** 
		bysort ccode_cont year month: egen lag_six_month_`x' = total(sum_1_6_lag_`x')
		bysort ccode_cont year month: replace lag_six_month_`x' = . if lag_6_`x' == . 
		label var lag_six_month_`x' "Six Month Contributor Fatalities for `x'"

		*** Fill in totals for new missions *** 
		bysort ccode_cont year month (lag_month_`x'): replace lag_month_`x' = lag_month_`x'[_n-1] if lag_month_`x' == .
		bysort ccode_cont year month (lag_three_month_`x'): replace lag_three_month_`x' = lag_three_month_`x'[_n-1] if lag_three_month_`x' == .
		bysort ccode_cont year month (lag_six_month_`x'): replace lag_six_month_`x' = lag_six_month_`x'[_n-1] if lag_six_month_`x' == .
		
		* Drop Extra Variables *
		drop lag_1_`x' lag_2_`x' lag_3_`x' lag_4_`x' lag_5_`x' lag_6_`x' sum_1_3_lag_`x' sum_1_6_lag_`x'
	}
	
	*** Save individual files *** 
	duplicates drop
	save Loops/fats`i', replace
	local i = `i' + 1 
	}
	else {
		local i = `i' + 1
	} 
}
clear

* Append the little files into one file *

cd "${cd_path}/Loops" // Change when you change folder locations
! ls *.dta >filelist.txt

file open myfile using filelist.txt, read

file read myfile line
use `line'
save cont_fats, replace

file read myfile line
while r(eof)==0 { /* while you're not at the end of the file */
	append using `line'
	file read myfile line
}
file close myfile
save cont_fats, replace


* Set WD again *
cd "${cd_path}" 


* Bring back original dataset *
use all_potential.dta, clear


* Merge Fatalities with original dataset *
merge m:m year month mission ccode_cont using "Loops/cont_fats.dta"
drop _merge


* Save dataset *
save all_potential.dta, replace


********************************
*** Total Mission Fatalities ***
********************************

* Frame create *
frame create pko_d
frame change pko_d 


* Import pko death dataset *
use PKO_Deaths/Contigent-mission-month_data.dta, clear


* Make mission month fatalities *
collapse (sum) Illness Accident Malicious Other Total Mil Obs Police Local International Otherstaff, by(Mission Year Month)


* Prep data *
rename Illness illness_m
rename Accident accident_m
rename Malicious malicious_m
rename Other other_m
rename Total total_m
rename Mil mil_m
rename Obs obs_m
rename Police police_m
rename Local local_m
rename International international_m
rename Otherstaff otherstaff_m
rename Year year 
rename Month month 
rename Mission mission

* Save dataset *
save PKO_deaths_mission.dta, replace 


* Frame change *
frame change default 
frame drop pko_d 


* Prep for merge *
gen mission2 = mission
replace mission2 = "UNAVEM" if mission == "UNAVEM I"
replace mission2 = "UNVAEM" if mission == "UNAVEM II"
rename mission mission_orig
rename mission2 mission 

* Merge datasets *
merge m:m mission year month using "PKO_deaths_mission.dta"
drop _merge 


* Fix missions *
drop mission
rename mission_orig mission


* Drop observations *
drop if year < 1990
drop if year > 2014


* Drop extras from non-included misisons *
drop if ccode_cont == .
drop if ccode_host == .


* Fill in 0's for mission deaths *
local fats illness_m accident_m malicious_m other_m total_m mil_m obs_m police_m local_m international_m otherstaff_m
foreach x of varlist `fats' {
	replace `x' = 0 if `x' == .
}


* Save dataset *
save all_potential.dta, replace


*****************
*** Joint IOs ***
*****************

* Create frame *
frame create IOs
frame change IOs 


* Import dataset *
import delimited "Joint_IOs/dyadic_formatv3.csv", clear // Change when move folder


* Drop if year is less than 1990 *
drop if year < 1990


* Rename variables *
rename ccode1 ccode_cont
rename ccode2 ccode_host


* Make Joint IOs into directed dyads *
expand 2, gen(dup)

gen ccode_cont_2 = ccode_cont if dup == 0
gen ccode_host_2 = ccode_host if dup == 0
replace ccode_cont_2 = ccode_host if dup == 1
replace ccode_host_2 = ccode_cont if dup == 1

drop ccode_cont ccode_host

rename ccode_host_2 ccode_host
rename ccode_cont_2 ccode_cont 

order ccode_cont country1 ccode_host country2
drop dup

* Create joint IOs measure *
local ios aalco aalco aata acdt acpeu anzus ap apt baltbat bc benelux bsec caci cbss ccnr ccomm cento chstea cis coe comsec eapc eipa esa entente g15 g24 g3 glacsec iadefb iahc iarhc iasaj icamo iccilmb icivdo idc iocom iomig itto iupip loas lon mfo nam nato ncm nordc oas oau ocas ocr opanal osce paho pca pif pmaesa rcc riogroup repcom saarc schengen seato spc un usp wcdc weu wpact wassen au csto corg eip iorarc um swpd sco recsa bobp cica fec iru iuic pap rcfc segib acct aci acml acso afte arcal asatp ascbc asef amcc aralsea articc bcsc biisef bionet cab cabi caipa cames cbi celc cmhasg colombo confejes cosave cpab cpsc ctcaf cwgc cxc danube eccd efcc efilwc embc embl emppo eso etf eufmd euratom gbact gcrsnc gef iabe iabath iaci iacs iacss iacw iaea iaias iamlo iaphy iaradio iaruhr iatsj ibe ibi ibier ibpmp icao iccrom iccs icdr ices ichrb icmmp icprp icri icrpbc ictm iec ies iexb iho iie ilo imbslav imc imi incap infsmk interpol ioez iolm ioph ipedi ipentc iphyl irlcs iro isa ishrest isupt itcc itcle iuplaw jalaao jinr jnolcrh lacac lacp laeo laiec latin lcbc mcpttc mcwcasm mwn montreal nappo nasco ncrr neafc npafc npfsc ntsc occedca oic omdkr oslo ospar paigh pc pcsp pices pics psnarco rcaela rimmo rioppah sacep scaf sch seameo swapu turksoy unesco vasab waec wahc who wmo alsf amcow cbfp cslf cfrn geo ghsi iaii icptu igcc inpfc irena isuc waho papu maocn marri npi nwhf africarice borgip cilss euramet icfam iifeo iiwee isrbc itro nafo nvc oiv pibac valdivia unidroit aaaid aacb aaro aatpo abeda abepseac acc acp acs acssrb acu afesd afeximb afgec afpu afrand agc agpundo aic aidc aido aioec aipo alo amco amf amipo amptu amsc amu aoad aocrs aomr aopu apcc apec apfic apibd apo appa aptu arc aripo arpu asblac ascrubber asean asecna aspac ato atpc avrdc afdb afropda africare andean asdb bipm bis bndp bonn caad caarc cacb caec caecc camrsd camsf caricom carifta carii catc ccom ccpa cdb ceao cec ceepn cefta cei cemac cepgl cern cfatf cfc cifc cima cmaec cmaoc cmea comesa coptac cpu cto comab dbgls dlcoea eacm eacso eadb eapo ebrd ecb ecca eccas eccb eccm eccpif eco ecowas ecpta ecsc eec efta eib eldo emb emi epa epfsc epo esro eu eurocontrol eurofima euromet fao fdiplac gatt gcc goic hcpil iacb iadb iafc iaic iaigc ialong iara ias iatb iattc iba ibcs ibec ibrd icac icai icc iccec icco iccslt icnc icnwaf icse icseaf icsg icfo ichemo icomo iea ifad ifc ifca igad igc iia iicom iif ijo ilzsg imf imo imso infofish inro insg intelsat ioathre iooc iopcf iocc ipc ipi iprizec irsg isb isdb itc itpa itu itvrc iupct iupnvp iupr ivwo iwsg iwhale iocean lafdo lafta laia lgida miga mru mercosur nacap nafta nctr ndf nerc nib nrc oapec ocam oecd oecs oeec opec otif pahc pcb ped piarc pipd ptasea puasp rascom radiou saafa sacu sadc sadcc sami sartc sca sela sica sieca sittdec srdo sugu tcrmg uasc ubec udeac uemoa uiucv ukdwd umac umoa unido upu wco wipo wnf wto wtouro acwl afspc aitic bs d8 eac eaec epu eria afristat omvg

foreach x in `ios' {
	replace `x' = 0 if `x' != 1
}

gen joint_ios = aalco + aalco + aata + acdt + acpeu + anzus + ap + apt + baltbat + bc + benelux + bsec + caci + cbss + ccnr + ccomm + cento + chstea + cis + coe + comsec + eapc + eipa + esa + entente + g15 + g24 + g3 + glacsec + iadefb + iahc + iarhc + iasaj + icamo + iccilmb + icivdo + idc + iocom + iomig + itto + iupip + loas + lon + mfo + nam + nato + ncm + nordc + oas + oau + ocas + ocr + opanal + osce + paho + pca + pif + pmaesa + rcc + riogroup + repcom + saarc + schengen + seato + spc + un + usp + wcdc + weu + wpact + wassen + au + csto + corg + eip + iorarc + um + swpd + sco + recsa + bobp + cica + fec + iru + iuic + pap + rcfc + segib + acct + aci + acml + acso + afte + arcal + asatp + ascbc + asef + amcc + aralsea + articc + bcsc + biisef + bionet + cab + cabi + caipa + cames + cbi + celc + cmhasg + colombo + confejes + cosave + cpab + cpsc + ctcaf + cwgc + cxc + danube + eccd + efcc + efilwc + embc + embl + emppo + eso + etf + eufmd + euratom + gbact + gcrsnc + gef + iabe + iabath + iaci + iacs + iacss + iacw + iaea + iaias + iamlo + iaphy + iaradio + iaruhr + iatsj + ibe + ibi + ibier + ibpmp + icao + iccrom + iccs + icdr + ices + ichrb + icmmp + icprp + icri + icrpbc + ictm + iec + ies + iexb + iho + iie + ilo + imbslav + imc + imi + incap + infsmk + interpol + ioez + iolm + ioph + ipedi + ipentc + iphyl + irlcs + iro + isa + ishrest + isupt + itcc + itcle + iuplaw + jalaao + jinr + jnolcrh + lacac + lacp + laeo + laiec + latin + lcbc + mcpttc + mcwcasm + mwn + montreal + nappo + nasco + ncrr + neafc + npafc + npfsc + ntsc + occedca + oic + omdkr + oslo + ospar + paigh + pc + pcsp + pices + pics + psnarco + rcaela + rimmo + rioppah + sacep + scaf + sch + seameo + swapu + turksoy + unesco + vasab + waec + wahc + who + wmo + alsf + amcow + cbfp + cslf + cfrn + geo + ghsi + iaii + icptu + igcc + inpfc + irena + isuc + waho + papu + maocn + marri + npi + nwhf + africarice + borgip + cilss + euramet + icfam + iifeo + iiwee + isrbc + itro + nafo + nvc + oiv + pibac + valdivia + unidroit + aaaid + aacb + aaro + aatpo + abeda + abepseac + acc + acp + acs + acssrb + acu + afesd + afeximb + afgec + afpu + afrand + agc + agpundo + aic + aidc + aido + aioec + aipo + alo + amco + amf + amipo + amptu + amsc + amu + aoad + aocrs + aomr + aopu + apcc + apec + apfic + apibd + apo + appa + aptu + arc + aripo + arpu + asblac + ascrubber + asean + asecna + aspac + ato + atpc + avrdc + afdb + afropda + africare + andean + asdb + bipm + bis + bndp + bonn + caad + caarc + cacb + caec + caecc + camrsd + camsf + caricom + carifta + carii + catc + ccom + ccpa + cdb + ceao + cec + ceepn + cefta + cei + cemac + cepgl + cern + cfatf + cfc + cifc + cima + cmaec + cmaoc + cmea + comesa + coptac + cpu + cto + comab + dbgls + dlcoea + eacm + eacso + eadb + eapo + ebrd + ecb + ecca + eccas + eccb + eccm + eccpif + eco + ecowas + ecpta + ecsc + eec + efta + eib + eldo + emb + emi + epa + epfsc + epo + esro + eu + eurocontrol + eurofima + euromet + fao + fdiplac + gatt + gcc + goic + hcpil + iacb + iadb + iafc + iaic + iaigc + ialong + iara + ias + iatb + iattc + iba + ibcs + ibec + ibrd + icac + icai + icc + iccec + icco + iccslt + icnc + icnwaf + icse + icseaf + icsg + icfo + ichemo + icomo + iea + ifad + ifc + ifca + igad + igc + iia + iicom + iif + ijo + ilzsg + imf + imo + imso + infofish + inro + insg + intelsat + ioathre + iooc + iopcf + iocc + ipc + ipi + iprizec + irsg + isb + isdb + itc + itpa + itu + itvrc + iupct + iupnvp + iupr + ivwo + iwsg + iwhale + iocean + lafdo + lafta + laia + lgida + miga + mru + mercosur + nacap + nafta + nctr + ndf + nerc + nib + nrc + oapec + ocam + oecd + oecs + oeec + opec + otif + pahc + pcb + ped + piarc + pipd + ptasea + puasp + rascom + radiou + saafa + sacu + sadc + sadcc + sami + sartc + sca + sela + sica + sieca + sittdec + srdo + sugu + tcrmg + uasc + ubec + udeac + uemoa + uiucv + ukdwd + umac + umoa + unido + upu + wco + wipo + wnf + wto + wtouro + acwl + afspc + aitic + bs + d8 + eac + eaec + epu + eria + afristat + omvg


* Keep necessary variables *
keep ccode_cont ccode_host year joint_ios


* Save dataset *
save joint_ios.dta, replace 


* Frame change *
frame change default
frame drop IOs


* Merge Fatalities with original dataset *
merge m:m year ccode_cont ccode_host using "joint_ios.dta"
drop _merge


* Drop extra variables *
drop if contributors == .


* Lag joint IOs *
bysort ccode_cont mission (year month): gen lag_joint_ios = joint_ios[_n-1]
drop joint_ios
label var lag_joint_ios "Joint IOs"



* Save dataset *
save all_potential.dta, replace


**********************
*** Rugged Terrain ***
**********************

* Create frame *
frame create terrain
frame change terrain 


* Import dataset *
import delimited "Rugged_Terrain/Country_Ruggedness_1946_2015.csv", clear // Change when move folder


* Rename variables *
rename cowid ccode_host 
rename mean rugged


* Keep variables *
keep ccode_host rugged


* Save dataset *
save rugged.dta, replace


* Change frame *
frame change default
frame drop terrain 


* Merge dataset *
merge m:m ccode_host using "rugged.dta"
drop _merge
drop if contributors == . 


* Lag rugged *
bysort ccode_cont mission (year month): gen lag_rugged = rugged[_n-1]
drop rugged
label var lag_rugged "Rugged Terrain"



* Save dataset *
save all_potential.dta, replace


************************
*** Ethnic Exclusion ***
************************

* Create frame *
frame create ethnic
frame change ethnic


* Import dataset *
import delimited "Ethnic_Exclude/EPR-2021.csv", clear // Change when move folder


* Drop observations before 1990 *
drop if to < 1990


* Make into country year *
bysort statename groupid: gen dur = (to - from) + 1
expand dur
duplicates tag, gen(dup)
bysort statename groupid from dur: gen count = [_n] - 1
bysort statename groupid from dur: gen year = from + count
keep statename groupid status year


* Discriminated count *
gen disc = 0
replace disc = 1 if status == "DISCRIMINATED"


* Collapse into country year *
collapse (sum) disc, by(statename year)
drop if year < 1990


* Get cow codes *
rename statename country
do http://www.uky.edu/~clthyn2/replace_ccode_country.do
drop ccode_polity ccode_gw


* Fill in ccodes *
replace ccode = 370 if country == "Belarus (Byelorussia)"
replace ccode = 439 if country == "Burkina Faso (Upper Volta)"
replace ccode = 490 if country == "Congo, Democratic Republic of (Zaire)"
replace ccode = 630 if country == "Iran (Persia)"
replace ccode = 325 if country == "Italy/Sardinia"
replace ccode = 731 if country == "Korea, People's Republic of"
replace ccode = 343 if country == "Macedonia (FYROM/North Macedonia)"
replace ccode = 580 if country == "Madagascar (Malagasy)"
replace ccode = 115 if country == "Surinam"
replace ccode = 572 if country == "Swaziland (Eswatini)"
replace ccode = 510 if country == "Tanzania (Tanganyika)"
replace ccode = 650 if country == "Turkey (Ottoman Empire)"
replace ccode = 816 if country == "Vietnam, Democratic Republic of" & year >= 1976
replace ccode = 679 if country == "Yemen (Arab Republic of Yemen)" & year >= 1990
drop if ccode == .


* Rename variable *
rename ccode ccode_host


* Save dataset *
save ethnic_ex.dta, replace


* Change frame *
frame change default
frame drop ethnic 


* Merge dataset *
merge m:m ccode_host year using "ethnic_ex.dta"
drop _merge country
drop if contributors == . 


* Fill in zeros *
replace disc = 0 if disc == .


* Lag discrimination *
bysort ccode_cont mission (year month): gen lag_disc = disc[_n-1]
drop disc 
label var lag_disc "Number of Discriminated Ethnic Groups"


* Save dataset *
save all_potential.dta, replace


*****************************************
*** All contributed troops in a month ***
*****************************************

foreach PKO in mission {
	bysort ccode_cont year month: egen all_troops_big = total(troops)
}
	gen all_troops = all_troops_big/100
	label var all_troops "Total Contributed Troops (Hundreds)"


***********************
*** Mission Changes ***
***********************

* Missions that were taken over by the UN or changed name *
* Cannot be downgraded missions such as moving from a mission to an observer office *

* Change Mission *
gen mis_change = 0
label var mis_change "Previous Mission"

local change "BINUB" "MINURCA" "MINURCAT" "MINUSCA" "MINUSMA" "MINUSTAH" "MIPONUH" "MONUA" "MONUSCO" "ONUB" "UNAMID" "UNAMIR" "UNAMSIL" "UNAVEM II" "UNCRO" "UNIKOM" "UNMIBH" "UNMIH" "UNMIL" "UNMISET" "UNMISS" "UNMIT" "UNMOP" "UNOCI" "UNOSOM II" "UNPREDEP" "UNPSG" "UNSMIH" "UNTAC" "UNTAET" "UNTMIH"

foreach mis in "`change'"{
	replace mis_change = 1 if mission == "`mis'"
}


* Pick up from former UN mission *
gen un_change = 0
label var un_change "Previous UN Mission"

local un_chan "BINUB" "MINUSCA" "MINUSTAH" "MIPONUH" "MONUA" "MONUSCO" "UNAMIR" "UNAVEM II" "UNCRO" "UNIKOM" "UNMIBH" "UNMIL" "UNMISET" "UNMISS" "UNMIT" "UNMOP" "UNOSOM II" "UNPREDEP" "UNPSG" "UNSMIH" "UNTAC" "UNTAET" "UNTMIH"

foreach un_mis in "`un_chan'" {
	replace un_change = 1 if mission == "`un_mis'"
}


* Re-hatted missions *
gen re_hat = 0
label var re_hat "Re-hatted"

local hatted "MINURCA" "MINURCAT" "MINUSMA" "ONUB" "UNAMID" "UNAMSIL" "UNMIL" "UNOCI" "UNOMIL"

foreach hat in "`hatted'" {
	replace re_hat = 1 if mission == "`hat'"
}


* Save dataset *
save all_potential.dta, replace


********************
*** Sent Samples ***
********************

* Make earliest indicator *
egen first = min(cond(troops > 0, yearmon, .)), by(ccode_cont)
replace first = 0 if first == .


* Ever sent indicator *
gen ever_sent = 0
replace ever_sent = 1 if yearmon >= first
drop first
label var ever_sent "Ever Sent Sample"


* Find time since sent *
gen sent = 0
replace sent = 1 if troops > 0
bysort ccode_cont year (month): gen spell = (sent != 0)
bysort ccode_cont year (month): replace spell = sum(spell)
bysort ccode_cont spell (year month): gen wanted = _n-1 if spell > 0
bysort ccode_cont spell (year month): replace wanted = _n if spell == 0
rename wanted sent_time


* 5 year sent *
gen sent_five = 0
replace sent_five = 1 if sent_time <= 60
label var sent_five "Sent in 5 Last Years"


* 10 year sent * 
gen sent_ten = 0
replace sent_ten = 1 if sent_time <= 120
label var sent_ten "Sent in 10 Last Years"


****************
*** Drop IVs ***
****************

drop mission_country_iso3 region subtasks totaltasks numtasks contributor_iso3 contributor_region contributor_p5g4a3 mission_hq mission_region illness accident malicious other total_f mil obs police locals international otherstaff geo_host geo_cont all_troops_big contributor

***************
*** Lag IVs ***
***************

local IVs qual curr low deaths_civilians deaths_unknown best gov_death non_gov_death best_2 l_duration GDP_cont GDP_host host_size dem_host dem_cont same_continent s_un_atop bi_trade border illness_m accident_m malicious_m other_m total_m mil_m obs_m police_m local_m international_m otherstaff_m all_troops mis_change un_change re_hat outcome ended

foreach x of varlist `IVs' {
	bysort ccode_cont mission (year month): gen lag_`x' = `x'[_n-1]
	drop `x'
}

local others risk_ratio less_risk_ratio contributors
foreach x of varlist `others' {
	bysort ccode_cont mission (year month): gen lag_`x' = `x'[_n-1]
}


*****************
*** Lagged DV ***
*****************

bysort ccode_cont mission (year month): gen l_troops = troops[_n-1]/100
label var l_troops "Lagged Troops (Hundreds)"


***********************
*** Label Variables ***
***********************

label var ccode_cont "Contributor COW"

rename statenme contributor 
label var contributor "Contributor"

label var year "Year"

label var month "Month"

label var mission "Mission"

label var mission_country "Mission Country"

label var ccode_host "Host COW"

label var lag_risk_ratio "Risk Ratio"

label var lag_less_risk_ratio "Less Risky Ratio"

label var lag_best "Battle Deaths"

label var lag_best_2 "Battle Deaths (Hundreds)"

label var lag_qual "Troop Quality (Billions)"

label var lag_low "Low Activity"

label var lag_curr "Current"

label var lag_outcome "Conflict Termination"

label var lag_ended "Conflict Termination"

label var lag_l_duration "Conflict Duration (Logged)"

label var lag_GDP_host "Host GDP per Capita (Thousands)"

label var lag_dem_host "Host Democracy"

label var lag_contributors "Number of Contributors (Tens)"

label var lag_GDP_cont "Contributor GDP per Capita (Ten Thousands)"

label var lag_dem_cont "Contributor Democracy"

label var lag_same_continent "Same Continent"

label var lag_s_un_atop "S-Score"

label var lag_bi_trade "Trade (Billions)"

label var l_troops "Troops"

label var lag_host_size "Host Size (Million Sq. Km)"

label var lag_deaths_civilians "Civilian Deaths"

label var lag_deaths_unknown "Unknown Deaths"

label var lag_gov_death "Government Deaths"

label var lag_non_gov_death "Non-Government Deaths"

label var lag_border "Shared Border"

label var lag_illness_m "Mission Illness Deaths"

label var lag_accident_m "Mission Accident Deaths"

label var lag_malicious_m "Mission Malicious Deaths"

label var lag_other_m "Mission Other Deaths"

label var lag_total_m "Mission Total Deaths"

label var lag_mil_m "Mission Military Deaths"

label var lag_obs_m "Mission Observer Deaths"

label var lag_police_m "Mission Police Deaths"

label var lag_local_m "Mission Local Staff Deaths"

label var lag_international_m "Mission International Staff Deaths"

label var lag_otherstaff_m "Mission Other Staff Deaths"

label var lag_all_troops "Total Contributed Troops (Hundreds)"

label var lag_mis_change "Previous Mission"

label var lag_un_change "Previous UN Mission"

label var lag_re_hat "Re-hatted"

label var observe "Observer Mission"


* Save dataset *
save all_potential.dta, replace            

***************************
*** Lag All Risky Tasks ***
***************************

bysort ccode_cont mission (year month): gen lag_peaceag_cease_monitor = peaceag_cease_monitor[_n-1]
gen l_pe_ce_mon = lag_peaceag_cease_monitor 
drop lag_peaceag_cease_monitor peaceag_cease_monitor
label var l_pe_ce_mon "Monitor Peace Agreement"

bysort ccode_cont mission (year month): gen lag_buffer_monitor = buffer_monitor[_n-1]
gen l_buf_mon = lag_buffer_monitor 
drop lag_buffer_monitor buffer_monitor
label var l_buf_mon "Monitor Buffer Zone"

bysort ccode_cont mission (year month): gen lag_liaise_warpart = liaise_warpart[_n-1]
gen l_lia_war = lag_liaise_warpart 
drop lag_liaise_warpart liaise_warpart
label var l_lia_war "Liaise War Parties"

bysort ccode_cont mission (year month): gen lag_peaceag_cease_assist = peaceag_cease_assist[_n-1] 
gen l_pe_ce_as = lag_peaceag_cease_assist
drop lag_peaceag_cease_assist peaceag_cease_assist
label var l_pe_ce_as "Peace Agreement Implement"

bysort ccode_cont mission (year month): gen lag_ch7 = ch7[_n-1] 
gen l_ch7 = lag_ch7 
drop lag_ch7 ch7
label var l_ch7 "Chapter VII"

bysort ccode_cont mission (year month): gen lag_humrts_monitor = humrts_monitor[_n-1]
gen l_hr_mon = lag_humrts_monitor 
drop lag_humrts_monitor humrts_monitor
label var l_hr_mon "Monitor Human Rights"

bysort ccode_cont mission (year month): gen lag_refugees_monitor = refugees_monitor[_n-1]
gen l_ref_mon = lag_refugees_monitor 
drop lag_refugees_monitor refugees_monitor
label var l_ref_mon "Monitor Refugees"

bysort ccode_cont mission (year month): gen lag_humrts_protect = humrts_protect[_n-1]
gen l_hr_pro = lag_humrts_protect 
drop lag_humrts_protect humrts_protect
label var l_hr_pro "Protect Human Rights"

bysort ccode_cont mission (year month): gen lag_children_protect = children_protect[_n-1]
gen l_chi_pro = lag_children_protect 
drop lag_children_protect children_protect
label var l_chi_pro "Protect Children"

bysort ccode_cont mission (year month): gen lag_women_protect = women_protect[_n-1]
gen l_wo_pro = lag_women_protect
drop lag_women_protect women_protect
label var l_wo_pro "Protect Women"

bysort ccode_cont mission (year month): gen lag_prociv = prociv[_n-1]
gen l_prociv = lag_prociv 
drop lag_prociv prociv
label var l_prociv "Protect Civilians"

bysort ccode_cont mission (year month): gen lag_unpersonnel_protect = unpersonnel_protect[_n-1]
gen l_un_pro = lag_unpersonnel_protect 
drop lag_unpersonnel_protect unpersonnel_protect
label var l_un_pro "Protect UN Personnel"

bysort ccode_cont mission (year month): gen lag_demining_assist = demining_assist[_n-1]
gen l_demi_as = lag_demining_assist 
drop lag_demining_assist demining_assist
label var l_demi_as "Assist Demining"

bysort ccode_cont mission (year month): gen lag_refugees_assist = refugees_assist[_n-1]
gen l_ref_as = lag_refugees_assist
drop lag_refugees_assist refugees_assist
label var l_ref_as "Assist Refugees"

bysort ccode_cont mission (year month): gen lag_humaid_assist = humaid_assist[_n-1]
gen l_ha_as = lag_humaid_assist
drop lag_humaid_assist humaid_assist
label var l_ha_as "Assist Humanitarian Personnel"

bysort ccode_cont mission (year month): gen lag_humpersonnel_protect = humpersonnel_protect[_n-1]
gen l_hper_pro = lag_humpersonnel_protect
drop lag_humpersonnel_protect humpersonnel_protect
label var l_hper_pro "Protect Humanitarian Personnel"

bysort ccode_cont mission (year month): gen lag_borders_monitor = borders_monitor[_n-1]
gen l_bor_mon = lag_borders_monitor 
drop lag_borders_monitor borders_monitor
label var l_bor_mon "Monitor Borders"

bysort ccode_cont mission (year month): gen lag_securitysectorreform_assist = securitysectorreform_assist[_n-1]
gen l_sec_ref_as = lag_securitysectorreform_assist 
drop lag_securitysectorreform_assist securitysectorreform_assist
label var l_sec_ref_as "Assist with Security Sector Reform"

bysort ccode_cont mission (year month): gen lag_policereform_assist = policereform_assist[_n-1]
gen l_pol_ref_as = lag_policereform_assist
drop lag_policereform_assist policereform_assist
label var l_pol_ref_as "Assist Police Reform"

bysort ccode_cont mission (year month): gen lag_police_monitor = police_monitor[_n-1]
gen l_pol_mon = lag_police_monitor 
drop lag_police_monitor police_monitor
labe var l_pol_mon "Monitor the Police"

bysort ccode_cont mission (year month): gen lag_police_jointpatrols = police_jointpatrols[_n-1]
gen l_pol_join = lag_police_jointpatrols 
drop lag_police_jointpatrols police_jointpatrols
label var l_pol_join "Conduct Joint Patrols with Police"

bysort ccode_cont mission (year month): gen lag_ddr_monitor = ddr_monitor[_n-1]
gen l_ddr_mon = lag_ddr_monitor 
drop lag_ddr_monitor ddr_monitor
label var l_ddr_mon "Monitor DDR"

bysort ccode_cont mission (year month): gen lag_ddr_assist = ddr_assist[_n-1]
gen l_ddr_as = lag_ddr_assist
drop lag_ddr_assist ddr_assist
label var l_ddr_as "Assist DDR"


****************************
*** Lag Less Risky Tasks ***
****************************

bysort ccode_cont mission (year month): gen lag_goodoffices = goodoffices[_n-1]
gen l_go_off = lag_goodoffices
drop lag_goodoffices goodoffices
label var l_go_off "Good Offices"

bysort ccode_cont mission (year month): gen lag_weaponstrade_monitor = weaponstrade_monitor[_n-1]
gen l_weap_mon = lag_weaponstrade_monitor
drop lag_weaponstrade_monitor weaponstrade_monitor
label var l_weap_mon "Monitor Weapons Trade"

bysort ccode_cont mission (year month): gen lag_weaponsembargo_monitor = weaponsembargo_monitor[_n-1]
gen l_weap_em_mon = lag_weaponsembargo_monitor
drop lag_weaponsembargo_monitor weaponsembargo_monitor
label var l_weap_em_mon "Monitor Weapons Embargo"

bysort ccode_cont mission (year month): gen lag_cargoinspections = cargoinspections[_n-1]
gen l_carg_insp = lag_cargoinspections
drop lag_cargoinspections cargoinspections
label var l_carg_insp "Cargo Inspections"

bysort ccode_cont mission (year month): gen lag_resources_monitor = resources_monitor[_n-1]
gen l_resou_mon = lag_resources_monitor
drop lag_resources_monitor resources_monitor
label var l_resou_mon "Monitor Resources"

bysort ccode_cont mission (year month): gen lag_election_monitor = election_monitor[_n-1]
gen l_ele_mon = lag_election_monitor
drop lag_election_monitor election_monitor
label var l_ele_mon "Monitor Elections"

bysort ccode_cont mission (year month): gen lag_election_security = election_security[_n-1]
gen l_ele_sec = lag_election_security
drop lag_election_security election_security
label var l_ele_sec "Election Security"

bysort ccode_cont mission (year month): gen lag_election_assist = election_assist[_n-1]
gen l_ele_ass = lag_election_assist
drop lag_election_assist election_assist
label var l_ele_ass "Assist Elections"

bysort ccode_cont mission (year month): gen lag_govcap_assist = govcap_assist[_n-1]
gen l_gov_ass = lag_govcap_assist
drop lag_govcap_assist govcap_assist
label var l_gov_ass "Government Capacity Assist"

bysort ccode_cont mission (year month): gen lag_govpolicies_assist = govpolicies_assist[_n-1]
gen l_govp_ass = lag_govpolicies_assist
drop lag_govpolicies_assist govpolicies_assist
label var l_govp_ass "Government Policy Assist"

bysort ccode_cont mission (year month): gen lag_cultural_pres = cultural_pres[_n-1]
gen l_cul_pres = lag_cultural_pres
drop lag_cultural_pres cultural_pres
label var l_cul_pres "Cultural Preservation"

bysort ccode_cont mission (year month): gen lag_qip_assist = qip_assist[_n-1]
gen l_qip_ass = lag_qip_assist
drop lag_qip_assist qip_assist
label var l_qip_ass "QIP Assistance"

bysort ccode_cont mission (year month): gen lag_justice_assist = justice_assist[_n-1]
gen l_jus_ass = lag_justice_assist
drop lag_justice_assist justice_assist
label var l_jus_ass "Assist Justice"

bysort ccode_cont mission (year month): gen lag_reconciliation = reconciliation[_n-1]
gen l_recon = lag_reconciliation
drop lag_reconciliation reconciliation
label var l_recon "Promote Reconciliation"

bysort ccode_cont mission (year month): gen lag_justice_warcrim = justice_warcrim[_n-1]
gen l_jus_warc = lag_justice_warcrim
drop lag_justice_warcrim justice_warcrim
label var l_jus_warc "Justice on War Criminals"

bysort ccode_cont mission (year month): gen lag_mission_pr = mission_pr[_n-1]
gen l_mis_pr = lag_mission_pr
drop lag_mission_pr mission_pr
label var l_mis_pr "Mission PR"

bysort ccode_cont mission (year month): gen lag_freepress = freepress[_n-1]
gen l_fre_pres = lag_freepress
drop lag_freepress freepress
label var l_fre_pres "Promote Free Press"


*******************************
*** Authorized Mission Size ***
******************************* 

* Create frame *
frame create auth 
frame change auth 


* Import dataset *
use Shortfalls/Personnel_shortfall_data.dta, clear


* Drop unneeded variables *
drop mission_number_auth missioncode_Meg monyear monyear_mission authpolice authmilobs police milobs shortfallpolice shortfallmilobs shortfalltotal propshortfallpolice propshortfallmilobs unspecdrawdown contpresence contributors propshortfall total2 totalauth totmilauth missionccode missioncountry yearmon total


* Save dataframe *
save shortfalls.dta, replace


* Change frame *
frame change default
frame drop auth


* Merge dataset * 
merge m:m mission year month using "shortfalls.dta"
drop _merge troop


* Rename variables *
label var authtroop "Authorize Troops"

rename shortfalltroop troops_short
gen val = troops_short 
drop troops_short
gen troops_short = val/100
drop val
label var troops_short "Troop Shortfall (Hundres)"

rename propshortfalltroops troops_short_prop
label var troops_short_prop "Troop Shortfall Proportion"

rename numberofmissions miss_num 
label var miss_num "Number of Missions"

rename missionlength1 miss_dur
label var miss_dur "Mission Duration"


* Lag shortfall variables *
local short authtroop troops_short troops_short_prop miss_num miss_dur troopauth_reduc troopauth_reduc_count

foreach x of varlist `short' {
	bysort ccode_cont mission (year month): gen lag_`x' = `x'[_n-1]
}


* Label variables *
label var lag_authtroop "Authorized Troops"
label var lag_troops_short "Troop Shortfall (Hundreds)"
label var lag_troops_short_prop "Troop Shortfall Proportion"
label var lag_miss_num "Number of Missions"
label var lag_miss_dur "Mission Duration"
label var lag_troopauth_reduc "Troop Authorization Reduction"
label var lag_troopauth_reduc_count "Troop Authorization Reduction Count"


* Save dataset *
save all_potential.dta, replace    

***********************************************************
*** Contributions as Percentage of Contributor Military ***
***********************************************************

* Generate variable *
gen lag_cont_troop_prop = l_troops / lag_milper_cont
label var lag_cont_troop_prop "Proportion of Contributor Troops"


*********************
*** Regional PKOs ***
*********************

* Create frame *
frame create reg_pko
frame change reg_pko


* Import dataset *
use "Regional_PKO/UN and Non-UN Peacekeeping_v2-2019.dta", clear


* Drop UN missions *
drop if org == 1


* Split date *
format date %10.0g
gen date2 = dofm(date)
format date2 %d
gen month=month(date2)


* Keep variables *
keep ccode month year onlypolice


* Gen Regional PK0 variable *
gen reg_PKO = 1


* Collapse data *
collapse (sum) reg_PKO onlypolice, by(ccode month year)


* Gen regional PKO presence variable *
gen reg_PKO_dum = 1


* rename ccode *
rename ccode ccode_host 


* Save dataset *
save reg_PKO.dta, replace


* Change frame *
frame change default 
frame drop reg_pko


* merge dataset *
merge m:m ccode_host year month using "reg_PKO.dta"
drop if ccode_cont == .
drop _merge
	 

* lag variables * 
local vars reg_PKO onlypolice reg_PKO_dum 

foreach x in `vars' {
	bysort ccode_cont mission (year month): gen lag_`x' = `x'[_n-1]
	drop `x'
}

label var lag_reg_PKO "Number of Regional PKOs"
replace lag_reg_PKO = 0 if lag_reg_PKO == . 
label var lag_onlypolice "Number of Police Only Regional PKOS"
replace lag_onlypolice = 0 if lag_onlypolice == .
label var lag_reg_PKO_dum "Presence of Regional PKO"
replace lag_reg_PKO_dum = 0 if lag_reg_PKO_dum == . 


************************
*** Mandate Duration ***
************************

* Create frame *
frame copy default dur
frame change dur


* Collapse dataset *
collapse (first) unsc_resolution, by(mission year month)

* Make duration variable *
gen mandate_dur = 0


* Replace with duration *
bysort mission (year month): replace mandate_dur = mandate_dur[_n-1] + 1 if unsc_resolution == unsc_resolution[_n-1]


* Save dataset *
save mandate_dur.dta, replace


* Change frame *
frame change default
frame drop dur


* Merge dataset * 
merge m:m mission year month using "mandate_dur.dta"
drop _merge


* Lag mandate duration *
bysort ccode_cont mission (year month): gen lag_mandate_dur = mandate_dur[_n-1]
drop mandate_dur
label var lag_mandate_dur "Mandate Duration"



***********************
*** Order Variables ***
***********************

order year month mission contributor ccode_cont mission_country ccode_host troops civilian_police observers total lag_risk_ratio lag_less_risk_ratio l_troops lag_contributors lag_l_duration lag_outcome lag_qual lag_best lag_best_2 lag_GDP_cont lag_GDP_host lag_host_size lag_dem_host lag_dem_cont lag_same_continent lag_border lag_s_un_atop lag_bi_trade lag_curr lag_low lag_illness_m lag_accident_m lag_malicious_m lag_other_m lag_total_m lag_mil_m lag_obs_m lag_police_m lag_local_m lag_international_m lag_otherstaff_m lag_all_troops lag_mis_change lag_un_change lag_re_hat lag_authtroop lag_troops_short lag_troops_short_prop lag_troopauth_reduc lag_troopauth_reduc_count lag_miss_num lag_miss_dur authtroop troops_short troops_short_prop miss_num miss_dur lag_mandate_dur lag_joint_ios lag_rugged lag_disc ever_sent sent_five sent_ten lag_milper_cont lag_cont_troop_prop lag_reg_PKO lag_onlypolice lag_reg_PKO_dum


*** Drop Extra Observations ***
drop if contributor == ""

* Save dataset *
save all_potential.dta, replace            


**************************
*** Randomization Loop ***
**************************

cd "${cd_path}"

use all_potential.dta, clear

encode mission, gen(mission2)
levelsof mission2
local missions = r(levels)
save all_potential_loop.dta, replace

foreach mis in `missions' {
	use all_potential_loop.dta, clear
	keep if mission2 == `mis'
	save Random_Loops/r`mis'.dta, replace
	local i = 359 
	
	while `i' <= 659 {
		use Random_Loops/r`mis'.dta, clear
		drop if yearmon != `i'
		
		if _N > 0 {
		
		* Random 1 *
		set seed 8739 // The numbers spell Trey
		bysort mission year month: complete_ra rand1_15 if troops == 0, m(15) replace
		replace rand1_15 = 1 if rand1_15 == .
		bysort mission year month: complete_ra rand1_30 if troops == 0, m(30) replace
		replace rand1_30 = 1 if rand1_30 == .

		* Random 2 *
		set seed 0722 // Trey's Birthday
		bysort mission year month: complete_ra rand2_15 if troops == 0, m(15) replace
		replace rand2_15 = 1 if rand2_15 == .
		bysort mission year month: complete_ra rand2_30 if troops == 0, m(30) replace
		replace rand2_30 = 1 if rand2_30 == .

		* Random 3 *
		set seed 1945 // Year the UN Was Founded
		bysort mission year month: complete_ra rand3_15 if troops == 0, m(15) replace
		replace rand3_15 = 1 if rand3_15 == .
		bysort mission year month: complete_ra rand3_30 if troops == 0, m(30) replace
		replace rand3_30 = 1 if rand3_30 == .

		* Random 4 *
		set seed 1948 // Year of First UN PKO
		bysort mission year month: complete_ra rand4_15 if troops == 0, m(15) replace
		replace rand4_15 = 1 if rand4_15 == .
		bysort mission year month: complete_ra rand4_30 if troops == 0, m(30) replace
		replace rand4_30 = 1 if rand4_30 == .

		* Random 5 *
		set seed 3079 // Last 4 Digits of My Phone Number
		bysort mission year month: complete_ra rand5_15 if troops == 0, m(15) replace
		replace rand5_15 = 1 if rand5_15 == .
		bysort mission year month: complete_ra rand5_30 if troops == 0, m(30) replace
		replace rand5_30 = 1 if rand5_30 == .

		* Random 6 *
		set seed 2021 // Year Project Began
		bysort mission year month: complete_ra rand6_15 if troops == 0, m(15) replace
		replace rand6_15 = 1 if rand6_15 == .
		bysort mission year month: complete_ra rand6_30 if troops == 0, m(30) replace
		replace rand6_30 = 1 if rand6_30 == .

		* Random 7 *
		set seed 1996 // Year Trey Was Born
		bysort mission year month: complete_ra rand7_15 if troops == 0, m(15) replace
		replace rand7_15 = 1 if rand7_15 == .
		bysort mission year month: complete_ra rand7_30 if troops == 0, m(30) replace
		replace rand7_30 = 1 if rand7_30 == .
		
		* Random 8 *
		set seed 7669 // Phone Spelling for My Favorite Headphones Brand, Sony
		bysort mission year month: complete_ra rand8_15 if troops == 0, m(15) replace
		replace rand8_15 = 1 if rand8_15 == .
		bysort mission year month: complete_ra rand8_30 if troops == 0, m(30) replace
		replace rand8_30 = 1 if rand8_30 == .
		
		* Random 9 *
		set seed 1955 // Year Covenant College was Founded
		bysort mission year month: complete_ra rand9_15 if troops == 0, m(15) replace
		replace rand9_15 = 1 if rand9_15 == .
		bysort mission year month: complete_ra rand9_30 if troops == 0, m(30) replace
		replace rand9_30 = 1 if rand9_30 == .

		* Random 10 *
		set seed 1865 // Year University Of Kentucky was Founded
		bysort mission year month: complete_ra rand10_15 if troops == 0, m(15) replace
		replace rand10_15 = 1 if rand10_15 == .
		bysort mission year month: complete_ra rand10_30 if troops == 0, m(30) replace
		replace rand10_30 = 1 if rand10_30 == .
		drop mission2
		duplicates drop
		save Random_Loops/Smaller_Datasets/r`mis'_`i'.dta, replace
		local i = `i' + 1
		}		
		else {
			local i = `i' + 1
		}
	}
}

* Append into one dataset *
cd "${cd_path}/Random_Loops/Smaller_Datasets"

! ls *.dta >filelist.txt

file open myfile using filelist.txt, read

file read myfile line
use `line'
save all_potential_loop.dta, replace

file read myfile line
while r(eof)==0 { /* while you're not at the end of the file */
	append using `line'
	file read myfile line
}
file close myfile
save all_potential_loop.dta, replace


*********************************
*** Cut into smaller datasets ***
*********************************


*forvalues x = 1990(1)2014 {
*	use all_potential_loop.dta
*	keep if year == `x'
*	save "/Users/treywood/Dropbox/Projects/Active_Projects/Mandate_Contribute/Data_Analysis/Dataset/set_`x'", replace
*}


****************************
*** Erase extra datasets ***
****************************

do ${cd_path}/Erases.do



******************
*** Final Save ***
******************

cd "${da_path}" 

save Mandate_Cont.dta, replace



